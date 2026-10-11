-- APPROVED AND APPLIED on 2026-10-11. This file preserves the original proposal.
-- Do not rerun this proposal; follow the applied migrations for the final implementation:
-- 20261011021932_driver_assignment_monitoring.sql
-- 20261011024717_driver_monitoring_case_lock_and_readback.sql
-- 20261011030731_driver_monitoring_incident_timing.sql
-- Không tạo bảng; lưu trạng thái hiện tại trên orders. Lịch sử GPS vẫn ở R2.
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS driver_monitoring jsonb;
COMMENT ON COLUMN public.orders.driver_monitoring IS
  'Server-owned assignment monitoring; current state only, not GPS history.';
ALTER TABLE public.case_messages DROP CONSTRAINT case_messages_sender_role_snapshot_check;
ALTER TABLE public.case_messages ADD CONSTRAINT case_messages_sender_role_snapshot_check
  CHECK (sender_role_snapshot IN ('customer','driver','support','admin','system'));

CREATE OR REPLACE FUNCTION private.monitoring_distance_m(
  a_lat double precision,a_lng double precision,b_lat double precision,b_lng double precision)
RETURNS double precision LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT 6371000 * 2 * asin(least(1.0,sqrt(
    power(sin(radians(b_lat-a_lat)/2),2)
    + cos(radians(a_lat))*cos(radians(b_lat))*power(sin(radians(b_lng-a_lng)/2),2))));
$$;

CREATE OR REPLACE FUNCTION private.guard_order_driver_monitoring()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
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
      AND v_driver.current_lat IS NOT NULL AND v_driver.current_lng IS NOT NULL THEN
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
$$;
CREATE TRIGGER orders_guard_driver_monitoring BEFORE INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION private.guard_order_driver_monitoring();

-- Cùng khóa đơn với cron: bằng chứng nhận hàng không được ghi cho tài xế
-- đã mất phân công trong lúc upload ảnh. Các loại bằng chứng khác giữ luồng cũ.
CREATE OR REPLACE FUNCTION private.guard_monitoring_pickup_proof()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_order public.orders%ROWTYPE;
BEGIN
  IF NEW.stage='pickup' THEN
    SELECT * INTO v_order FROM public.orders WHERE id=NEW.order_id FOR UPDATE;
    IF v_order.driver_monitoring IS NOT NULL AND (
      v_order.driver_id IS DISTINCT FROM NEW.driver_id
      OR v_order.status NOT IN ('assigned','picking_up','delivering')
    ) THEN RAISE EXCEPTION 'PICKUP_ASSIGNMENT_CHANGED'; END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER order_proofs_guard_monitoring_pickup BEFORE INSERT OR UPDATE OF order_id,driver_id,stage
ON public.order_delivery_proofs FOR EACH ROW EXECUTE FUNCTION private.guard_monitoring_pickup_proof();

-- RPC ghi một mẫu GPS mới; không lưu chuỗi tọa độ trong PostgreSQL.
CREATE OR REPLACE FUNCTION public.record_driver_monitoring_position(
  p_order_id uuid,p_lat double precision,p_lng double precision,
  p_accuracy double precision,p_captured_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_state jsonb;
  v_now timestamptz;
  v_previous timestamptz;
  v_candidate timestamptz;
  v_distance double precision;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id FOR UPDATE;
  IF NOT FOUND OR v_order.driver_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED' USING ERRCODE='42501';
  END IF;
  IF v_order.status NOT IN ('assigned','picking_up','delivering','return_approved','returning') THEN
    RETURN jsonb_build_object('accepted',false);
  END IF;
  v_now := clock_timestamp();
  IF p_lat IS NULL OR p_lng IS NULL OR p_accuracy IS NULL OR p_captured_at IS NULL
    OR NOT (p_lat BETWEEN -90 AND 90 AND p_lng BETWEEN -180 AND 180)
    OR NOT (p_accuracy BETWEEN 0 AND 50)
    OR p_captured_at < v_now-interval '90 seconds'
    OR p_captured_at > v_now+interval '15 seconds' THEN
    RETURN jsonb_build_object('accepted',false,'reason','invalid_or_stale_sample','server_now',v_now);
  END IF;
  v_state := v_order.driver_monitoring;
  IF v_state IS NULL THEN RETURN jsonb_build_object('accepted',false,'reason','monitoring_not_initialized'); END IF;
  v_previous := (v_state->>'last_captured_at')::timestamptz;
  IF v_previous IS NOT NULL AND p_captured_at <= v_previous THEN
    RETURN jsonb_build_object('accepted',false,'reason','duplicate_or_out_of_order');
  END IF;
  -- Không công nhận một bước nhảy vị trí phi thực tế là GPS còn hoạt động.
  IF v_previous IS NOT NULL AND v_state->>'last_lat' IS NOT NULL
    AND private.monitoring_distance_m((v_state->>'last_lat')::double precision,
      (v_state->>'last_lng')::double precision,p_lat,p_lng)
      > 35*extract(epoch FROM p_captured_at-v_previous)+100 THEN
    RETURN jsonb_build_object('accepted',false,'reason','implausible_jump');
  END IF;
  v_state := (v_state - ARRAY['gps_reminded_at','gps_warned_at','gps_escalated_gap_at'])
    || jsonb_build_object('last_received_at',v_now,'last_captured_at',p_captured_at,
      'last_lat',p_lat,'last_lng',p_lng,'last_accuracy',p_accuracy);
  IF v_state->>'anchor_lat' IS NULL THEN
    v_state := v_state || jsonb_build_object('anchor_lat',p_lat,'anchor_lng',p_lng);
  END IF;
  IF private.monitoring_distance_m(p_lat,p_lng,v_order.pickup_lat,v_order.pickup_lng)+p_accuracy <=100 THEN
    v_state := v_state || jsonb_build_object('at_pickup_at',coalesce(
      (v_state->>'at_pickup_at')::timestamptz,v_now));
  END IF;
  IF v_state->>'departed_at' IS NULL THEN
    v_distance := private.monitoring_distance_m((v_state->>'anchor_lat')::double precision,
      (v_state->>'anchor_lng')::double precision,p_lat,p_lng);
    IF v_distance-p_accuracy >=100 THEN
      v_candidate := (v_state->>'departure_candidate_at')::timestamptz;
      IF v_candidate IS NULL THEN
        v_state := v_state || jsonb_build_object('departure_candidate_at',v_now);
      ELSIF v_now >= v_candidate+interval '10 seconds' THEN
        v_state := v_state || jsonb_build_object('departed_at',v_candidate);
        -- Chỉ bỏ đúng 5 phút chuẩn bị nếu xuất phát sớm; không tính lại các chặng.
        IF v_order.status IN ('assigned','picking_up') THEN
          UPDATE public.orders SET delivery_eta=private.apply_fixed_eta_departure(
            delivery_eta,v_candidate) WHERE id=p_order_id;
        END IF;
      END IF;
    ELSE v_state := v_state - 'departure_candidate_at'; END IF;
  END IF;
  UPDATE public.orders SET driver_monitoring=v_state WHERE id=p_order_id;
  RETURN jsonb_build_object('accepted',true,'state',v_state,'server_now',v_now);
END;
$$;
REVOKE ALL ON FUNCTION public.record_driver_monitoring_position(uuid,double precision,double precision,double precision,timestamptz) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.record_driver_monitoring_position(uuid,double precision,double precision,double precision,timestamptz) TO authenticated;

-- Không mở RLS users. CSKH chỉ đọc liên hệ của người yêu cầu thuộc hồ sơ đã chọn.
CREATE OR REPLACE FUNCTION public.get_support_ticket_contacts(p_ticket_ids uuid[])
RETURNS TABLE(ticket_id uuid,requester_id uuid,requester_role text,
  requester_name text,requester_phone text,requester_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM private.require_risk_staff();
  IF coalesce(cardinality(p_ticket_ids),0) NOT BETWEEN 1 AND 200 THEN
    RAISE EXCEPTION 'CONTACT_BATCH_INVALID';
  END IF;
  RETURN QUERY SELECT t.id,u.id,u.role::text,u.full_name,u.phone,u.email
  FROM public.support_tickets t JOIN public.users u ON u.id=t.requester_id
  WHERE t.id=ANY(p_ticket_ids);
END;
$$;
REVOKE ALL ON FUNCTION public.get_support_ticket_contacts(uuid[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_support_ticket_contacts(uuid[]) TO authenticated;

-- Khách, tài xế hiện tại và CSKH có quyền đọc trạng thái. Tài xế cũ chỉ biết
-- đơn đã rời khỏi mình và đường dẫn hồ sơ của chính mình, không đọc tài xế mới.
CREATE OR REPLACE FUNCTION public.get_order_driver_monitoring(p_order_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
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
  WHERE t.order_id=p_order_id AND t.requester_id=v_actor AND EXISTS (
    SELECT 1 FROM public.case_messages m WHERE m.ticket_id=t.id AND m.sender_role_snapshot='system')
  ORDER BY t.created_at DESC,t.id LIMIT 1;
  IF v_ticket IS NULL THEN RAISE EXCEPTION 'MONITORING_ACCESS_DENIED' USING ERRCODE='42501'; END IF;
  RETURN jsonb_build_object('order_id',p_order_id,'released',true,
    'support_ticket_id',v_ticket,'server_now',statement_timestamp());
END;
$$;
REVOKE ALL ON FUNCTION public.get_order_driver_monitoring(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_order_driver_monitoring(uuid) TO authenticated;

-- Chỉ hàm nội bộ được tạo hồ sơ hệ thống. Guard vẫn xác minh người yêu cầu
-- thuộc đơn tại thời điểm tạo; sau đổi tài xế, quyền chat bám requester_id.
CREATE OR REPLACE FUNCTION private.create_monitoring_ticket(
  p_order_id uuid,p_requester_id uuid,p_subject text,p_body text,p_existing_id uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_id uuid:=gen_random_uuid(); v_previous text;
BEGIN
  IF p_existing_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.support_tickets
    WHERE id=p_existing_id AND order_id=p_order_id AND requester_id=p_requester_id
      AND status NOT IN ('resolved','closed')) THEN
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
$$;

CREATE OR REPLACE FUNCTION private.process_driver_monitoring()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
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
      v_driver_ticket:=private.create_monitoring_ticket(v_order.id,v_order.driver_id,
        CASE WHEN v_custody THEN 'Giám sát: mất GPS khi đang giữ hàng' ELSE 'Giám sát: thu hồi phân công' END,
        v_body,(v_state->>'driver_ticket_id')::uuid);
      v_customer_ticket:=private.create_monitoring_ticket(v_order.id,v_order.customer_id,
        CASE WHEN v_custody THEN 'Giám sát: cần xác minh hành trình' ELSE 'Giám sát: tìm tài xế thay thế' END,
        v_body,(v_state->>'customer_ticket_id')::uuid);
      v_state:=v_state||jsonb_build_object('incident_reason',v_reason,'incident_at',v_now,
        'driver_ticket_id',v_driver_ticket,'customer_ticket_id',v_customer_ticket);
      IF v_custody THEN
        v_state:=v_state||jsonb_build_object('gps_escalated_gap_at',v_last);
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
$$;

REVOKE ALL ON FUNCTION private.monitoring_distance_m(double precision,double precision,double precision,double precision),
  private.guard_order_driver_monitoring(),private.guard_monitoring_pickup_proof(),
  private.create_monitoring_ticket(uuid,uuid,text,text,uuid),
  private.process_driver_monitoring() FROM PUBLIC,anon,authenticated;

-- Chỉ bật cho phân công mới. Không thu hồi hàng loạt đơn cũ lúc rollout.
-- Không thêm GPS vào orders cũ hoặc suy đoán mốc nhận từ thời gian tạo đơn.
SELECT cron.schedule('driver-assignment-monitoring','5 seconds','SELECT private.process_driver_monitoring()');

-- Hai trigger hỗ trợ hồ sơ hệ thống được bổ sung bên dưới từ định nghĩa hiện có.
CREATE OR REPLACE FUNCTION private.validate_support_ticket_write()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  requester_role public.user_role;
  assignee_role public.user_role;
  accepting boolean := false;
  taking_over boolean := false;
BEGIN
  SELECT role INTO actor_role
  FROM public.users
  WHERE id = actor_id;

  -- Internal monitor context is set only by the private creator, never by a client RPC.
  IF TG_OP = 'INSERT' AND current_setting('giaohang.monitoring_ticket', true) = NEW.id::text THEN
    IF NEW.created_by IS DISTINCT FROM NEW.requester_id OR NOT EXISTS (
      SELECT 1 FROM public.orders o WHERE o.id=NEW.order_id
        AND NEW.requester_id IN (o.customer_id,o.driver_id)
    ) THEN RAISE EXCEPTION 'MONITORING_CASE_CONTEXT_INVALID' USING ERRCODE='42501'; END IF;
    NEW.assigned_to:=NULL; NEW.status:='open'; NEW.priority:='high';
    NEW.resolution:=NULL; NEW.risk_report_id:=NULL; NEW.first_response_at:=NULL;
    NEW.escalated_at:=NULL; NEW.created_at:=clock_timestamp(); NEW.updated_at:=NEW.created_at;
    NEW.response_due_at:=NEW.created_at+interval '10 minutes';
    RETURN NEW;
  END IF;

  IF actor_id IS NULL OR actor_role IS NULL THEN
    IF TG_OP = 'UPDATE' AND actor_id IS NULL THEN
      NEW.updated_at := now();
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Authenticated user profile is required'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF actor_role IN (
      'customer'::public.user_role,
      'driver'::public.user_role
    ) THEN
      NEW.requester_id := actor_id;
      NEW.created_by := actor_id;
      NEW.assigned_to := NULL;
      NEW.status := 'open';
      NEW.resolution := NULL;
      NEW.risk_report_id := NULL;
      NEW.first_response_at := NULL;
      NEW.escalated_at := NULL;
    ELSIF actor_role IN (
      'support'::public.user_role,
      'admin'::public.user_role
    ) THEN
      SELECT role INTO requester_role
      FROM public.users
      WHERE id = NEW.requester_id;
      IF requester_role NOT IN (
        'customer'::public.user_role,
        'driver'::public.user_role
      ) THEN
        RAISE EXCEPTION 'Support ticket requester must be Customer or Driver'
          USING ERRCODE = '23514';
      END IF;
      NEW.created_by := actor_id;
      NEW.assigned_to := COALESCE(NEW.assigned_to, actor_id);
      NEW.status := CASE
        WHEN NEW.assigned_to IS NULL THEN 'open'
        ELSE 'in_progress'
      END;
    ELSE
      RAISE EXCEPTION 'Role cannot create support tickets'
        USING ERRCODE = '42501';
    END IF;

    NEW.created_at := now();
    NEW.updated_at := now();
    NEW.response_due_at := COALESCE(
      NEW.response_due_at,
      now() + interval '4 hours'
    );
    RETURN NEW;
  END IF;

  -- A requester may only touch the activity timestamp and, when replying,
  -- move a waiting case back into the active queue.
  IF actor_role IN (
    'customer'::public.user_role,
    'driver'::public.user_role
  ) THEN
    IF OLD.requester_id = actor_id
      AND (
        NEW.status = OLD.status
        OR (
          OLD.status IN ('waiting_customer','resolved','closed')
          AND NEW.status = 'in_progress'
        )
      )
      AND (
        to_jsonb(NEW) - ARRAY['status', 'updated_at', 'resolved_at']
      ) = (
        to_jsonb(OLD) - ARRAY['status', 'updated_at', 'resolved_at']
      )
      AND NEW.resolved_at IS NOT DISTINCT FROM (CASE
        WHEN OLD.status IN ('resolved','closed') AND NEW.status = 'in_progress'
          THEN NULL::timestamptz
        ELSE OLD.resolved_at
      END) THEN
      IF OLD.status IN ('resolved','closed') AND NEW.status = 'in_progress' THEN
        NEW.resolved_at := NULL;
      END IF;
      NEW.updated_at := now();
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Requester can only update activity by replying'
      USING ERRCODE = '42501';
  END IF;

  IF actor_role NOT IN (
    'support'::public.user_role,
    'admin'::public.user_role
  ) THEN
    RAISE EXCEPTION 'Only Support or Admin can update support tickets'
      USING ERRCODE = '42501';
  END IF;

  accepting := OLD.assigned_to IS NULL
    AND NEW.assigned_to = actor_id
    AND OLD.status = 'open'
    AND NEW.status = 'in_progress';

  taking_over := actor_role = 'admin'::public.user_role
    AND OLD.assigned_to IS DISTINCT FROM actor_id
    AND NEW.assigned_to = actor_id
    AND NEW.status = OLD.status;

  IF NOT accepting
    AND NOT taking_over
    AND OLD.assigned_to IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'Only the assigned staff member can update this ticket'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.requester_id IS DISTINCT FROM OLD.requester_id
    OR NEW.order_id IS DISTINCT FROM OLD.order_id
    OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION 'Ticket requester, order and creator cannot be changed'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.assigned_to IS NOT NULL THEN
    SELECT role INTO assignee_role
    FROM public.users
    WHERE id = NEW.assigned_to;
    IF assignee_role NOT IN (
      'support'::public.user_role,
      'admin'::public.user_role
    ) THEN
      RAISE EXCEPTION 'Ticket assignee must be Support or Admin'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status
    AND NOT accepting
    AND NOT taking_over THEN
    IF NOT (
      (OLD.status = 'open' AND NEW.status IN ('in_progress', 'closed'))
      OR (OLD.status = 'in_progress' AND NEW.status IN (
        'waiting_customer', 'waiting_admin', 'resolved', 'closed'
      ))
      OR (OLD.status = 'waiting_customer' AND NEW.status IN (
        'in_progress', 'resolved', 'closed'
      ))
      OR (OLD.status = 'waiting_admin' AND NEW.status IN (
        'in_progress', 'resolved', 'closed'
      ))
      OR (OLD.status = 'resolved' AND NEW.status IN ('closed', 'in_progress'))
      OR (OLD.status = 'closed' AND NEW.status = 'in_progress')
    ) THEN
      RAISE EXCEPTION 'Invalid support ticket status transition: % -> %',
        OLD.status, NEW.status
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF NEW.status IN ('resolved', 'closed') THEN
    IF NEW.resolution IS NULL OR char_length(trim(NEW.resolution)) < 3 THEN
      RAISE EXCEPTION 'Resolution is required when closing a ticket'
        USING ERRCODE = '23514';
    END IF;
    NEW.resolved_at := COALESCE(OLD.resolved_at, now());
  ELSE
    NEW.resolved_at := NULL;
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION private.seed_support_ticket_message()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE creator_role public.user_role; v_system boolean;
BEGIN
  SELECT role INTO creator_role FROM public.users WHERE id=NEW.created_by;
  v_system:=coalesce(current_setting('giaohang.monitoring_ticket',true)=NEW.id::text,false);
  INSERT INTO public.case_messages(ticket_id,sender_id,sender_role_snapshot,visibility,body,created_at)
  VALUES(NEW.id,NEW.created_by,CASE WHEN v_system THEN 'system' ELSE creator_role::text END,
    'public',NEW.message,NEW.created_at);
  IF NOT v_system AND creator_role IN ('support','admin') THEN
    PERFORM private.enqueue_linked_case_notification(NEW.requester_id,'Yêu cầu hỗ trợ mới',
      NEW.subject,'support_ticket_created',NEW.order_id,NEW.id);
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.validate_support_ticket_write(),private.seed_support_ticket_message()
FROM PUBLIC,anon,authenticated;
