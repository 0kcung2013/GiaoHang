-- Avoid misclassifying normal release as monitoring reclaim; protect concurrent CSKH chat.
CREATE OR REPLACE FUNCTION public.get_order_driver_monitoring(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_actor uuid:=auth.uid(); v_order public.orders%ROWTYPE; v_ticket uuid;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_actor IN (v_order.customer_id,v_order.driver_id) OR EXISTS (
    SELECT 1 FROM public.users WHERE id=v_actor AND role IN ('support','admin')
  ) THEN
    RETURN jsonb_build_object('order_id',p_order_id,'status',v_order.status,
      'driver_id',v_order.driver_id,'released',false,'state',v_order.driver_monitoring,
      'server_now',statement_timestamp());
  END IF;
  SELECT t.id INTO v_ticket FROM public.support_tickets t
  WHERE t.order_id=p_order_id AND t.requester_id=v_actor
    AND t.subject='Giám sát: thu hồi phân công' AND EXISTS (
    SELECT 1 FROM public.case_messages m WHERE m.ticket_id=t.id AND m.sender_role_snapshot='system')
  ORDER BY t.created_at DESC,t.id LIMIT 1;
  IF v_ticket IS NULL THEN
    IF EXISTS (SELECT 1 FROM public.order_status_logs l
      WHERE l.order_id=p_order_id AND l.logged_by=v_actor AND l.status='assigned')
      OR EXISTS (SELECT 1 FROM public.support_tickets t JOIN public.case_messages m ON m.ticket_id=t.id
        WHERE t.order_id=p_order_id AND t.requester_id=v_actor AND m.sender_role_snapshot='system') THEN
      RETURN jsonb_build_object('order_id',p_order_id,'released',false,
        'status','not_assigned','server_now',statement_timestamp());
    END IF;
    RAISE EXCEPTION 'MONITORING_ACCESS_DENIED' USING ERRCODE='42501';
  END IF;
  RETURN jsonb_build_object('order_id',p_order_id,'released',true,
    'support_ticket_id',v_ticket,'server_now',statement_timestamp());
END;
$function$;

CREATE OR REPLACE FUNCTION private.create_monitoring_ticket(p_order_id uuid, p_requester_id uuid, p_subject text, p_body text, p_existing_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_id uuid:=gen_random_uuid(); v_previous text;
BEGIN
  IF p_existing_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.support_tickets
    WHERE id=p_existing_id AND order_id=p_order_id AND requester_id=p_requester_id
      AND status NOT IN ('resolved','closed')) THEN
    -- Chat locks ticket before inserting a notification referencing this order.
    -- Never wait for that ticket while cron holds the order; retry the next tick.
    PERFORM 1 FROM public.support_tickets WHERE id=p_existing_id FOR UPDATE NOWAIT;
    INSERT INTO public.case_messages(ticket_id,sender_id,sender_role_snapshot,visibility,body)
    VALUES(p_existing_id,p_requester_id,'system','public',p_body);
    UPDATE public.support_tickets SET updated_at=clock_timestamp() WHERE id=p_existing_id;
    v_id:=p_existing_id;
  ELSE
    v_previous:=current_setting('giaohang.monitoring_ticket',true);
    PERFORM set_config('giaohang.monitoring_ticket',v_id::text,true);
    INSERT INTO public.support_tickets(id,order_id,requester_id,created_by,subject,message,
      priority,status,response_due_at)
    VALUES(v_id,p_order_id,p_requester_id,p_requester_id,p_subject,p_body,
      'high','open',clock_timestamp()+interval '10 minutes');
    PERFORM set_config('giaohang.monitoring_ticket',coalesce(v_previous,''),true);
  END IF;
  PERFORM private.enqueue_linked_case_notification(p_requester_id,
    p_subject,p_body,'support_ticket_created',p_order_id,v_id);
  -- Thông báo cho nhân viên đang phụ trách nếu tái sử dụng hồ sơ.
  PERFORM private.enqueue_linked_case_notification(t.assigned_to,p_subject,p_body,
    'support_ticket_customer_message',p_order_id,v_id)
  FROM public.support_tickets t WHERE t.id=v_id AND t.assigned_to IS NOT NULL;
  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION private.process_driver_monitoring()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_order public.orders%ROWTYPE; v_state jsonb; v_now timestamptz;
  v_accepted timestamptz; v_last timestamptz; v_no_departure boolean;
  v_custody boolean; v_reason text; v_body text; v_release bigint;
  v_driver_ticket uuid; v_customer_ticket uuid; v_count integer:=0;
BEGIN
  FOR v_order IN SELECT * FROM public.orders
    WHERE driver_id IS NOT NULL AND driver_monitoring IS NOT NULL
      AND status IN ('assigned','picking_up','delivering','return_approved','returning')
      AND (
        (coalesce((driver_monitoring->>'last_received_at')::timestamptz,
          (driver_monitoring->>'accepted_at')::timestamptz) <= clock_timestamp()-interval '5 minutes'
          AND (driver_monitoring->>'gps_warned_at' IS NULL
            OR driver_monitoring->>'gps_escalated_gap_at' IS NULL))
        OR (status IN ('assigned','picking_up') AND actual_picked_up_at IS NULL
          AND driver_monitoring->>'gps_escalated_gap_at' IS NULL
          AND driver_monitoring->>'departed_at' IS NULL
          AND driver_monitoring->>'at_pickup_at' IS NULL AND pickup_arrived_at IS NULL
          AND (driver_monitoring->>'accepted_at')::timestamptz <= clock_timestamp()-interval '5 minutes')
      )
    ORDER BY coalesce((driver_monitoring->>'last_received_at')::timestamptz,
      (driver_monitoring->>'accepted_at')::timestamptz)
    FOR UPDATE SKIP LOCKED LIMIT 200
  LOOP
    v_now:=clock_timestamp(); v_state:=v_order.driver_monitoring;
    v_accepted:=(v_state->>'accepted_at')::timestamptz;
    v_last:=coalesce((v_state->>'last_received_at')::timestamptz,v_accepted);
    v_custody:=v_order.actual_picked_up_at IS NOT NULL
      OR v_order.status NOT IN ('assigned','picking_up')
      OR EXISTS (SELECT 1 FROM public.order_delivery_proofs
        WHERE order_id=v_order.id AND stage='pickup')
      OR EXISTS (SELECT 1 FROM public.risk_report_interventions
        WHERE order_id=v_order.id AND state IN ('return_required','handoff_required'));
    v_no_departure:=NOT v_custody AND v_state->>'departed_at' IS NULL
      AND v_state->>'at_pickup_at' IS NULL AND v_order.pickup_arrived_at IS NULL;
    v_reason:=NULL;
    IF v_now>=v_last+interval '10 minutes' THEN v_reason:='gps_lost';
    ELSIF v_no_departure AND v_now>=v_accepted+interval '10 minutes' THEN v_reason:='not_departed'; END IF;
    IF v_reason IS NOT NULL AND (NOT v_custody OR v_state->>'gps_escalated_gap_at' IS NULL) THEN
      v_body:=CASE WHEN v_reason='not_departed'
        THEN 'Tài xế chưa xuất phát sau 10 phút tính từ lúc nhận đơn (đã bao gồm 5 phút chuẩn bị).'
        ELSE 'Không nhận được vị trí GPS hợp lệ của tài xế trong 10 phút liên tục.' END;
      v_body:=v_body||E'\nNhận đơn: '||to_char(v_accepted AT TIME ZONE 'Asia/Ho_Chi_Minh','DD/MM/YYYY HH24:MI:SS')
        ||E'\nPhát hiện: '||to_char(v_now AT TIME ZONE 'Asia/Ho_Chi_Minh','DD/MM/YYYY HH24:MI:SS')
        ||CASE WHEN v_custody THEN E'\nHàng đã nhận hoặc có bằng chứng nhận hàng. Giữ tài xế; CSKH cần liên hệ xác minh.'
          ELSE E'\nChưa nhận hàng. Hệ thống thu hồi phân công và tìm tài xế thay thế. Không tính là lượt từ chối.' END;
      BEGIN
      v_driver_ticket:=private.create_monitoring_ticket(v_order.id,v_order.driver_id,
        CASE WHEN v_custody THEN 'Giám sát: mất GPS khi đang giữ hàng' ELSE 'Giám sát: thu hồi phân công' END,
        v_body,(v_state->>'driver_ticket_id')::uuid);
      v_customer_ticket:=private.create_monitoring_ticket(v_order.id,v_order.customer_id,
        CASE WHEN v_custody THEN 'Giám sát: cần xác minh hành trình' ELSE 'Giám sát: tìm tài xế thay thế' END,
        v_body,(v_state->>'customer_ticket_id')::uuid);
      EXCEPTION WHEN lock_not_available THEN
        -- Subtransaction rolls back both messages/notifications; no partial incident.
        CONTINUE;
      END;
      v_state:=v_state||jsonb_build_object('incident_reason',v_reason,'incident_at',v_now,
        'driver_ticket_id',v_driver_ticket,'customer_ticket_id',v_customer_ticket);
      IF v_custody THEN
        v_state:=v_state||jsonb_build_object('gps_escalated_gap_at',v_last,'gps_reminded_at',v_now,'gps_warned_at',v_now);
        INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
        VALUES(v_order.id,v_order.status,'Mất GPS: chuyển CSKH xác minh',v_body,v_order.driver_id);
      ELSE
        -- Giữ thứ tự khóa của phân công/ví. Cron không thu hồi đơn đã có hàng.
        PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('driver-assignment:'||v_order.driver_id::text,0));
        PERFORM 1 FROM public.drivers WHERE user_id=v_order.driver_id FOR UPDATE;
        PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_order.driver_id::text,0));
        SELECT coalesce(sum(held_delta),0)::bigint INTO v_release FROM public.driver_wallet_transactions
          WHERE driver_id=v_order.driver_id AND order_id=v_order.id AND status='completed';
        IF v_release>0 THEN
          INSERT INTO public.driver_wallet_transactions(driver_id,order_id,transaction_type,
            amount,available_delta,held_delta,idempotency_key,completed_at)
          VALUES(v_order.driver_id,v_order.id,'cod_release',v_release,v_release,-v_release,
            'monitoring:'||(v_state->>'assignment_id')||':cod_release',v_now);
        END IF;
        v_state:=v_state||jsonb_build_object('reclaimed_at',v_now);
        UPDATE public.orders SET driver_id=NULL,status='pending',driver_monitoring=v_state,
          offered_driver_id=NULL,offer_expires_at=NULL,pickup_arrived_at=NULL,
          assignment_expires_at=v_now+interval '15 minutes',assignment_timed_out_at=NULL,
          estimated_pickup_at=NULL,estimated_delivery_at=NULL,
          rejected_by=CASE WHEN coalesce(rejected_by,'[]'::jsonb) ? v_order.driver_id::text
            THEN rejected_by ELSE coalesce(rejected_by,'[]'::jsonb)||jsonb_build_array(v_order.driver_id::text) END,
          status_note='Đang tìm tài xế thay thế do gián đoạn hành trình.'
        WHERE id=v_order.id;
        INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
        VALUES(v_order.id,'pending','Hệ thống thu hồi phân công',v_body,v_order.driver_id);
        PERFORM private.dispatch_next_order_offer(v_order.id,2000);
        v_count:=v_count+1;
        CONTINUE;
      END IF;
    ELSE
      IF v_no_departure AND v_now>=v_accepted+interval '8 minutes' AND v_state->>'departure_warned_at' IS NULL THEN
        PERFORM private.enqueue_linked_case_notification(v_order.driver_id,'Cần xuất phát ngay',
          'Bạn chưa xuất phát. Đơn sẽ được thu hồi ở phút thứ 10 nếu chưa nhận hàng.','order_update',v_order.id);
        v_state:=v_state||jsonb_build_object('departure_warned_at',v_now,'departure_reminded_at',v_now);
      ELSIF v_no_departure AND v_now>=v_accepted+interval '5 minutes' AND v_state->>'departure_reminded_at' IS NULL THEN
        PERFORM private.enqueue_linked_case_notification(v_order.driver_id,'Đã hết 5 phút chuẩn bị',
          'Vui lòng di chuyển đến điểm lấy hàng. Hệ thống sẽ thu hồi đơn nếu chưa xuất phát sau 10 phút.','order_update',v_order.id);
        v_state:=v_state||jsonb_build_object('departure_reminded_at',v_now);
      END IF;
      IF v_now>=v_last+interval '9 minutes' AND v_state->>'gps_warned_at' IS NULL THEN
        PERFORM private.enqueue_linked_case_notification(v_order.driver_id,'Cần khôi phục GPS ngay',
          CASE WHEN v_custody THEN 'Mất cập nhật vị trí 9 phút. Sau 10 phút, CSKH sẽ nhận hồ sơ xác minh; bạn vẫn chịu trách nhiệm giao hàng.'
            ELSE 'Mất cập nhật vị trí 9 phút. Sau 10 phút liên tục, đơn chưa nhận hàng sẽ được thu hồi.' END,
          'order_update',v_order.id);
        v_state:=v_state||jsonb_build_object('gps_warned_at',v_now,'gps_reminded_at',v_now);
      ELSIF v_now>=v_last+interval '5 minutes' AND v_state->>'gps_reminded_at' IS NULL THEN
        PERFORM private.enqueue_linked_case_notification(v_order.driver_id,'Mất cập nhật vị trí',
          'Không nhận được GPS hợp lệ trong 5 phút. Vui lòng kiểm tra quyền vị trí và kết nối mạng.','order_update',v_order.id);
        v_state:=v_state||jsonb_build_object('gps_reminded_at',v_now);
      END IF;
    END IF;
    IF v_state IS DISTINCT FROM v_order.driver_monitoring THEN
      UPDATE public.orders SET driver_monitoring=v_state WHERE id=v_order.id;
    END IF;
  END LOOP;
  RETURN v_count;
END;
$function$;

CREATE OR REPLACE FUNCTION private.guard_order_driver_monitoring()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_now timestamptz := clock_timestamp();
  v_driver public.drivers%ROWTYPE;
BEGIN
  IF current_user IN ('anon','authenticated') AND (
    (TG_OP = 'INSERT' AND NEW.driver_monitoring IS NOT NULL)
    OR (TG_OP = 'UPDATE' AND NEW.driver_monitoring IS DISTINCT FROM OLD.driver_monitoring)
  ) THEN RAISE EXCEPTION 'MONITORING_SERVER_OWNED' USING ERRCODE='42501'; END IF;
  IF NEW.driver_id IS NOT NULL AND (
    TG_OP = 'INSERT' OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
  ) THEN
    SELECT * INTO v_driver FROM public.drivers WHERE user_id=NEW.driver_id;
    NEW.driver_monitoring := jsonb_build_object(
      'version',1,'assignment_id',gen_random_uuid(),'driver_id',NEW.driver_id,
      'accepted_at',v_now,'last_received_at',NULL,'departed_at',NULL,'at_pickup_at',NULL);
    IF v_driver.location_updated_at >= v_now-interval '2 minutes'
      AND v_driver.location_updated_at<=v_now+interval '15 seconds'
      AND v_driver.current_lat BETWEEN -90 AND 90 AND v_driver.current_lng BETWEEN -180 AND 180
      AND NOT (v_driver.current_lat=0 AND v_driver.current_lng=0) THEN
      NEW.driver_monitoring := NEW.driver_monitoring || jsonb_build_object(
        'anchor_lat',v_driver.current_lat,'anchor_lng',v_driver.current_lng);
      IF private.monitoring_distance_m(v_driver.current_lat,v_driver.current_lng,
        NEW.pickup_lat,NEW.pickup_lng) <= 75 THEN
        NEW.driver_monitoring := NEW.driver_monitoring || jsonb_build_object('at_pickup_at',v_now);
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
