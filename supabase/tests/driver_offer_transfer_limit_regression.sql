-- Run after the separately approved migration. All fixtures, audit, notifications
-- and brief locks on an idle driver are rolled back; no dispatch request is sent.
BEGIN;
SET LOCAL lock_timeout = '5s';
SELECT set_config('giaohang.road_dispatch_requested', 'yes', true);
SELECT set_config('request.jwt.claims', '{}', true);

CREATE FUNCTION pg_temp.transfer_offer(p_customer uuid, p_driver uuid)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid := gen_random_uuid();
BEGIN
  INSERT INTO public.orders(
    id, customer_id, status, pickup_address, pickup_lat, pickup_lng,
    delivery_address, delivery_lat, delivery_lng, tracking_code,
    offered_driver_id, offer_expires_at, assignment_expires_at
  ) VALUES (
    v_id, p_customer, 'confirmed', 'Transfer regression pickup', 10.78, 106.7,
    'Transfer regression delivery', 10.79, 106.71, 'TEST-TRANSFER-' || v_id::text,
    p_driver, CASE WHEN p_driver IS NOT NULL
      THEN clock_timestamp() + interval '45 seconds' END,
    clock_timestamp() + interval '15 minutes'
  );
  RETURN v_id;
END;
$$;

DO $$
DECLARE
  v_driver uuid;
  v_customer uuid;
  v_order uuid;
  v_first uuid;
  v_fourth uuid;
  v_active uuid;
  v_before timestamptz;
  v_lock timestamptz;
  v_intent boolean;
  v_state jsonb;
BEGIN
  SELECT d.user_id, d.is_available INTO STRICT v_driver, v_intent
  FROM public.drivers d JOIN public.users u ON u.id = d.user_id AND u.role = 'driver'
  WHERE (d.acceptance_locked_until IS NULL OR d.acceptance_locked_until <= clock_timestamp())
    AND NOT EXISTS (SELECT 1 FROM public.orders o WHERE o.driver_id = d.user_id
      AND o.status IN ('assigned','picking_up','delivering','return_approved','returning'))
    AND NOT EXISTS (SELECT 1 FROM public.orders o WHERE o.offered_driver_id = d.user_id
      AND o.status IN ('pending','confirmed') AND o.driver_id IS NULL)
    AND NOT EXISTS (SELECT 1 FROM private.driver_transfer_window(d.user_id, clock_timestamp()))
  ORDER BY d.user_id LIMIT 1 FOR UPDATE OF d;
  SELECT id INTO STRICT v_customer FROM public.users WHERE role = 'customer' LIMIT 1;
  PERFORM set_config('test.transfer_driver', v_driver::text, true);
  PERFORM set_config('request.jwt.claims',
    jsonb_build_object('sub',v_driver,'role','authenticated')::text, true);

  v_state := public.get_driver_acceptance_state();
  IF (v_state->>'transfer_count')::integer <> 0 THEN RAISE EXCEPTION 'Nonempty fixture quota'; END IF;

  -- Wrong actor, unoffered order and already-finished assignment cannot consume
  -- a refusal. Real expiry has its own regression.
  v_order := pg_temp.transfer_offer(v_customer, v_driver);
  BEGIN
    PERFORM public.reject_order(v_order, gen_random_uuid()::text);
    RAISE EXCEPTION 'Wrong actor was allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'NOT_ALLOWED' THEN RAISE; END IF; END;
  UPDATE public.orders SET offered_driver_id = NULL, offer_expires_at = NULL WHERE id = v_order;
  v_order := pg_temp.transfer_offer(v_customer, NULL);
  BEGIN
    PERFORM public.reject_order(v_order, v_driver::text);
    RAISE EXCEPTION 'Unoffered order was allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'ORDER_NOT_OFFERED_TO_DRIVER' THEN RAISE; END IF; END;
  v_order := pg_temp.transfer_offer(v_customer, v_driver);
  UPDATE public.orders SET assignment_timed_out_at = clock_timestamp() WHERE id = v_order;
  PERFORM public.reject_order(v_order, v_driver::text);
  UPDATE public.orders SET offered_driver_id = NULL, offer_expires_at = NULL WHERE id = v_order;
  IF (public.get_driver_acceptance_state()->>'transfer_count')::integer <> 0
    THEN RAISE EXCEPTION 'Invalid/unoffered transfers counted'; END IF;

  FOR i IN 1..3 LOOP
    v_order := pg_temp.transfer_offer(v_customer, v_driver);
    PERFORM public.reject_order(v_order, v_driver::text);
    IF i = 1 THEN v_first := v_order; END IF;
    IF (public.get_driver_acceptance_state()->>'transfer_count')::integer <> i
      THEN RAISE EXCEPTION 'Incorrect transfer count at %', i; END IF;
    IF (SELECT acceptance_locked_until > clock_timestamp() FROM public.drivers WHERE user_id = v_driver)
      THEN RAISE EXCEPTION 'Locked before four transfers'; END IF;
    IF (SELECT offered_driver_id FROM public.orders WHERE id = v_order) IS NOT NULL
      OR NOT ((SELECT rejected_by FROM public.orders WHERE id = v_order) ? v_driver::text)
      THEN RAISE EXCEPTION 'Existing redispatch behavior changed'; END IF;
  END LOOP;

  -- Same order after a lost response cannot count again.
  BEGIN
    PERFORM public.reject_order(v_first, v_driver::text);
    RAISE EXCEPTION 'Stale replay was allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'ORDER_NOT_OFFERED_TO_DRIVER' THEN RAISE; END IF; END;
  UPDATE public.orders SET offered_driver_id = v_driver,
    offer_expires_at = clock_timestamp() + interval '45 seconds' WHERE id = v_first;
  PERFORM public.reject_order(v_first, v_driver::text);
  IF (public.get_driver_acceptance_state()->>'transfer_count')::integer <> 3
    THEN RAISE EXCEPTION 'Same order counted twice'; END IF;

  -- Window is rolling. Receiving an assigned order does not reset the quota.
  v_active := pg_temp.transfer_offer(v_customer, NULL);
  UPDATE public.orders SET driver_id = v_driver, status = 'assigned' WHERE id = v_active;
  IF (public.get_driver_acceptance_state()->>'transfer_count')::integer <> 3
    THEN RAISE EXCEPTION 'Receiving an order reset transfers'; END IF;
  UPDATE public.order_status_logs SET created_at = clock_timestamp() - interval '30 minutes 1 second'
  WHERE order_id = v_first AND title = 'Tài xế từ chối lời mời';
  v_state := public.get_driver_acceptance_state();
  IF (v_state->>'transfer_count')::integer <> 2 OR v_state->>'transfer_next_expiry_at' IS NULL
    THEN RAISE EXCEPTION 'Old event did not expire from the window'; END IF;
  v_order := pg_temp.transfer_offer(v_customer, v_driver);
  PERFORM public.reject_order(v_order, v_driver::text);
  IF (public.get_driver_acceptance_state()->>'transfer_count')::integer <> 3
    THEN RAISE EXCEPTION 'Count included expired event'; END IF;

  v_order := pg_temp.transfer_offer(v_customer, v_driver);
  v_fourth := v_order;
  v_before := clock_timestamp();
  PERFORM public.reject_order(v_order, v_driver::text);
  SELECT acceptance_locked_until INTO v_lock FROM public.drivers WHERE user_id = v_driver;
  IF v_lock IS NULL OR v_lock < v_before + interval '30 minutes'
    OR v_lock > clock_timestamp() + interval '30 minutes'
    THEN RAISE EXCEPTION 'Incorrect 30-minute cooldown'; END IF;
  v_state := public.get_driver_acceptance_state();
  IF v_state->>'lock_reason' IS DISTINCT FROM 'offer_transfers'
    OR (v_state->>'locked_until')::timestamptz IS DISTINCT FROM v_lock
    OR (v_state->>'transfer_count')::integer <> 0
    THEN RAISE EXCEPTION 'Snapshot did not expose and consume the cooldown'; END IF;
  IF (SELECT count(*) FROM public.order_status_logs WHERE logged_by = v_driver
      AND title = 'Đã tính đơn vào khóa chuyển đơn') <> 4
    THEN RAISE EXCEPTION 'Did not consume exactly four distinct orders'; END IF;
  IF (SELECT is_available FROM public.drivers WHERE user_id = v_driver) IS DISTINCT FROM v_intent
    THEN RAISE EXCEPTION 'Changed online intent'; END IF;
  IF (SELECT status FROM public.orders WHERE id = v_active) <> 'assigned'
    THEN RAISE EXCEPTION 'Interrupted an already-assigned order'; END IF;

  -- Duplicate RPC and a different existing lock cannot extend/shorten cooldown.
  BEGIN
    PERFORM public.reject_order(v_fourth, v_driver::text);
    RAISE EXCEPTION 'Replay was allowed while locked';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'ORDER_NOT_OFFERED_TO_DRIVER' THEN RAISE; END IF; END;
  IF (SELECT acceptance_locked_until FROM public.drivers WHERE user_id = v_driver) IS DISTINCT FROM v_lock
    THEN RAISE EXCEPTION 'Replay changed cooldown'; END IF;
  v_order := pg_temp.transfer_offer(v_customer, v_driver);
  BEGIN
    PERFORM public.accept_order(v_order);
    RAISE EXCEPTION 'Normal accept bypassed cooldown';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'DRIVER_ACCEPTANCE_LOCKED' THEN RAISE; END IF; END;
  BEGIN
    PERFORM public.claim_free_pick_order(v_order);
    RAISE EXCEPTION 'FreePick bypassed cooldown';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'DRIVER_ACCEPTANCE_LOCKED' THEN RAISE; END IF; END;
  v_lock := clock_timestamp() + interval '1 hour';
  UPDATE public.drivers SET acceptance_locked_until = v_lock WHERE user_id = v_driver;
  BEGIN
    PERFORM public.reject_order(v_order, v_driver::text);
    RAISE EXCEPTION 'Transfer ignored another cooldown';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'DRIVER_ACCEPTANCE_LOCKED' THEN RAISE; END IF; END;
  IF (SELECT acceptance_locked_until FROM public.drivers WHERE user_id = v_driver) IS DISTINCT FROM v_lock
    THEN RAISE EXCEPTION 'Changed another cooldown'; END IF;

  -- Expiry starts a new quota; consumed orders cannot be used again.
  UPDATE public.orders SET offered_driver_id = NULL, offer_expires_at = NULL WHERE id = v_order;
  UPDATE public.drivers SET acceptance_locked_until = clock_timestamp() - interval '1 second'
  WHERE user_id = v_driver;
  FOR i IN 1..3 LOOP
    v_order := pg_temp.transfer_offer(v_customer, v_driver);
    PERFORM public.reject_order(v_order, v_driver::text);
    IF (public.get_driver_acceptance_state()->>'transfer_count')::integer <> i
      OR (SELECT acceptance_locked_until > clock_timestamp() FROM public.drivers WHERE user_id = v_driver)
      THEN RAISE EXCEPTION 'Reused previously consumed transfers'; END IF;
  END LOOP;
  v_order := pg_temp.transfer_offer(v_customer, v_driver);
  PERFORM public.reject_order(v_order, v_driver::text);
  IF (SELECT count(*) FROM public.order_status_logs WHERE logged_by = v_driver
      AND title = 'Đã tính đơn vào khóa chuyển đơn') <> 8
    THEN RAISE EXCEPTION 'Second cooldown consumption failed'; END IF;
  IF (SELECT count(*) FROM public.notifications WHERE user_id = v_driver
      AND title = 'Tạm khóa nhận đơn 30 phút' AND created_at >= v_before) <> 2
    THEN RAISE EXCEPTION 'Missing or duplicated cooldown notification'; END IF;
  IF has_function_privilege('authenticated', 'private.driver_transfer_window(uuid,timestamp with time zone)', 'execute')
    THEN RAISE EXCEPTION 'Client can call private helper'; END IF;
  PERFORM set_config('test.transfer_order', v_order::text, true);
END;
$$;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object(
  'sub',current_setting('test.transfer_driver'),'role','authenticated')::text, true);
DO $$
BEGIN
  BEGIN
    INSERT INTO public.order_status_logs(order_id,status,title,logged_by)
    VALUES(current_setting('test.transfer_order')::uuid,'confirmed',
      'Đã tính đơn vào khóa chuyển đơn',current_setting('test.transfer_driver')::uuid);
    RAISE EXCEPTION 'Client forged consumed marker';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'DELIVERY_POLICY_AUDIT_SERVER_OWNED' THEN RAISE; END IF;
  END;
  BEGIN
    INSERT INTO public.order_status_logs(order_id,status,title,logged_by)
    VALUES(current_setting('test.transfer_order')::uuid,'confirmed',
      'Tài xế từ chối lời mời',current_setting('test.transfer_driver')::uuid);
    RAISE EXCEPTION 'Client forged transfer event';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'DELIVERY_POLICY_AUDIT_SERVER_OWNED' THEN RAISE; END IF;
  END;
END;
$$;
RESET ROLE;
ROLLBACK;
