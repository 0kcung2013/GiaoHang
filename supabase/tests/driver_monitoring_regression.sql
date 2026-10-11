-- Chạy sau driver_assignment_monitoring; tất cả dữ liệu fixture đều rollback.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT set_config('giaohang.road_dispatch_requested','yes',true);
SELECT set_config('request.jwt.claims','{}',true);

CREATE FUNCTION pg_temp.monitor_order(p_customer uuid,p_driver uuid,p_minutes integer DEFAULT 0)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid:=gen_random_uuid();
BEGIN
  INSERT INTO public.orders(id,customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,
    delivery_address,delivery_lat,delivery_lng,tracking_code)
  VALUES(v_id,p_customer,p_driver,'assigned','Monitoring fixture pickup',10.78,106.7,
    'Monitoring fixture delivery',10.79,106.71,'TEST-MONITOR-'||v_id::text);
  UPDATE public.orders SET driver_monitoring=driver_monitoring||jsonb_build_object(
    'accepted_at',clock_timestamp()-make_interval(mins=>p_minutes),
    'last_received_at',clock_timestamp(),'anchor_lat',10.77,'anchor_lng',106.7,
    'at_pickup_at',NULL) WHERE id=v_id;
  RETURN v_id;
END;
$$;

DO $$
DECLARE
  v_driver uuid; v_other uuid; v_customer uuid; v_staff uuid; v_ticket uuid; v_customer_ticket uuid;
  v_order uuid; v_five uuid; v_eight uuid; v_gap uuid; v_proof uuid;
  v_state jsonb; v_old_assignment text; v_now timestamptz; v_lock timestamptz;
  v_minutes integer; v_eta jsonb;
BEGIN
  SELECT d.user_id INTO STRICT v_driver FROM public.drivers d
  WHERE coalesce(d.acceptance_locked_until,'-infinity')<=clock_timestamp()
    AND NOT EXISTS(SELECT 1 FROM public.orders WHERE driver_id=d.user_id
      AND status IN ('assigned','picking_up','delivering','return_approved','returning'))
  ORDER BY d.user_id LIMIT 1;
  SELECT d.user_id INTO STRICT v_other FROM public.drivers d WHERE d.user_id<>v_driver
    AND coalesce(d.acceptance_locked_until,'-infinity')<=clock_timestamp()
    AND NOT EXISTS(SELECT 1 FROM public.orders WHERE driver_id=d.user_id
      AND status IN ('assigned','picking_up','delivering','return_approved','returning'))
    ORDER BY d.user_id LIMIT 1;
  SELECT id INTO STRICT v_customer FROM public.users WHERE role='customer' LIMIT 1;
  SELECT id INTO STRICT v_staff FROM public.users WHERE role IN ('support','admin') LIMIT 1;
  SELECT acceptance_locked_until INTO v_lock FROM public.drivers WHERE user_id=v_driver;

  -- Mốc 5 / 8 và retry không nhắc lại. GPS còn mới nên đây là chưa xuất phát.
  v_five:=pg_temp.monitor_order(v_customer,v_driver,5);
  PERFORM private.process_driver_monitoring();
  PERFORM private.process_driver_monitoring();
  IF (SELECT count(*) FROM public.notifications WHERE order_id=v_five
    AND user_id=v_driver AND title='Đã hết 5 phút chuẩn bị')<>1
    OR (SELECT driver_id FROM public.orders WHERE id=v_five)<>v_driver THEN
    RAISE EXCEPTION '5 minute reminder/retry failed'; END IF;
  UPDATE public.orders SET driver_monitoring=driver_monitoring||jsonb_build_object(
    'accepted_at',clock_timestamp()-interval '8 minutes') WHERE id=v_five;
  PERFORM private.process_driver_monitoring();
  PERFORM private.process_driver_monitoring();
  IF (SELECT count(*) FROM public.notifications WHERE order_id=v_five
    AND user_id=v_driver AND title='Cần xuất phát ngay')<>1 THEN RAISE EXCEPTION '8 minute warning failed'; END IF;

  -- Hết 10 phút: cùng đơn, tìm lại 15 phút, xóa ETA/hạn, không phạt từ chối.
  UPDATE public.orders SET driver_monitoring=driver_monitoring||jsonb_build_object(
    'accepted_at',clock_timestamp()-interval '10 minutes'),
    estimated_delivery_at=clock_timestamp()+interval '30 minutes' WHERE id=v_five;
  PERFORM private.process_driver_monitoring();
  PERFORM private.process_driver_monitoring();
  IF NOT EXISTS(SELECT 1 FROM public.orders WHERE id=v_five AND driver_id IS NULL
    AND status='pending' AND assignment_expires_at>clock_timestamp()+interval '14 minutes'
    AND delivery_eta IS NULL AND estimated_delivery_at IS NULL AND rejected_by ? v_driver::text)
    OR (SELECT count(*) FROM public.order_status_logs WHERE order_id=v_five
      AND title='Hệ thống thu hồi phân công')<>1
    OR (SELECT count(*) FROM public.support_tickets WHERE order_id=v_five)<>2
    OR EXISTS(SELECT 1 FROM public.order_status_logs WHERE order_id=v_five
      AND title='Tài xế từ chối lời mời')
    OR (SELECT acceptance_locked_until FROM public.drivers WHERE user_id=v_driver) IS DISTINCT FROM v_lock THEN
    RAISE EXCEPTION 'Reassignment/case idempotency or refusal isolation failed'; END IF;
  SELECT id INTO STRICT v_ticket FROM public.support_tickets
    WHERE order_id=v_five AND requester_id=v_driver;
  IF NOT EXISTS(SELECT 1 FROM public.case_messages WHERE ticket_id=v_ticket
    AND sender_role_snapshot='system' AND body LIKE '%GPS hợp lệ cuối:%'
    AND body LIKE '%Xuất phát:%') THEN RAISE EXCEPTION 'Missing system author or durable incident timing'; END IF;
  SELECT id INTO STRICT v_customer_ticket FROM public.support_tickets
    WHERE order_id=v_five AND requester_id=v_customer;

  -- Tài xế cũ và CSKH vẫn chat; liên hệ bám người mở hồ sơ.
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_driver,'role','authenticated')::text,true);
  PERFORM public.post_support_ticket_message(v_ticket,'Tôi cần giải thích sự cố GPS.','public');
  v_state:=public.get_order_driver_monitoring(v_five);
  IF v_state->>'released'<>'true' OR v_state ? 'driver_id' THEN RAISE EXCEPTION 'Former driver snapshot leaked'; END IF;
  BEGIN
    PERFORM public.get_support_ticket_contacts(ARRAY[v_ticket]);
    RAISE EXCEPTION 'Driver read staff contacts';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_customer,'role','authenticated')::text,true);
  BEGIN
    PERFORM public.post_support_ticket_message(v_ticket,'Không thuộc hồ sơ.','public');
    RAISE EXCEPTION 'Customer posted to driver case';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_staff,'role','authenticated')::text,true);
  PERFORM public.accept_support_ticket(v_ticket);
  PERFORM public.post_support_ticket_message(v_ticket,'CSKH đã nhận và đang kiểm tra.','public');
  PERFORM public.post_support_ticket_message(v_ticket,'Ghi chú xác minh nội bộ.','internal');
  IF NOT EXISTS(SELECT 1 FROM public.get_support_ticket_contacts(ARRAY[v_ticket])
    WHERE requester_id=v_driver AND requester_role='driver') THEN RAISE EXCEPTION 'Former driver contacts lost'; END IF;
  PERFORM set_config('request.jwt.claims','{}',true);

  -- Người mới nhận reset assignment, hồ sơ cũ vẫn hoạt động và không lộ GPS mới.
  SELECT driver_monitoring->>'assignment_id' INTO v_old_assignment FROM public.orders WHERE id=v_five;
  UPDATE public.orders SET driver_id=v_other,status='assigned' WHERE id=v_five;
  IF (SELECT driver_monitoring->>'assignment_id' FROM public.orders WHERE id=v_five)=v_old_assignment
    OR (SELECT driver_monitoring->>'reclaimed_at' FROM public.orders WHERE id=v_five) IS NOT NULL THEN
    RAISE EXCEPTION 'New assignment retained old timer'; END IF;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_driver,'role','authenticated')::text,true);
  PERFORM public.post_support_ticket_message(v_ticket,'Tôi vẫn trả lời được sau khi đổi tài xế.','public');
  IF (public.get_order_driver_monitoring(v_five)->>'released')<>'true' THEN RAISE EXCEPTION 'Old driver lost case after new assignment'; END IF;

  -- Dùng role authenticated thực để kiểm tra RLS, không chỉ auth.uid() dưới postgres.
  EXECUTE 'SET LOCAL ROLE authenticated';
  IF EXISTS(SELECT 1 FROM public.orders WHERE id=v_five)
    OR EXISTS(SELECT 1 FROM public.support_tickets WHERE id=v_customer_ticket)
    OR EXISTS(SELECT 1 FROM public.case_messages WHERE ticket_id=v_customer_ticket)
    OR EXISTS(SELECT 1 FROM public.case_messages WHERE ticket_id=v_ticket AND visibility<>'public')
    OR NOT EXISTS(SELECT 1 FROM public.case_messages WHERE ticket_id=v_ticket AND sender_role_snapshot='system') THEN
    RAISE EXCEPTION 'Former driver RLS leaked order, other case, internal note or lost own case'; END IF;
  PERFORM public.post_support_ticket_message(v_ticket,'Trả lời qua đúng quyền authenticated.','public');
  BEGIN
    INSERT INTO public.case_messages(ticket_id,sender_id,sender_role_snapshot,visibility,body)
      VALUES(v_ticket,v_driver,'system','public','Giả mạo hệ thống.');
    RAISE EXCEPTION 'Client forged system author';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.record_driver_monitoring_position(v_five,10.77,106.7,5,clock_timestamp());
    RAISE EXCEPTION 'Former driver renewed new assignment GPS';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_other,'role','authenticated')::text,true);
  IF NOT EXISTS(SELECT 1 FROM public.orders WHERE id=v_five)
    OR EXISTS(SELECT 1 FROM public.case_messages WHERE ticket_id=v_ticket) THEN
    RAISE EXCEPTION 'New driver RLS lost own order or leaked former case'; END IF;
  BEGIN
    UPDATE public.orders SET driver_monitoring=driver_monitoring||jsonb_build_object('departed_at',clock_timestamp())
      WHERE id=v_five;
    RAISE EXCEPTION 'Client changed server-owned monitoring';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_customer,'role','authenticated')::text,true);
  IF EXISTS(SELECT 1 FROM public.case_messages WHERE ticket_id=v_ticket)
    OR NOT EXISTS(SELECT 1 FROM public.case_messages WHERE ticket_id=v_customer_ticket) THEN
    RAISE EXCEPTION 'Customer case RLS isolation failed'; END IF;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_staff,'role','authenticated')::text,true);
  IF NOT EXISTS(SELECT 1 FROM public.get_support_ticket_contacts(ARRAY[v_ticket])
    WHERE requester_id=v_driver AND requester_role='driver')
    OR NOT EXISTS(SELECT 1 FROM public.case_messages WHERE ticket_id=v_ticket AND visibility='internal') THEN
    RAISE EXCEPTION 'CSKH authenticated contacts or internal access failed'; END IF;
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims','{}',true);
  UPDATE public.orders SET status='cancelled' WHERE id=v_five;

  -- Có xuất phát, đến điểm lấy: không thu hồi vì không di chuyển; điểm GPS cũ
  -- và sai số lớn không được làm mới bộ đếm mất GPS.
  v_order:=pg_temp.monitor_order(v_customer,v_driver,11);
  UPDATE public.orders SET driver_monitoring=driver_monitoring||jsonb_build_object('departed_at',clock_timestamp()-interval '8 minutes') WHERE id=v_order;
  PERFORM private.process_driver_monitoring();
  IF (SELECT driver_id FROM public.orders WHERE id=v_order)<>v_driver THEN RAISE EXCEPTION 'Stationary after departure reclaimed'; END IF;
  UPDATE public.orders SET status='cancelled' WHERE id=v_order;
  v_order:=pg_temp.monitor_order(v_customer,v_driver,11);
  UPDATE public.orders SET driver_monitoring=driver_monitoring||jsonb_build_object('at_pickup_at',clock_timestamp()-interval '8 minutes') WHERE id=v_order;
  PERFORM private.process_driver_monitoring();
  IF (SELECT driver_id FROM public.orders WHERE id=v_order)<>v_driver THEN RAISE EXCEPTION 'Waiting at pickup reclaimed'; END IF;
  UPDATE public.orders SET status='cancelled' WHERE id=v_order;

  -- Mất GPS độc lập: nhắc 5, cảnh báo 9, khôi phục trước 10 hủy bộ đếm.
  v_gap:=pg_temp.monitor_order(v_customer,v_driver,11);
  UPDATE public.orders SET driver_monitoring=driver_monitoring||jsonb_build_object(
    'departed_at',clock_timestamp()-interval '9 minutes','last_received_at',clock_timestamp()-interval '5 minutes') WHERE id=v_gap;
  PERFORM private.process_driver_monitoring();
  UPDATE public.orders SET driver_monitoring=driver_monitoring||jsonb_build_object(
    'last_received_at',clock_timestamp()-interval '9 minutes') WHERE id=v_gap;
  PERFORM private.process_driver_monitoring();
  IF (SELECT count(*) FROM public.notifications WHERE order_id=v_gap
    AND user_id=v_driver AND title IN ('Mất cập nhật vị trí','Cần khôi phục GPS ngay'))<>2 THEN
    RAISE EXCEPTION 'GPS gap warnings failed'; END IF;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_driver,'role','authenticated')::text,true);
  IF (public.record_driver_monitoring_position(v_gap,10.77,106.7,80,clock_timestamp())->>'accepted')<>'false'
    OR (public.record_driver_monitoring_position(v_gap,10.77,106.7,5,clock_timestamp()-interval '2 minutes')->>'accepted')<>'false' THEN
    RAISE EXCEPTION 'Invalid GPS renewed monitoring'; END IF;
  v_now:=clock_timestamp();
  IF (public.record_driver_monitoring_position(v_gap,10.77,106.7,5,v_now)->>'accepted')<>'true'
    OR (public.record_driver_monitoring_position(v_gap,10.77,106.7,5,v_now)->>'accepted')<>'false' THEN
    RAISE EXCEPTION 'Fresh GPS/replay gate failed'; END IF;
  PERFORM set_config('request.jwt.claims','{}',true);
  PERFORM private.process_driver_monitoring();
  IF (SELECT driver_monitoring->>'gps_warned_at' FROM public.orders WHERE id=v_gap) IS NOT NULL
    OR (SELECT driver_id FROM public.orders WHERE id=v_gap)<>v_driver THEN RAISE EXCEPTION 'Recovery did not reset gap'; END IF;
  UPDATE public.orders SET driver_monitoring=driver_monitoring||jsonb_build_object(
    'last_received_at',clock_timestamp()-interval '10 minutes') WHERE id=v_gap;
  PERFORM private.process_driver_monitoring();
  IF (SELECT driver_id FROM public.orders WHERE id=v_gap) IS NOT NULL THEN RAISE EXCEPTION 'GPS expiry failed'; END IF;

  -- Bằng chứng đã nhận là rào chắn cả khi trạng thái chưa kịp đổi.
  v_proof:=pg_temp.monitor_order(v_customer,v_driver,11);
  INSERT INTO public.order_delivery_proofs(order_id,driver_id,stage,storage_path,captured_at)
    VALUES(v_proof,v_driver,'pickup','r2://fixture/proof.webp',clock_timestamp());
  UPDATE public.orders SET driver_monitoring=driver_monitoring||jsonb_build_object(
    'last_received_at',clock_timestamp()-interval '11 minutes') WHERE id=v_proof;
  PERFORM private.process_driver_monitoring();
  PERFORM private.process_driver_monitoring();
  IF (SELECT driver_id FROM public.orders WHERE id=v_proof)<>v_driver
    OR (SELECT count(*) FROM public.support_tickets WHERE order_id=v_proof)<>2 THEN
    RAISE EXCEPTION 'Pickup proof custody/idempotent escalation failed'; END IF;
  UPDATE public.orders SET driver_monitoring=driver_monitoring||jsonb_build_object(
    'last_received_at',clock_timestamp(),'departed_at',clock_timestamp()) WHERE id=v_proof;
  -- Kết thúc fixture để dành tài xế cho ca sau; không mô phỏng thao tác hủy của tài xế.
  UPDATE public.orders SET status='cancelled' WHERE id=v_proof;

  -- Đang giao / actual_picked_up_at cũng là rào chắn, kể cả không có ảnh fixture.
  v_order:=pg_temp.monitor_order(v_customer,v_driver,11);
  UPDATE public.orders SET status='delivering',actual_picked_up_at=clock_timestamp(),
    driver_monitoring=driver_monitoring||jsonb_build_object(
      'last_received_at',clock_timestamp()-interval '11 minutes') WHERE id=v_order;
  PERFORM private.process_driver_monitoring(); PERFORM private.process_driver_monitoring();
  IF (SELECT driver_id FROM public.orders WHERE id=v_order)<>v_driver
    OR (SELECT count(*) FROM public.support_tickets WHERE order_id=v_order)<>2
    OR EXISTS(SELECT 1 FROM public.order_status_logs WHERE order_id=v_order AND title='Hệ thống thu hồi phân công') THEN
    RAISE EXCEPTION 'Actual pickup custody was reassigned'; END IF;
  UPDATE public.orders SET status='delivered' WHERE id=v_order;
  -- Một hồ sơ mất GPS sau nhận hàng không được biến bàn giao thủ công thành
  -- thông báo thu hồi tự động cho tài xế cũ.
  UPDATE public.orders SET driver_id=NULL WHERE id=v_order;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_driver,'role','authenticated')::text,true);
  v_state:=public.get_order_driver_monitoring(v_order);
  IF v_state->>'released'<>'false' OR v_state->>'status'<>'not_assigned' THEN
    RAISE EXCEPTION 'Custody case misclassified normal unassignment'; END IF;
  PERFORM set_config('request.jwt.claims','{}',true);

  -- Hai mẫu dịch chuyển có xác nhận theo giờ server. Du hành mốc candidate
  -- trong fixture thay cho chờ 10 giây; client thực không được sửa cột này.
  FOREACH v_minutes IN ARRAY ARRAY[4,6] LOOP
    v_order:=pg_temp.monitor_order(v_customer,v_driver,v_minutes);
    UPDATE public.orders SET delivery_eta=jsonb_build_object('driver_id',v_driver,
      'assigned_at',clock_timestamp()-make_interval(mins=>v_minutes),
      'calculation_mode','assignment_once_v1','initial_remaining_minutes',40,
      'initial_predicted_at',clock_timestamp()+interval '40 minutes',
      'remaining_minutes',40,'predicted_at',clock_timestamp()+interval '40 minutes',
      'pickup_service_minutes',5,'delivery_service_minutes',5) WHERE id=v_order;
    PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_driver,'role','authenticated')::text,true);
    v_now:=clock_timestamp();
    PERFORM public.record_driver_monitoring_position(v_order,10.77,106.7,5,v_now-interval '15 seconds');
    PERFORM public.record_driver_monitoring_position(v_order,10.7712,106.7,5,v_now);
    IF (SELECT driver_monitoring->>'departed_at' FROM public.orders WHERE id=v_order) IS NOT NULL THEN
      RAISE EXCEPTION 'One displacement sample counted as departure'; END IF;
    PERFORM set_config('request.jwt.claims','{}',true);
    UPDATE public.orders SET driver_monitoring=driver_monitoring||jsonb_build_object(
      'departure_candidate_at',clock_timestamp()-interval '11 seconds') WHERE id=v_order;
    PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_driver,'role','authenticated')::text,true);
    PERFORM public.record_driver_monitoring_position(v_order,10.7712,106.7,5,v_now+interval '1 second');
    SELECT delivery_eta INTO v_eta FROM public.orders WHERE id=v_order;
    IF (v_eta->>'remaining_minutes')::numeric<>(CASE WHEN v_minutes=4 THEN 35 ELSE 40 END)
      OR (v_eta->>'initial_remaining_minutes')::numeric<>40
      OR (v_eta->>'pickup_service_minutes')::numeric<>5
      OR (v_eta->>'delivery_service_minutes')::numeric<>5
      OR (SELECT driver_monitoring->>'departed_at' FROM public.orders WHERE id=v_order) IS NULL THEN
      RAISE EXCEPTION 'Fixed ETA changed components or early preparation exception failed'; END IF;
    PERFORM public.record_driver_monitoring_position(v_order,10.7712,106.7,5,v_now+interval '2 seconds');
    IF (SELECT delivery_eta->>'remaining_minutes' FROM public.orders WHERE id=v_order)<>v_eta->>'remaining_minutes' THEN
      RAISE EXCEPTION 'GPS changed fixed ETA a second time'; END IF;
    PERFORM set_config('request.jwt.claims','{}',true);
    UPDATE public.orders SET status='cancelled' WHERE id=v_order;
  END LOOP;

  -- Hai nguyên nhân đồng thời chỉ một lần; chứng cứ nộp sau thu hồi bị chặn.
  v_order:=pg_temp.monitor_order(v_customer,v_driver,11);
  UPDATE public.orders SET driver_monitoring=driver_monitoring||jsonb_build_object(
    'last_received_at',clock_timestamp()-interval '11 minutes') WHERE id=v_order;
  INSERT INTO public.driver_wallet_transactions(driver_id,order_id,transaction_type,amount,
    available_delta,held_delta,idempotency_key,completed_at)
    VALUES(v_driver,v_order,'cod_hold',50000,-50000,50000,'fixture:'||v_order,clock_timestamp());
  PERFORM private.process_driver_monitoring(); PERFORM private.process_driver_monitoring();
  IF (SELECT count(*) FROM public.order_status_logs WHERE order_id=v_order AND title='Hệ thống thu hồi phân công')<>1
    OR (SELECT sum(held_delta) FROM public.driver_wallet_transactions WHERE order_id=v_order AND driver_id=v_driver)<>0
    OR (SELECT count(*) FROM public.driver_wallet_transactions WHERE order_id=v_order AND transaction_type='cod_release')<>1 THEN
    RAISE EXCEPTION 'Two causes or COD release processed twice'; END IF;
  BEGIN
    INSERT INTO public.order_delivery_proofs(order_id,driver_id,stage,storage_path,captured_at)
      VALUES(v_order,v_driver,'pickup','r2://fixture/late-proof.webp',clock_timestamp());
    RAISE EXCEPTION 'Late pickup proof allowed';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'PICKUP_ASSIGNMENT_CHANGED' THEN RAISE; END IF;
  END;
END;
$$;
SELECT 'PASS: monitoring reminders, revoke, GPS recovery, custody, cases, contacts, chat, privacy, COD and idempotency' AS result;
ROLLBACK;
