-- Regression for the proposed automatic requeue RPCs. Synthetic data rolls back.
-- Expected to fail on the current backend; apply the approved draft locally first.
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
  search_expires_at timestamptz;
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

  INSERT INTO public.driver_wallet_transactions(driver_id,transaction_type,amount,
    available_delta,provider,provider_txn_ref,idempotency_key) VALUES
    (driver_a,'vnpay_topup',500000,500000,'vnpay',driver_a::text,'requeue-wallet:'||driver_a::text),
    (driver_b,'vnpay_topup',500000,500000,'vnpay',driver_b::text,'requeue-wallet:'||driver_b::text);

  FOREACH scenario IN ARRAY ARRAY[
    'assigned', 'picking_up', 'legacy_handoff', 'picked_up', 'delivering',
    'return_required', 'stale_driver', 'other_custody', 'pickup_wins',
    'legacy_closed_hold', 'no_eligible_driver', 'paid_goods_deposit'
  ] LOOP
    -- Roll back each scenario independently: one active order per driver.
    BEGIN
    v_order_id := gen_random_uuid();
    report_id := gen_random_uuid();
    PERFORM set_config('request.jwt.claim.sub','',true);
    INSERT INTO public.orders(id,customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,
        delivery_address,delivery_lat,delivery_lng,tracking_code,delivery_fee_payer,payment_status,paid_at,
        assignment_expires_at,estimated_delivery_at,pickup_arrived_at,
        goods_value,cod_collection_amount,driver_advance_amount,driver_net_earning,
        delivery_fee,total_price,receiver_collection_amount)
      VALUES(v_order_id,customer,driver_a,
        CASE WHEN scenario = 'assigned' THEN 'assigned'::public.order_status
          WHEN scenario = 'delivering' THEN 'delivering'::public.order_status
          ELSE 'picking_up'::public.order_status END,
        'Test pickup',80,160,'Test delivery',80.01,160.01,
        'GH-SUPPORT-CANCEL-' || v_order_id::text,'sender','paid',clock_timestamp(),
        clock_timestamp()-interval '1 minute',clock_timestamp()+interval '1 hour',
        clock_timestamp()-interval '10 minutes',
        CASE WHEN scenario='paid_goods_deposit' THEN 120000 ELSE 0 END,
        CASE WHEN scenario='paid_goods_deposit' THEN 0 ELSE 120000 END,
        120000,25000,25000,
        CASE WHEN scenario='paid_goods_deposit' THEN 25000 ELSE 145000 END,
        CASE WHEN scenario='paid_goods_deposit' THEN 0 ELSE 120000 END);
    PERFORM set_config('request.jwt.claim.sub',staff::text,true);
    INSERT INTO public.risk_reports(id,order_id,reported_by,updated_by,assigned_to,
        category,severity,status,title,description,reporter_role_snapshot)
      VALUES(report_id,v_order_id,staff,staff,staff,'cargo_issue','medium','investigating',
        'Synthetic cancellation','Synthetic pre-pickup cancellation regression','support');
    PERFORM set_config('request.jwt.claim.sub','',true);
    IF scenario = 'legacy_closed_hold' THEN
      UPDATE public.orders SET status='risk_hold',driver_id=NULL,
        risk_hold_report_id=report_id WHERE id=v_order_id;
      UPDATE public.risk_report_interventions SET state='held_before_pickup',
        driver_released_at=clock_timestamp()-interval '1 hour'
        WHERE risk_report_id=report_id;
      UPDATE public.risk_reports SET status='resolved',resolution='Previously closed'
        WHERE id=report_id;
    ELSIF scenario = 'no_eligible_driver' THEN
      UPDATE public.drivers SET is_available=false WHERE user_id=driver_b;
    ELSIF scenario = 'legacy_handoff' THEN
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
    IF scenario='legacy_closed_hold' THEN
      BEGIN
        PERFORM public.resume_risk_held_order(report_id);
        RAISE EXCEPTION 'Expected resume ownership rejection';
      EXCEPTION WHEN insufficient_privilege THEN NULL;
      END;
    END IF;
    RESET ROLE;
    PERFORM set_config('request.jwt.claim.sub',staff::text,true);
    SET LOCAL ROLE authenticated;
    IF scenario IN ('assigned','picking_up','legacy_handoff','legacy_closed_hold',
        'no_eligible_driver','paid_goods_deposit') THEN
      IF scenario='legacy_closed_hold' THEN
        PERFORM public.resume_risk_held_order(report_id);
        SELECT * INTO result FROM public.risk_report_interventions WHERE risk_report_id=report_id;
      ELSE
        result := public.hold_risk_order_before_pickup(report_id);
      END IF;
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

      ASSERT current_order.assignment_expires_at > clock_timestamp()+interval '14 minutes'
        AND current_order.assignment_expires_at <= clock_timestamp()+interval '15 minutes',
        'Search deadline was not restarted';
      ASSERT current_order.assignment_timed_out_at IS NULL
        AND current_order.estimated_delivery_at IS NULL
        AND current_order.pickup_arrived_at IS NULL, 'Previous driver timers leaked into search';
      ASSERT current_order.rejected_by ? driver_a::text, 'Cancelled driver was offered again';
      ASSERT current_order.driver_advance_amount=120000
        AND current_order.driver_net_earning=25000, 'Requeue changed the financial snapshot';
      ASSERT NOT EXISTS(SELECT 1 FROM public.driver_wallet_transactions WHERE order_id=v_order_id),
        'Pre-pickup cancellation changed the wallet';
      IF scenario='no_eligible_driver' THEN
        ASSERT current_order.offered_driver_id IS NULL, 'Ineligible driver received an offer';
      ELSE
        ASSERT current_order.offered_driver_id=driver_b
          AND current_order.offer_expires_at > clock_timestamp(),
          'Requeue did not dispatch a fresh offer';
      END IF;
      IF scenario='legacy_closed_hold' THEN
        ASSERT (SELECT status='resolved' FROM public.risk_reports WHERE id=report_id),
          'Recovery reopened a closed report';
      END IF;
      search_expires_at := current_order.assignment_expires_at;

      released_at := result.driver_released_at;
      SELECT count(*) INTO event_count FROM public.risk_report_events
        WHERE risk_report_id=report_id;
      result := public.hold_risk_order_before_pickup(report_id,'Retry');
      IF result.driver_released_at IS DISTINCT FROM released_at
        OR event_count <> (SELECT count(*) FROM public.risk_report_events WHERE risk_report_id=report_id) THEN
        RAISE EXCEPTION 'Retry duplicated cancellation';
      END IF;

      PERFORM public.resume_risk_held_order(report_id);
      ASSERT (SELECT assignment_expires_at=search_expires_at FROM public.orders WHERE id=v_order_id),
        'Retry extended the search deadline';
      IF scenario<>'no_eligible_driver' THEN
        RESET ROLE;
        PERFORM set_config('request.jwt.claim.sub',driver_b::text,true);
        SET LOCAL ROLE authenticated;
        PERFORM public.accept_order(v_order_id);
        IF scenario='paid_goods_deposit' THEN
          PERFORM public.advance_driver_order_status(v_order_id);
          RESET ROLE;
          INSERT INTO public.order_delivery_proofs(order_id,driver_id,stage,storage_path,captured_lat,captured_lng)
            VALUES(v_order_id,driver_b,'pickup','synthetic-new-driver-proof',80,160);
          SET LOCAL ROLE authenticated;
          PERFORM public.confirm_driver_pickup(v_order_id);
          ASSERT (SELECT available_balance=380000 AND held_balance=120000
            FROM public.get_driver_wallet_summary()), 'New driver deposit was not held correctly';
        END IF;
        RESET ROLE;
        PERFORM set_config('request.jwt.claim.sub',staff::text,true);
        SET LOCAL ROLE authenticated;
        PERFORM public.hold_risk_order_before_pickup(report_id,'Stale retry');
        PERFORM public.resume_risk_held_order(report_id);
        ASSERT (SELECT driver_id=driver_b AND assignment_expires_at=search_expires_at
          FROM public.orders WHERE id=v_order_id), 'Old cancellation removed the new driver';
        ASSERT event_count=(SELECT count(*) FROM public.risk_report_events WHERE risk_report_id=report_id),
          'Retry duplicated reassignment audit';
      END IF;
      RESET ROLE;
      PERFORM set_config('request.jwt.claim.sub',driver_a::text,true);
      SET LOCAL ROLE authenticated;
      IF NOT EXISTS (SELECT 1 FROM public.risk_report_interventions WHERE risk_report_id=report_id
          AND driver_released_at=released_at) THEN
        RAISE EXCEPTION 'Released driver cannot read cancellation under RLS';
      END IF;
      ASSERT (SELECT available_balance=500000 AND held_balance=0
        FROM public.get_driver_wallet_summary()), 'Old driver wallet changed on requeue';
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
