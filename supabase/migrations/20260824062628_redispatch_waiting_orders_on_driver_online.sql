-- Going online is one server command: publish a fresh position, mark the
-- driver available, then wake a bounded slice of the persisted order queue.

CREATE INDEX IF NOT EXISTS orders_waiting_dispatch_created_idx
  ON public.orders (created_at, id)
  WHERE driver_id IS NULL
    AND assignment_timed_out_at IS NULL
    AND status IN (
      'pending'::public.order_status,
      'confirmed'::public.order_status
    );

CREATE OR REPLACE FUNCTION private.dispatch_waiting_orders_for_driver(
  p_driver_user_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_driver public.drivers%ROWTYPE;
  v_available_balance bigint;
  v_waiting_order record;
  v_offered_driver_id uuid;
  v_existing_offer_id uuid;
BEGIN
  IF p_driver_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT driver_profile.*
  INTO v_driver
  FROM public.drivers AS driver_profile
  WHERE driver_profile.user_id = p_driver_user_id;

  IF NOT FOUND
     OR v_driver.is_available IS DISTINCT FROM true
     OR v_driver.approval_status IS DISTINCT FROM
        'approved'::public.approval_status
     OR v_driver.current_lat IS NULL
     OR v_driver.current_lng IS NULL
     OR v_driver.location_updated_at <
        clock_timestamp() - interval '3 minutes' THEN
    RETURN NULL;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.orders AS active_order
    WHERE active_order.driver_id = p_driver_user_id
      AND active_order.status IN (
        'assigned'::public.order_status,
        'picking_up'::public.order_status,
        'delivering'::public.order_status
      )
  ) THEN
    RETURN NULL;
  END IF;

  SELECT active_offer.id
  INTO v_existing_offer_id
  FROM public.orders AS active_offer
  WHERE active_offer.offered_driver_id = p_driver_user_id
    AND active_offer.driver_id IS NULL
    AND active_offer.assignment_timed_out_at IS NULL
    AND active_offer.status IN (
      'pending'::public.order_status,
      'confirmed'::public.order_status
    )
    AND active_offer.offer_expires_at > clock_timestamp()
  ORDER BY active_offer.created_at ASC, active_offer.id ASC
  LIMIT 1;

  IF v_existing_offer_id IS NOT NULL THEN
    RETURN v_existing_offer_id;
  END IF;

  SELECT COALESCE(sum(wallet_tx.available_delta), 0)
  INTO v_available_balance
  FROM public.driver_wallet_transactions AS wallet_tx
  WHERE wallet_tx.driver_id = p_driver_user_id
    AND wallet_tx.status = 'completed';

  FOR v_waiting_order IN
    SELECT waiting_order.id
    FROM public.orders AS waiting_order
    WHERE waiting_order.driver_id IS NULL
      AND waiting_order.status IN (
        'pending'::public.order_status,
        'confirmed'::public.order_status
      )
      AND waiting_order.assignment_timed_out_at IS NULL
      AND waiting_order.assignment_expires_at > clock_timestamp()
      AND (
        waiting_order.offered_driver_id IS NULL
        OR waiting_order.offer_expires_at <= clock_timestamp()
      )
      AND COALESCE(waiting_order.note, '') <>
        'FREEPICK_DEMO_PERSISTENT'
      AND NOT (
        COALESCE(waiting_order.rejected_by, '[]'::jsonb)
        ? p_driver_user_id::text
      )
      AND v_available_balance >= waiting_order.driver_advance_amount
      AND public.ST_DWithin(
        public.ST_SetSRID(
          public.ST_MakePoint(v_driver.current_lng, v_driver.current_lat),
          4326
        )::public.geography,
        public.ST_SetSRID(
          public.ST_MakePoint(
            waiting_order.pickup_lng,
            waiting_order.pickup_lat
          ),
          4326
        )::public.geography,
        2000
      )
    ORDER BY waiting_order.created_at ASC, waiting_order.id ASC
    LIMIT 20
  LOOP
    v_offered_driver_id := private.dispatch_next_order_offer(
      v_waiting_order.id,
      2000
    );

    IF v_offered_driver_id = p_driver_user_id THEN
      RETURN v_waiting_order.id;
    END IF;

    SELECT active_offer.id
    INTO v_existing_offer_id
    FROM public.orders AS active_offer
    WHERE active_offer.offered_driver_id = p_driver_user_id
      AND active_offer.driver_id IS NULL
      AND active_offer.assignment_timed_out_at IS NULL
      AND active_offer.status IN (
        'pending'::public.order_status,
        'confirmed'::public.order_status
      )
      AND active_offer.offer_expires_at > clock_timestamp()
    ORDER BY active_offer.created_at ASC, active_offer.id ASC
    LIMIT 1;

    IF v_existing_offer_id IS NOT NULL THEN
      RETURN v_existing_offer_id;
    END IF;
  END LOOP;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_driver_online_with_location(
  p_lat double precision,
  p_lng double precision
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
  v_now timestamptz := clock_timestamp();
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF p_lat IS NULL OR p_lat < -90 OR p_lat > 90 THEN
    RAISE EXCEPTION 'INVALID_DRIVER_LATITUDE';
  END IF;
  IF p_lng IS NULL OR p_lng < -180 OR p_lng > 180 THEN
    RAISE EXCEPTION 'INVALID_DRIVER_LONGITUDE';
  END IF;

  UPDATE public.drivers AS driver_profile
  SET
    current_lat = p_lat,
    current_lng = p_lng,
    location_updated_at = v_now,
    is_available = true,
    updated_at = v_now
  WHERE driver_profile.user_id = v_driver_user_id
    AND driver_profile.approval_status =
      'approved'::public.approval_status;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPROVED_DRIVER_REQUIRED';
  END IF;

  RETURN private.dispatch_waiting_orders_for_driver(v_driver_user_id);
END;
$$;

REVOKE ALL ON FUNCTION private.dispatch_waiting_orders_for_driver(uuid)
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.set_driver_online_with_location(
  double precision,
  double precision
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.set_driver_online_with_location(
  double precision,
  double precision
) TO authenticated;

COMMENT ON FUNCTION public.set_driver_online_with_location(
  double precision,
  double precision
) IS
  'Atomically publishes fresh GPS, marks an approved driver online, and wakes persisted waiting orders.';
