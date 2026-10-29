-- Fixtures, money movements and audit events are all rolled back.
BEGIN;
DO $test$
DECLARE
  c uuid; d uuid; d2 uuid; staff uuid; o uuid;
  pin jsonb; result jsonb; again jsonb; wrong text; n bigint;
BEGIN
  SELECT id INTO STRICT c FROM public.users WHERE role='customer' LIMIT 1;
  SELECT user_id INTO STRICT d FROM public.drivers WHERE approval_status='approved'
    AND COALESCE(acceptance_locked_until,'-infinity')<clock_timestamp() LIMIT 1;
  SELECT user_id INTO STRICT d2 FROM public.drivers WHERE user_id<>d AND approval_status='approved'
    AND COALESCE(acceptance_locked_until,'-infinity')<clock_timestamp() LIMIT 1;
  SELECT id INTO STRICT staff FROM public.users WHERE role IN ('support','admin') LIMIT 1;
  INSERT INTO public.orders(customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,
    delivery_address,delivery_lat,delivery_lng,total_price,delivery_fee,delivery_fee_payer,
    payment_status,payment_mode,goods_value,driver_advance_amount,receiver_collection_amount,
    platform_fee_amount,driver_net_earning)
  VALUES(c,d,'picking_up','Pickup regression',10.773,106.703,'Delivery regression',10.776,
    106.701,0,0,'recipient','not_required','cod',0,0,0,0,0) RETURNING id INTO o;
  INSERT INTO public.order_delivery_proofs(order_id,driver_id,stage,storage_path,captured_lat,captured_lng)
    VALUES(o,d,'pickup','test/pickup.png',10.773,106.703);
  -- Creator-only code access.
  FOREACH staff IN ARRAY ARRAY[d,staff] LOOP
    PERFORM set_config('request.jwt.claim.sub',staff::text,true);
    BEGIN PERFORM public.get_customer_pickup_code(o); RAISE EXCEPTION 'Non-owner read code';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub',c::text,true);
  pin:=public.get_customer_pickup_code(o);
  again:=public.get_customer_pickup_code(o);
  IF pin->>'code' !~ '^[0-9]{4}$' OR pin->>'code' IS DISTINCT FROM again->>'code' THEN
    RAISE EXCEPTION 'Invalid or unstable code'; END IF;
  IF has_function_privilege('anon','public.get_customer_pickup_code(uuid)','execute')
    OR has_function_privilege('anon','public.confirm_driver_pickup_code(uuid,text)','execute')
    OR has_function_privilege('authenticated','private.pickup_handoff_code(uuid,uuid,uuid,text)','execute')
    OR has_table_privilege('authenticated','vault.decrypted_secrets','select') THEN
    RAISE EXCEPTION 'Secret permissions too broad'; END IF;
  IF EXISTS(SELECT 1 FROM public.orders WHERE id=o AND
    (pickup_handoff ? 'code' OR pickup_handoff ? 'pin' OR pickup_handoff ? 'hash')) THEN
    RAISE EXCEPTION 'Public metadata leaked code/hash'; END IF;
  -- Forged metadata, direct UPDATE and legacy RPC must fail.
  PERFORM set_config('request.jwt.claim.sub',d::text,true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN UPDATE public.orders SET pickup_handoff='{"confirmed_at":"2026-10-19"}' WHERE id=o;
    RAISE EXCEPTION 'Forged metadata accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN UPDATE public.orders SET status='delivering' WHERE id=o;
    RAISE EXCEPTION 'Direct delivery bypass';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'PICKUP_CODE_REQUIRED' THEN RAISE; END IF; END;
  EXECUTE 'RESET ROLE';
  BEGIN PERFORM public.confirm_driver_pickup(o); RAISE EXCEPTION 'Legacy pickup bypass';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'PICKUP_CODE_REQUIRED' THEN RAISE; END IF; END;
  BEGIN PERFORM public.advance_driver_order_status(o); RAISE EXCEPTION 'Advance bypass';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'PICKUP_CODE_REQUIRED' THEN RAISE; END IF; END;
  -- Five persisted failures, cooldown, expiry and renewal.
  wrong:=CASE WHEN pin->>'code'='0000' THEN '0001' ELSE '0000' END;
  FOR attempt IN 1..5 LOOP
    result:=public.confirm_driver_pickup_code(o,wrong);
    IF result->>'success'<>'false' THEN RAISE EXCEPTION 'Wrong code accepted'; END IF;
  END LOOP;
  result:=public.confirm_driver_pickup_code(o,pin->>'code');
  IF result->>'error'<>'PICKUP_CODE_LOCKED' THEN RAISE EXCEPTION 'Lock bypassed'; END IF;
  PERFORM set_config('request.jwt.claim.sub',c::text,true);
  PERFORM public.get_customer_pickup_code(o);
  IF (SELECT (pickup_handoff->>'failed_attempts')::integer FROM public.orders WHERE id=o)<>5 THEN
    RAISE EXCEPTION 'Creator reset attempts'; END IF;
  UPDATE public.orders SET pickup_handoff=pickup_handoff || jsonb_build_object(
    'locked_until',clock_timestamp()-interval '1 second',
    'expires_at',clock_timestamp()-interval '1 second') WHERE id=o;
  PERFORM set_config('request.jwt.claim.sub',d::text,true);
  result:=public.confirm_driver_pickup_code(o,pin->>'code');
  IF result->>'error'<>'PICKUP_CODE_EXPIRED' THEN RAISE EXCEPTION 'Expiry bypassed'; END IF;
  PERFORM set_config('request.jwt.claim.sub',c::text,true);
  pin:=public.get_customer_pickup_code(o);
  -- Reassignment invalidates the old code and the former driver.
  BEGIN
    UPDATE public.orders SET driver_id=d2 WHERE id=o;
    IF (SELECT pickup_handoff FROM public.orders WHERE id=o)<>'{}'::jsonb THEN
      RAISE EXCEPTION 'Old challenge survived reassignment'; END IF;
    PERFORM set_config('request.jwt.claim.sub',d::text,true);
    BEGIN PERFORM public.confirm_driver_pickup_code(o,pin->>'code'); RAISE EXCEPTION 'Old driver accepted';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'DRIVER_NOT_ASSIGNED' THEN RAISE; END IF; END;
    RAISE EXCEPTION 'rollback' USING ERRCODE='PZ001';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
  -- Cancel-first serialization.
  BEGIN
    PERFORM set_config('request.jwt.claim.sub',c::text,true);
    PERFORM public.cancel_customer_order(o,c);
    PERFORM set_config('request.jwt.claim.sub',d::text,true);
    BEGIN PERFORM public.confirm_driver_pickup_code(o,pin->>'code'); RAISE EXCEPTION 'Cancelled order revived';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'ORDER_NOT_PICKING_UP' THEN RAISE; END IF; END;
    RAISE EXCEPTION 'rollback' USING ERRCODE='PZ001';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
  -- Geofence and missing proof leave no custody receipt.
  PERFORM set_config('request.jwt.claim.sub',d::text,true);
  BEGIN
    UPDATE public.order_delivery_proofs SET captured_lat=0,captured_lng=0 WHERE order_id=o;
    BEGIN PERFORM public.confirm_driver_pickup_code(o,pin->>'code'); RAISE EXCEPTION 'Geofence bypassed';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'PICKUP_OUTSIDE_GEOFENCE' THEN RAISE; END IF; END;
    IF (SELECT actual_picked_up_at FROM public.orders WHERE id=o) IS NOT NULL THEN
      RAISE EXCEPTION 'Failed proof committed custody'; END IF;
    RAISE EXCEPTION 'rollback' USING ERRCODE='PZ001';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
  BEGIN
    DELETE FROM public.order_delivery_proofs WHERE order_id=o;
    BEGIN PERFORM public.confirm_driver_pickup_code(o,pin->>'code'); RAISE EXCEPTION 'Missing proof accepted';
    EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'PICKUP_PROOF_LOCATION_REQUIRED' THEN RAISE; END IF; END;
    RAISE EXCEPTION 'rollback' USING ERRCODE='PZ001';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
  -- Confirm-first serialization, atomic delivery and idempotent retry.
  result:=public.confirm_driver_pickup_code(o,pin->>'code');
  IF result->>'success'<>'true' OR NOT EXISTS(SELECT 1 FROM public.orders WHERE id=o
    AND status='delivering' AND actual_picked_up_at IS NOT NULL
    AND pickup_handoff->>'method'='customer_code' AND NOT(pickup_handoff ? 'nonce')) THEN
    RAISE EXCEPTION 'Non-atomic confirmation'; END IF;
  SELECT count(*) INTO n FROM public.order_status_logs WHERE order_id=o;
  again:=public.confirm_driver_pickup_code(o,pin->>'code');
  IF result->>'confirmed_at' IS DISTINCT FROM again->>'confirmed_at'
    OR (SELECT count(*) FROM public.order_status_logs WHERE order_id=o)<>n THEN
    RAISE EXCEPTION 'Replay duplicated receipt/logs'; END IF;
  BEGIN PERFORM public.cancel_driver_order(o,'personal'); RAISE EXCEPTION 'Driver abandoned custody';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'ORDER_ALREADY_PICKED_UP' THEN RAISE; END IF; END;
  PERFORM set_config('request.jwt.claim.sub',c::text,true);
  BEGIN PERFORM public.cancel_customer_order(o,c); RAISE EXCEPTION 'Customer cancelled custody';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT IN('ORDER_ALREADY_PICKED_UP','ORDER_NOT_CANCELLABLE')
    THEN RAISE; END IF; END;
  pin:=public.get_customer_pickup_code(o);
  IF pin ? 'code' OR pin->>'confirmed_at' IS NULL THEN RAISE EXCEPTION 'Consumed code exposed'; END IF;
  BEGIN UPDATE public.orders SET driver_id=NULL,status='pending' WHERE id=o; RAISE EXCEPTION 'Custody reset';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'ORDER_ALREADY_PICKED_UP' THEN RAISE; END IF; END;
  PERFORM set_config('request.jwt.claim.sub','',true);
  BEGIN PERFORM public.confirm_driver_pickup_code(o,'0000'); RAISE EXCEPTION 'Anonymous accepted';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'AUTH_REQUIRED' THEN RAISE; END IF; END;
END;
$test$;
ROLLBACK;
SELECT 'pickup handoff regression passed; fixtures rolled back' AS result;
