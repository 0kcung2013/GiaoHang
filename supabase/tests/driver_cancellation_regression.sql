-- All fixture data, audit rows and wallet writes are rolled back.
BEGIN;
DO $test$
DECLARE
  customer uuid := gen_random_uuid();
  driver_a uuid := gen_random_uuid();
  driver_b uuid := gen_random_uuid();
  order_a uuid := gen_random_uuid();
  order_b uuid := gen_random_uuid();
  stamp timestamptz;
  deadline timestamptz;
  response jsonb;
  current_order public.orders%ROWTYPE;
  wallet bigint;
BEGIN
  INSERT INTO public.users(id,email,full_name,role) VALUES
    (customer,customer::text || '@cancellation-test.invalid','Cancellation test customer','customer'),
    (driver_a,driver_a::text || '@cancellation-test.invalid','Cancellation test driver A','driver'),
    (driver_b,driver_b::text || '@cancellation-test.invalid','Cancellation test driver B','driver');
  INSERT INTO public.drivers(user_id,is_available,approval_status,current_lat,current_lng,location_updated_at)
  VALUES (driver_a,true,'approved',80,160,clock_timestamp()),(driver_b,true,'approved',80,160,clock_timestamp());
  INSERT INTO public.orders(id,customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,
    delivery_address,delivery_lat,delivery_lng,tracking_code,delivery_fee_payer,payment_status,paid_at)
  VALUES (order_a,customer,driver_a,'picking_up','Test pickup',80,160,'Test delivery',80.01,160.01,
    'GH-CANCEL-TEST-' || order_a::text,'sender','paid',clock_timestamp());
  INSERT INTO public.driver_wallet_transactions(driver_id,order_id,transaction_type,amount,available_delta,idempotency_key)
  VALUES (driver_a,NULL,'cod_settlement',50000,50000,'test-credit:' || driver_a::text);
  INSERT INTO public.driver_wallet_transactions(driver_id,order_id,transaction_type,amount,available_delta,held_delta,idempotency_key)
  VALUES (driver_a,order_a,'cod_hold',10000,-10000,10000,'test-hold:' || order_a::text);

  PERFORM set_config('request.jwt.claim.sub',driver_b::text,true);
  BEGIN
    PERFORM public.cancel_driver_order(order_a,'personal');
    RAISE EXCEPTION 'Expected unassigned rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'DRIVER_NOT_ASSIGNED' THEN RAISE; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub',driver_a::text,true);
  BEGIN
    PERFORM public.cancel_driver_order(order_a,'store_closed');
    RAISE EXCEPTION 'Expected arrival wait rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'STORE_CANCELLATION_WAIT_REQUIRED' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.confirm_driver_pickup_arrival(order_a,80.1,160.1);
    RAISE EXCEPTION 'Expected geofence rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'PICKUP_OUTSIDE_GEOFENCE' THEN RAISE; END IF;
  END;
  response := public.confirm_driver_pickup_arrival(order_a,80,160);
  stamp := (response->>'pickup_arrived_at')::timestamptz;
  response := public.confirm_driver_pickup_arrival(order_a,80,160);
  IF stamp IS DISTINCT FROM (response->>'pickup_arrived_at')::timestamptz THEN
    RAISE EXCEPTION 'Arrival timer restarted';
  END IF;
  BEGIN
    PERFORM public.cancel_driver_order(order_a,'store_closed');
    RAISE EXCEPTION 'Expected ten-minute wait rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'STORE_CANCELLATION_WAIT_REQUIRED' THEN RAISE; END IF;
  END;

  response := public.cancel_driver_order(order_a,'personal');
  deadline := (response->>'locked_until')::timestamptz;
  IF deadline < clock_timestamp()+interval '29 minutes 59 seconds'
    OR deadline > clock_timestamp()+interval '30 minutes 1 second' THEN
    RAISE EXCEPTION 'Cooldown must last exactly thirty minutes';
  END IF;
  SELECT * INTO current_order FROM public.orders WHERE id=order_a;
  IF current_order.status <> 'pending' OR current_order.driver_id IS NOT NULL
    OR current_order.pickup_arrived_at IS NOT NULL OR current_order.payment_status <> 'paid'
    OR current_order.offered_driver_id IS DISTINCT FROM driver_b THEN
    RAISE EXCEPTION 'Personal cancellation must redispatch without changing payment: %', to_jsonb(current_order);
  END IF;
  SELECT sum(available_delta) INTO wallet FROM public.driver_wallet_transactions WHERE driver_id=driver_a AND status='completed';
  IF wallet <> 50000 THEN RAISE EXCEPTION 'Legacy hold was not released'; END IF;
  response := public.cancel_driver_order(order_a,'personal');
  IF deadline IS DISTINCT FROM (response->>'locked_until')::timestamptz THEN
    RAISE EXCEPTION 'Retry extended cooldown';
  END IF;
  IF (SELECT count(*) FROM public.driver_wallet_transactions WHERE order_id=order_a AND transaction_type='cod_release') <> 1 THEN
    RAISE EXCEPTION 'Release duplicated';
  END IF;
  BEGIN
    PERFORM public.accept_order(order_a);
    RAISE EXCEPTION 'Expected accept cooldown rejection';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'DRIVER_ACCEPTANCE_LOCKED' THEN RAISE; END IF; END;
  BEGIN
    PERFORM public.claim_free_pick_order(order_a);
    RAISE EXCEPTION 'Expected FreePick cooldown rejection';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'DRIVER_ACCEPTANCE_LOCKED' THEN RAISE; END IF; END;
  BEGIN
    PERFORM public.get_free_pick_orders_in_view(79.9,159.9,80.1,160.1,10);
    RAISE EXCEPTION 'Expected viewport cooldown rejection';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'DRIVER_ACCEPTANCE_LOCKED' THEN RAISE; END IF; END;
  BEGIN
    PERFORM public.set_driver_online_with_location(80,160,'123456');
    RAISE EXCEPTION 'Expected online cooldown rejection';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'DRIVER_ACCEPTANCE_LOCKED' THEN RAISE; END IF; END;
  IF EXISTS (SELECT 1 FROM public.find_nearest_drivers(80,160,2000,50) WHERE user_id=driver_a) THEN
    RAISE EXCEPTION 'Locked driver leaked into nearest-driver candidates';
  END IF;
  IF private.dispatch_waiting_orders_for_driver(driver_a) IS NOT NULL THEN
    RAISE EXCEPTION 'Locked driver received automatic offer';
  END IF;
  BEGIN
    INSERT INTO public.orders(customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,
      delivery_address,delivery_lat,delivery_lng,tracking_code)
    VALUES (customer,driver_a,'assigned','Test bypass',80,160,'Test delivery',80.01,160.01,
      'GH-CANCEL-BYPASS-' || order_a::text);
    RAISE EXCEPTION 'Expected assigned insert cooldown rejection';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'DRIVER_ACCEPTANCE_LOCKED' THEN RAISE; END IF; END;
  PERFORM set_config('request.jwt.claim.sub',customer::text,true);
  SET LOCAL ROLE authenticated;
  BEGIN
    INSERT INTO public.orders(customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,
      delivery_address,delivery_lat,delivery_lng,tracking_code)
    VALUES (customer,driver_b,'assigned','Test bypass',80,160,'Test delivery',80.01,160.01,
      'GH-CANCEL-CLIENT-' || order_a::text);
    RAISE EXCEPTION 'Expected client assignment insert rejection';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'ORDER_OFFER_SERVER_OWNED' THEN RAISE; END IF; END;
  RESET ROLE;

  -- Release B's offer and prove that expiry restores normal acceptance.
  PERFORM set_config('request.jwt.claim.sub','',true);
  UPDATE public.drivers SET acceptance_locked_until=clock_timestamp()-interval '1 second' WHERE user_id=driver_a;
  UPDATE public.orders SET offered_driver_id=driver_a,offer_expires_at=clock_timestamp()+interval '45 seconds' WHERE id=order_a;
  PERFORM set_config('request.jwt.claim.sub',driver_a::text,true);
  PERFORM public.accept_order(order_a);
  SELECT * INTO current_order FROM public.orders WHERE id=order_a;
  IF current_order.status <> 'assigned' OR current_order.driver_id IS DISTINCT FROM driver_a THEN
    RAISE EXCEPTION 'Acceptance was not restored after expiry';
  END IF;
  -- A preparatory pickup proof must protect custody from personal abandonment.
  UPDATE public.orders SET status='picking_up' WHERE id=order_a;
  INSERT INTO public.order_delivery_proofs(order_id,driver_id,stage,storage_path,captured_lat,captured_lng)
  VALUES (order_a,driver_a,'pickup','test-only-proof',80,160);
  BEGIN
    PERFORM public.cancel_driver_order(order_a,'personal');
    RAISE EXCEPTION 'Expected custody rejection';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'ORDER_ALREADY_PICKED_UP' THEN RAISE; END IF; END;
  IF (public.get_driver_order_cancellation_state(order_a)->>'pickup_confirmed')::boolean IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'UI snapshot must reflect custody proof';
  END IF;
  -- Use a second synthetic driver/order for store-closed cancellation.
  PERFORM set_config('request.jwt.claim.sub','',true);
  INSERT INTO public.orders(id,customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,
    delivery_address,delivery_lat,delivery_lng,tracking_code,delivery_fee_payer,payment_status,paid_at,pickup_arrived_at)
  VALUES (order_b,customer,driver_b,'picking_up','Test store',80,160,'Test delivery',80.01,160.01,
    'GH-CANCEL-TEST-' || order_b::text,'sender','paid',clock_timestamp(),clock_timestamp()-interval '10 minutes 1 second');
  INSERT INTO public.order_payment_sessions(customer_id,provider_txn_ref,amount,status,order_payload,expires_at,order_id)
  VALUES (customer,'test:' || order_b::text,10000,'paid','{}',clock_timestamp()+interval '15 minutes',order_b);
  PERFORM set_config('request.jwt.claim.sub',driver_b::text,true);
  response := public.cancel_driver_order(order_b,'store_closed');
  SELECT * INTO current_order FROM public.orders WHERE id=order_b;
  IF current_order.status <> 'cancelled' OR current_order.cancelled_at IS NULL
    OR current_order.payment_status <> 'refund_required' THEN RAISE EXCEPTION 'Store cancellation/refund incorrect'; END IF;
  IF (SELECT status FROM public.order_payment_sessions WHERE order_id=order_b) <> 'refund_required' THEN
    RAISE EXCEPTION 'Payment session refund missing';
  END IF;
  IF (SELECT acceptance_locked_until FROM public.drivers WHERE user_id=driver_b) IS NOT NULL THEN
    RAISE EXCEPTION 'Store cancellation must not impose cooldown';
  END IF;
  PERFORM public.cancel_driver_order(order_b,'store_closed');
  IF (SELECT count(*) FROM public.order_status_logs WHERE order_id=order_b AND status='cancelled') <> 1 THEN
    RAISE EXCEPTION 'Store cancellation retry duplicated audit';
  END IF;

  IF has_function_privilege('anon','public.cancel_driver_order(uuid,text)','EXECUTE')
    OR has_function_privilege('anon','public.confirm_driver_pickup_arrival(uuid,double precision,double precision)','EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous mutation access';
  END IF;
  IF has_column_privilege('authenticated','public.orders','pickup_arrived_at','UPDATE')
    OR has_column_privilege('authenticated','public.drivers','acceptance_locked_until','UPDATE') THEN
    RAISE EXCEPTION 'Client can tamper with deadlines';
  END IF;
END;
$test$;
ROLLBACK;
