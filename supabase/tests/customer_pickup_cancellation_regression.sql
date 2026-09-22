-- Regression checks against an existing unconfirmed picking_up order with a
-- saved pickup photo. Every scenario rolls back its own changes, including
-- wallet transactions and status logs. No order is actually cancelled.
DO $test$
DECLARE
  sample public.orders%ROWTYPE;
  confirmed_at timestamptz;
  repeated_at timestamptz;
  result_status text;
  other_driver_id uuid;
  initial_log_count bigint;
BEGIN
  SELECT o.* INTO STRICT sample FROM public.orders o
  JOIN public.order_delivery_proofs proof
    ON proof.order_id = o.id AND proof.driver_id = o.driver_id
    AND proof.stage = 'pickup'
  WHERE o.status = 'picking_up' AND o.actual_picked_up_at IS NULL
    AND proof.captured_lat IS NOT NULL AND proof.captured_lng IS NOT NULL
    AND public.ST_DWithin(
      public.ST_SetSRID(public.ST_MakePoint(proof.captured_lng, proof.captured_lat), 4326)::public.geography,
      public.ST_SetSRID(public.ST_MakePoint(o.pickup_lng, o.pickup_lat), 4326)::public.geography, 100
    )
  ORDER BY o.updated_at DESC LIMIT 1 FOR UPDATE OF o;

  -- 1. A photo alone leaves cancellation available; cancellation wins the race.
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', sample.customer_id::text, true);
    SELECT new_status INTO result_status FROM public.cancel_customer_order(
      sample.id, sample.customer_id, 'Regression: photo without committed handoff'
    );
    IF result_status IS DISTINCT FROM 'cancelled' THEN
      RAISE EXCEPTION 'Photo-only cancellation did not succeed';
    END IF;
    PERFORM set_config('request.jwt.claim.sub', sample.driver_id::text, true);
    BEGIN
      PERFORM public.confirm_driver_pickup(sample.id);
      RAISE EXCEPTION 'A cancelled order accepted pickup confirmation';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'ORDER_NOT_PICKING_UP' THEN RAISE; END IF;
    END;
    RAISE EXCEPTION 'ROLLBACK_SCENARIO' USING ERRCODE = 'PZ001';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL;
  END;

  -- 2. A committed handoff locks both RPC and direct cancellation; retry is idempotent.
  BEGIN
    SELECT count(*) INTO initial_log_count FROM public.order_status_logs WHERE order_id = sample.id;
    PERFORM set_config('request.jwt.claim.sub', sample.driver_id::text, true);
    confirmed_at := public.confirm_driver_pickup(sample.id);
    repeated_at := public.confirm_driver_pickup(sample.id);
    IF confirmed_at IS NULL OR confirmed_at IS DISTINCT FROM repeated_at THEN
      RAISE EXCEPTION 'Pickup confirmation is not idempotent';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.orders WHERE id = sample.id
        AND status = 'picking_up' AND actual_picked_up_at = confirmed_at
    ) THEN RAISE EXCEPTION 'Pickup confirmation did not commit its timestamp'; END IF;
    IF (SELECT count(*) FROM public.order_status_logs WHERE order_id = sample.id) <> initial_log_count + 1 THEN
      RAISE EXCEPTION 'Pickup confirmation retry duplicated its status log';
    END IF;
    PERFORM set_config('request.jwt.claim.sub', sample.customer_id::text, true);
    BEGIN
      PERFORM public.cancel_customer_order(sample.id, sample.customer_id);
      RAISE EXCEPTION 'Confirmed handoff accepted customer cancellation';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'ORDER_ALREADY_PICKED_UP' THEN RAISE; END IF;
    END;
    BEGIN
      UPDATE public.orders SET status = 'cancelled' WHERE id = sample.id;
      RAISE EXCEPTION 'Confirmed handoff accepted direct cancellation';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'ORDER_ALREADY_PICKED_UP' THEN RAISE; END IF;
    END;
    RAISE EXCEPTION 'ROLLBACK_SCENARIO' USING ERRCODE = 'PZ001';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL;
  END;

  -- 3. A failed geofence check leaves cancellation available.
  BEGIN
    UPDATE public.order_delivery_proofs SET captured_lat = 0, captured_lng = 0
    WHERE order_id = sample.id AND stage = 'pickup';
    PERFORM set_config('request.jwt.claim.sub', sample.driver_id::text, true);
    BEGIN
      PERFORM public.confirm_driver_pickup(sample.id);
      RAISE EXCEPTION 'Pickup accepted a photo outside the geofence';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'PICKUP_OUTSIDE_GEOFENCE' THEN RAISE; END IF;
    END;
    PERFORM set_config('request.jwt.claim.sub', sample.customer_id::text, true);
    SELECT new_status INTO result_status FROM public.cancel_customer_order(sample.id, sample.customer_id);
    IF result_status IS DISTINCT FROM 'cancelled' THEN RAISE EXCEPTION 'Failed handoff locked cancellation'; END IF;
    RAISE EXCEPTION 'ROLLBACK_SCENARIO' USING ERRCODE = 'PZ001';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL;
  END;

  -- 4. Missing proof never commits a handoff.
  BEGIN
    DELETE FROM public.order_delivery_proofs WHERE order_id = sample.id AND stage = 'pickup';
    PERFORM set_config('request.jwt.claim.sub', sample.driver_id::text, true);
    BEGIN
      PERFORM public.confirm_driver_pickup(sample.id);
      RAISE EXCEPTION 'Pickup confirmation accepted missing proof';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'PICKUP_PROOF_LOCATION_REQUIRED' THEN RAISE; END IF;
    END;
    PERFORM set_config('request.jwt.claim.sub', sample.customer_id::text, true);
    SELECT new_status INTO result_status FROM public.cancel_customer_order(sample.id, sample.customer_id);
    IF result_status IS DISTINCT FROM 'cancelled' THEN RAISE EXCEPTION 'Missing proof locked cancellation'; END IF;
    RAISE EXCEPTION 'ROLLBACK_SCENARIO' USING ERRCODE = 'PZ001';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL;
  END;

  -- 5. Customer/anonymous callers cannot manufacture a pickup confirmation.
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', sample.customer_id::text, true);
    BEGIN
      PERFORM public.confirm_driver_pickup(sample.id);
      RAISE EXCEPTION 'Customer confirmed driver pickup';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'DRIVER_ROLE_REQUIRED' THEN RAISE; END IF;
    END;
    BEGIN
      UPDATE public.orders SET actual_picked_up_at = clock_timestamp() WHERE id = sample.id;
      RAISE EXCEPTION 'Customer manufactured pickup timestamp';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'PICKUP_CONFIRMATION_DRIVER_REQUIRED' THEN RAISE; END IF;
    END;
    PERFORM set_config('request.jwt.claim.sub', '', true);
    BEGIN
      PERFORM public.confirm_driver_pickup(sample.id);
      RAISE EXCEPTION 'Anonymous caller confirmed pickup';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'AUTH_REQUIRED' THEN RAISE; END IF;
    END;
    RAISE EXCEPTION 'ROLLBACK_SCENARIO' USING ERRCODE = 'PZ001';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL;
  END;

  -- 6. Proof left by a different driver does not lock this assignment.
  SELECT id INTO STRICT other_driver_id FROM public.users
  WHERE role = 'driver' AND id <> sample.driver_id LIMIT 1;
  BEGIN
    UPDATE public.order_delivery_proofs SET driver_id = other_driver_id
    WHERE order_id = sample.id AND stage = 'pickup';
    PERFORM set_config('request.jwt.claim.sub', sample.driver_id::text, true);
    BEGIN
      PERFORM public.confirm_driver_pickup(sample.id);
      RAISE EXCEPTION 'Pickup accepted another driver''s proof';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'PICKUP_PROOF_LOCATION_REQUIRED' THEN RAISE; END IF;
    END;
    PERFORM set_config('request.jwt.claim.sub', other_driver_id::text, true);
    BEGIN
      PERFORM public.confirm_driver_pickup(sample.id);
      RAISE EXCEPTION 'Unassigned driver confirmed pickup';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'DRIVER_NOT_ASSIGNED' THEN RAISE; END IF;
    END;
    PERFORM set_config('request.jwt.claim.sub', sample.customer_id::text, true);
    SELECT new_status INTO result_status FROM public.cancel_customer_order(sample.id, sample.customer_id);
    IF result_status IS DISTINCT FROM 'cancelled' THEN RAISE EXCEPTION 'Previous driver proof locked cancellation'; END IF;
    RAISE EXCEPTION 'ROLLBACK_SCENARIO' USING ERRCODE = 'PZ001';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL;
  END;

  -- All scenarios rolled back: assert the original order is untouched.
  IF (SELECT to_jsonb(o) FROM public.orders o WHERE o.id = sample.id) IS DISTINCT FROM to_jsonb(sample) THEN
    RAISE EXCEPTION 'Regression tests left a persistent order change';
  END IF;
END;
$test$;

