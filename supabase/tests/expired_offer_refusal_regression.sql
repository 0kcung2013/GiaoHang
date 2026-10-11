-- Run after expired_offer_refusal_acceptance_lock. Fixtures and all driver
-- locks/audit/notifications are rolled back. No external dispatch is requested.
BEGIN;
SET LOCAL lock_timeout = '5s';
SELECT set_config('giaohang.road_dispatch_requested', 'yes', true);
SELECT set_config('request.jwt.claims', '{}', true);

CREATE FUNCTION pg_temp.expiry_offer(p_customer uuid, p_driver uuid)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid := gen_random_uuid();
BEGIN
  INSERT INTO public.orders(
    id, customer_id, status, pickup_address, pickup_lat, pickup_lng,
    delivery_address, delivery_lat, delivery_lng, tracking_code,
    offered_driver_id, offer_expires_at, assignment_expires_at
  ) VALUES (
    v_id, p_customer, 'confirmed', 'Expired offer regression pickup', 10.78, 106.7,
    'Expired offer regression delivery', 10.79, 106.71, 'TEST-EXPIRY-' || v_id::text,
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
  v_other_driver uuid;
  v_customer uuid;
  v_intent boolean;
  v_order uuid;
  v_first uuid;
  v_fourth uuid;
  v_active uuid;
  v_occurrence timestamptz;
  v_before timestamptz;
  v_lock timestamptz;
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
  SELECT d.user_id INTO STRICT v_other_driver FROM public.drivers d
  WHERE d.user_id <> v_driver
    AND (d.acceptance_locked_until IS NULL OR d.acceptance_locked_until <= clock_timestamp())
    AND NOT EXISTS (SELECT 1 FROM public.orders o WHERE o.offered_driver_id = d.user_id
      AND o.driver_id IS NULL AND o.status IN ('pending','confirmed'))
    AND NOT EXISTS (SELECT 1 FROM public.orders o WHERE o.driver_id = d.user_id
      AND o.status IN ('return_approved','returning'))
  ORDER BY d.user_id LIMIT 1;
  SELECT id INTO STRICT v_customer FROM public.users WHERE role = 'customer' LIMIT 1;
  PERFORM set_config('request.jwt.claims',
    jsonb_build_object('sub',v_driver,'role','authenticated')::text, true);

  -- Early acceptance/cancellation and absent invitation metadata are not refusals.
  v_order := pg_temp.expiry_offer(v_customer, v_driver);
  UPDATE public.orders SET offered_driver_id = NULL, offer_expires_at = NULL WHERE id = v_order;
  v_order := pg_temp.expiry_offer(v_customer, v_driver);
  UPDATE public.orders SET status = 'cancelled' WHERE id = v_order;
  v_order := pg_temp.expiry_offer(v_customer, NULL);
  UPDATE public.orders SET assignment_expires_at = clock_timestamp() - interval '1 second'
  WHERE id = v_order;
  PERFORM private.dispatch_next_order_offer(v_order, 2000);
  IF (public.get_driver_acceptance_state()->>'transfer_count')::integer <> 0
    THEN RAISE EXCEPTION 'An unexpired/missing invitation was charged'; END IF;

  -- A scheduler processing an old backlog uses the invitation's deadline,
  -- rather than inventing a recent event/lock when the driver last ignored it.
  v_order := pg_temp.expiry_offer(v_customer, v_driver);
  v_occurrence := clock_timestamp() - interval '31 minutes';
  UPDATE public.orders SET offer_expires_at = v_occurrence WHERE id = v_order;
  PERFORM private.dispatch_next_order_offer(v_order, 2000);
  IF (public.get_driver_acceptance_state()->>'transfer_count')::integer <> 0
    OR NOT EXISTS (SELECT 1 FROM public.order_status_logs
      WHERE order_id = v_order AND logged_by = v_driver
        AND title = 'Tài xế từ chối lời mời' AND created_at = v_occurrence)
    THEN RAISE EXCEPTION 'Expiry occurrence time was lost'; END IF;

  -- First refusal: expire without auth/client action; redispatch invokes the
  -- same path as the existing five-second server scheduler.
  v_order := pg_temp.expiry_offer(v_customer, v_driver);
  v_first := v_order;
  v_occurrence := clock_timestamp() - interval '1 second';
  UPDATE public.orders SET offer_expires_at = v_occurrence WHERE id = v_order;
  PERFORM set_config('request.jwt.claims', '{}', true);
  PERFORM private.dispatch_next_order_offer(v_order, 2000);
  PERFORM private.dispatch_next_order_offer(v_order, 2000);
  PERFORM set_config('request.jwt.claims',
    jsonb_build_object('sub',v_driver,'role','authenticated')::text, true);
  IF (public.get_driver_acceptance_state()->>'transfer_count')::integer <> 1
    OR (SELECT count(*) FROM public.order_status_logs WHERE order_id = v_order
      AND logged_by = v_driver AND title = 'Tài xế từ chối lời mời') <> 1
    OR NOT ((SELECT rejected_by FROM public.orders WHERE id = v_order) ? v_driver::text)
    THEN RAISE EXCEPTION 'Server expiry was not counted exactly once'; END IF;

  -- Replaying/re-offering that same order and later clearing it is harmless.
  UPDATE public.orders SET offered_driver_id = v_driver,
    offer_expires_at = clock_timestamp() + interval '45 seconds' WHERE id = v_first;
  UPDATE public.orders SET offer_expires_at = clock_timestamp() - interval '1 second'
  WHERE id = v_first;
  PERFORM public.reject_order(v_first, v_driver::text);
  IF (public.get_driver_acceptance_state()->>'transfer_count')::integer <> 1
    OR (SELECT count(*) FROM public.order_status_logs WHERE order_id = v_first
      AND logged_by = v_driver AND title = 'Tài xế từ chối lời mời') <> 1
    THEN RAISE EXCEPTION 'Late RPC/redispatch charged the same order twice'; END IF;

  -- Second refusal is manual, in the same rolling window.
  v_order := pg_temp.expiry_offer(v_customer, v_driver);
  PERFORM public.reject_order(v_order, v_driver::text);
  IF (public.get_driver_acceptance_state()->>'transfer_count')::integer <> 2
    THEN RAISE EXCEPTION 'Manual and expired invitations use different quotas'; END IF;

  -- Third refusal: a new driver claims an expired invitation before cron.
  -- Updating these two offer columns exercises FreePick's existing overwrite.
  v_order := pg_temp.expiry_offer(v_customer, v_driver);
  UPDATE public.orders SET offer_expires_at = clock_timestamp() - interval '1 second'
  WHERE id = v_order;
  UPDATE public.orders SET offered_driver_id = v_other_driver,
    offer_expires_at = clock_timestamp() + interval '45 seconds' WHERE id = v_order;
  IF (public.get_driver_acceptance_state()->>'transfer_count')::integer <> 3
    OR EXISTS (SELECT 1 FROM public.order_status_logs WHERE order_id = v_order
      AND logged_by = v_other_driver AND title = 'Tài xế từ chối lời mời')
    THEN RAISE EXCEPTION 'Replacing expiry charged the wrong driver or skipped it'; END IF;
  UPDATE public.orders SET offered_driver_id = NULL, offer_expires_at = NULL WHERE id = v_order;

  -- Already accepted/current deliveries, online intent and payment stay intact.
  v_active := pg_temp.expiry_offer(v_customer, v_driver);
  UPDATE public.orders SET driver_id = v_driver, status = 'assigned' WHERE id = v_active;
  IF (public.get_driver_acceptance_state()->>'transfer_count')::integer <> 3
    THEN RAISE EXCEPTION 'Accepting an unexpired invitation reset/charged quota'; END IF;

  -- Fourth refusal: the final 45s offer coincides with the 15-minute search
  -- deadline. It must count before the timeout trigger clears its driver.
  v_order := pg_temp.expiry_offer(v_customer, v_driver);
  v_fourth := v_order;
  v_occurrence := clock_timestamp() - interval '1 second';
  UPDATE public.orders SET offer_expires_at = v_occurrence,
    assignment_expires_at = v_occurrence WHERE id = v_order;
  v_before := clock_timestamp();
  PERFORM private.dispatch_next_order_offer(v_order, 2000);
  SELECT acceptance_locked_until INTO v_lock FROM public.drivers WHERE user_id = v_driver;
  v_state := public.get_driver_acceptance_state();
  IF v_lock IS NULL OR v_lock < v_before + interval '30 minutes'
    OR v_lock > clock_timestamp() + interval '30 minutes'
    OR v_state->>'lock_reason' IS DISTINCT FROM 'offer_transfers'
    OR (v_state->>'transfer_count')::integer <> 0
    OR (SELECT count(*) FROM public.order_status_logs WHERE logged_by = v_driver
      AND title = 'Đã tính đơn vào khóa chuyển đơn' AND created_at >= v_before) <> 4
    THEN RAISE EXCEPTION 'Four mixed refusals did not consume exactly four orders and lock'; END IF;
  IF (SELECT assignment_timed_out_at FROM public.orders WHERE id = v_order) IS NULL
    OR (SELECT offered_driver_id FROM public.orders WHERE id = v_order) IS NOT NULL
    OR (SELECT status FROM public.orders WHERE id = v_active) <> 'assigned'
    OR (SELECT payment_status FROM public.orders WHERE id = v_active) <> 'not_required'
    OR (SELECT is_available FROM public.drivers WHERE user_id = v_driver) IS DISTINCT FROM v_intent
    THEN RAISE EXCEPTION 'Expiry changed assignment, delivery, payment or online behavior'; END IF;
  PERFORM private.dispatch_next_order_offer(v_fourth, 2000);
  PERFORM public.reject_order(v_fourth, v_driver::text);
  IF (SELECT acceptance_locked_until FROM public.drivers WHERE user_id = v_driver) IS DISTINCT FROM v_lock
    OR (SELECT count(*) FROM public.notifications WHERE user_id = v_driver
      AND title = 'Tạm khóa nhận đơn 30 phút' AND created_at >= v_before) <> 1
    THEN RAISE EXCEPTION 'Retry extended lock or duplicated its notification'; END IF;

  -- Acceptance entry points continue to reject while locked, despite cron expiry.
  v_order := pg_temp.expiry_offer(v_customer, NULL);
  BEGIN
    PERFORM public.accept_order(v_order);
    RAISE EXCEPTION 'Normal acceptance bypassed expiry cooldown';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'DRIVER_ACCEPTANCE_LOCKED' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.claim_free_pick_order(v_order);
    RAISE EXCEPTION 'FreePick bypassed expiry cooldown';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'DRIVER_ACCEPTANCE_LOCKED' THEN RAISE; END IF;
  END;

  -- Previously consumed orders cannot start a second lock after unlocking.
  UPDATE public.drivers SET acceptance_locked_until = clock_timestamp() - interval '1 second'
  WHERE user_id = v_driver;
  UPDATE public.orders SET offered_driver_id = v_driver,
    offer_expires_at = clock_timestamp() + interval '45 seconds' WHERE id = v_first;
  UPDATE public.orders SET offer_expires_at = clock_timestamp() - interval '1 second'
  WHERE id = v_first;
  PERFORM private.dispatch_next_order_offer(v_first, 2000);
  IF (public.get_driver_acceptance_state()->>'transfer_count')::integer <> 0
    THEN RAISE EXCEPTION 'Consumed expiry was reused after unlocking'; END IF;

  -- An expiry is audited during another existing lock, without changing it.
  v_order := pg_temp.expiry_offer(v_customer, v_driver);
  UPDATE public.orders SET offer_expires_at = clock_timestamp() - interval '1 second'
  WHERE id = v_order;
  v_lock := clock_timestamp() + interval '1 hour';
  UPDATE public.drivers SET acceptance_locked_until = v_lock WHERE user_id = v_driver;
  PERFORM private.dispatch_next_order_offer(v_order, 2000);
  IF (SELECT acceptance_locked_until FROM public.drivers WHERE user_id = v_driver) IS DISTINCT FROM v_lock
    OR (public.get_driver_acceptance_state()->>'transfer_count')::integer <> 1
    THEN RAISE EXCEPTION 'Expiry altered an existing lock or lost its audit'; END IF;
  IF has_function_privilege('authenticated',
      'private.record_driver_offer_refusal(uuid,uuid,public.order_status,timestamp with time zone,boolean)', 'execute')
    OR has_function_privilege('anon',
      'private.record_driver_offer_refusal(uuid,uuid,public.order_status,timestamp with time zone,boolean)', 'execute')
    THEN RAISE EXCEPTION 'Client can forge an expiry/refusal through the helper'; END IF;
END;
$$;
ROLLBACK;
