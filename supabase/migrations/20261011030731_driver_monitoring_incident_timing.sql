-- Preserve incident timing in the case after a new assignment resets monitoring.
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
        ||E'\nGPS hợp lệ cuối: '||CASE WHEN v_state->>'last_received_at' IS NULL
        THEN 'Chưa nhận mẫu hợp lệ kể từ khi nhận đơn.'
        ELSE to_char(v_last AT TIME ZONE 'Asia/Ho_Chi_Minh','DD/MM/YYYY HH24:MI:SS') END
        ||E'\nXuất phát: '||CASE WHEN v_state->>'departed_at' IS NULL THEN 'Chưa xác nhận.'
        ELSE to_char((v_state->>'departed_at')::timestamptz AT TIME ZONE 'Asia/Ho_Chi_Minh','DD/MM/YYYY HH24:MI:SS') END
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

