-- Synthetic fixtures only. Orders, notifications, audit and wallet data roll back.
BEGIN;
DO $test$
DECLARE
  customer uuid := gen_random_uuid();
  driver_a uuid := gen_random_uuid();
  driver_b uuid := gen_random_uuid();
  staff uuid := gen_random_uuid();
  other_staff uuid := gen_random_uuid();
  v_order_id uuid;
  report_id uuid;
  scenario text;
  result public.risk_report_interventions%ROWTYPE;
  current_order public.orders%ROWTYPE;
  released_at timestamptz;
  event_count bigint;
BEGIN
  INSERT INTO public.users(id,email,full_name,role) VALUES
    (customer,customer::text || '@support-cancel-test.invalid','Test customer','customer'),
    (driver_a,driver_a::text || '@support-cancel-test.invalid','Test driver A','driver'),
    (driver_b,driver_b::text || '@support-cancel-test.invalid','Test driver B','driver'),
    (staff,staff::text || '@support-cancel-test.invalid','Test support','support'),
    (other_staff,other_staff::text || '@support-cancel-test.invalid','Other support','support');
  INSERT INTO public.drivers(user_id,is_available,approval_status,current_lat,current_lng,location_updated_at)
    VALUES (driver_a,true,'approved',80,160,clock_timestamp()),
      (driver_b,true,'approved',80,160,clock_timestamp());

  FOREACH scenario IN ARRAY ARRAY[
    'assigned', 'picking_up', 'legacy_handoff', 'picked_up', 'delivering',
    'return_required', 'stale_driver', 'other_custody', 'pickup_wins'
  ] LOOP
    -- Roll back each scenario independently: one active order per driver.
    BEGIN
    v_order_id := gen_random_uuid();
    report_id := gen_random_uuid();
    PERFORM set_config('request.jwt.claim.sub','',true);
    INSERT INTO public.orders(id,customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,
        delivery_address,delivery_lat,delivery_lng,tracking_code,delivery_fee_payer,payment_status,paid_at)
      VALUES(v_order_id,customer,driver_a,
        CASE WHEN scenario = 'assigned' THEN 'assigned'::public.order_status
          WHEN scenario = 'delivering' THEN 'delivering'::public.order_status
          ELSE 'picking_up'::public.order_status END,
        'Test pickup',80,160,'Test delivery',80.01,160.01,
        'GH-SUPPORT-CANCEL-' || v_order_id::text,'sender','paid',clock_timestamp());
    PERFORM set_config('request.jwt.claim.sub',staff::text,true);
    INSERT INTO public.risk_reports(id,order_id,reported_by,updated_by,assigned_to,
        category,severity,status,title,description,reporter_role_snapshot)
      VALUES(report_id,v_order_id,staff,staff,staff,'cargo_issue','medium','investigating',
        'Synthetic cancellation','Synthetic pre-pickup cancellation regression','support');
    PERFORM set_config('request.jwt.claim.sub','',true);
    IF scenario = 'legacy_handoff' THEN
      UPDATE public.risk_report_interventions SET state='handoff_required',
        instruction='Legacy incorrect handoff' WHERE risk_report_id=report_id;
    ELSIF scenario = 'return_required' THEN
      UPDATE public.risk_report_interventions SET state='return_required',
        instruction='Keep existing return workflow' WHERE risk_report_id=report_id;
    ELSIF scenario = 'stale_driver' THEN
      UPDATE public.risk_report_interventions SET driver_id=driver_b
        WHERE risk_report_id=report_id;
    ELSIF scenario = 'other_custody' THEN
      PERFORM set_config('request.jwt.claim.sub',staff::text,true);
      INSERT INTO public.risk_reports(order_id,reported_by,updated_by,assigned_to,
          category,severity,status,title,description,reporter_role_snapshot)
        VALUES(v_order_id,staff,staff,staff,'safety','medium','investigating',
          'Other custody decision','Separate existing pending custody decision','support');
      UPDATE public.risk_report_interventions SET state='handoff_required',
        instruction='Other pending custody' WHERE order_id=v_order_id
          AND risk_report_id <> report_id;
    ELSIF scenario = 'picked_up' THEN
      UPDATE public.orders SET actual_picked_up_at=clock_timestamp() WHERE id=v_order_id;
    ELSIF scenario = 'pickup_wins' THEN
      INSERT INTO public.order_delivery_proofs(order_id,driver_id,stage,storage_path,captured_lat,captured_lng)
        VALUES(v_order_id,driver_a,'pickup','synthetic-test-proof',80,160);
      PERFORM set_config('request.jwt.claim.sub',driver_a::text,true);
      SET LOCAL ROLE authenticated;
      PERFORM public.confirm_driver_pickup(v_order_id);
      RESET ROLE;
    END IF;

    -- The RPC must reject another staff member before changing any order.
    PERFORM set_config('request.jwt.claim.sub',other_staff::text,true);
    SET LOCAL ROLE authenticated;
    BEGIN
      PERFORM public.hold_risk_order_before_pickup(report_id);
      RAISE EXCEPTION 'Expected report ownership rejection';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    RESET ROLE;
    PERFORM set_config('request.jwt.claim.sub',staff::text,true);
    SET LOCAL ROLE authenticated;
    IF scenario IN ('assigned','picking_up','legacy_handoff') THEN
      result := public.hold_risk_order_before_pickup(report_id);
      IF result.state <> 'released' OR result.driver_id IS DISTINCT FROM driver_a
        OR result.driver_released_at IS NULL THEN
        RAISE EXCEPTION 'Missing pre-pickup driver release: %',scenario;
      END IF;
      SELECT * INTO current_order FROM public.orders WHERE id=v_order_id;
      IF current_order.status <> 'pending' OR current_order.driver_id IS NOT NULL
        OR current_order.risk_hold_report_id IS NOT NULL
        OR current_order.customer_id IS DISTINCT FROM customer
        OR current_order.payment_status <> 'paid' THEN
        RAISE EXCEPTION 'Cancellation changed customer order/payment: %',scenario;
      END IF;
      released_at := result.driver_released_at;
      SELECT count(*) INTO event_count FROM public.risk_report_events
        WHERE risk_report_id=report_id;
      result := public.hold_risk_order_before_pickup(report_id,'Retry');
      IF result.driver_released_at IS DISTINCT FROM released_at
        OR event_count <> (SELECT count(*) FROM public.risk_report_events WHERE risk_report_id=report_id) THEN
        RAISE EXCEPTION 'Retry duplicated cancellation';
      END IF;
      RESET ROLE;
      PERFORM set_config('request.jwt.claim.sub',driver_a::text,true);
      SET LOCAL ROLE authenticated;
      IF NOT EXISTS (SELECT 1 FROM public.risk_report_interventions WHERE risk_report_id=report_id
          AND driver_released_at=released_at) THEN
        RAISE EXCEPTION 'Released driver cannot read cancellation under RLS';
      END IF;
      BEGIN
        PERFORM public.confirm_driver_pickup(v_order_id);
        RAISE EXCEPTION 'Expected pickup rejection after support release';
      EXCEPTION WHEN raise_exception THEN
        IF SQLERRM <> 'DRIVER_NOT_ASSIGNED' THEN RAISE; END IF;
      END;
    ELSE
      BEGIN
        PERFORM public.hold_risk_order_before_pickup(report_id);
        RAISE EXCEPTION 'Expected custody/status rejection: %',scenario;
      EXCEPTION WHEN check_violation THEN NULL;
      END;
      SELECT * INTO current_order FROM public.orders WHERE id=v_order_id;
      IF current_order.driver_id IS DISTINCT FROM driver_a THEN
        RAISE EXCEPTION 'Rejected cancellation unassigned driver: %',scenario;
      END IF;
    END IF;
    RESET ROLE;
    RAISE EXCEPTION 'Rollback successful scenario' USING ERRCODE = 'Z0001';
    EXCEPTION WHEN SQLSTATE 'Z0001' THEN NULL;
    END;
  END LOOP;
END;
$test$;
ROLLBACK;
