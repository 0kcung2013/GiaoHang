-- An uploaded photo is not a committed pickup confirmation. Do not backfill
-- actual_picked_up_at from photos: stale or failed uploads caused this bug.
-- Existing delivering/delivered orders retain their status-based protection.

CREATE OR REPLACE FUNCTION private.enforce_driver_handoff_geofence()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  proof public.order_delivery_proofs%ROWTYPE;
  handoff_stage text;
  target_lat double precision;
  target_lng double precision;
BEGIN
  -- A new assignment must not inherit the previous driver's handoff.
  IF NEW.driver_id IS DISTINCT FROM OLD.driver_id
     OR (NEW.status IN ('pending', 'confirmed', 'assigned')
         AND NEW.status IS DISTINCT FROM OLD.status) THEN
    NEW.actual_picked_up_at := NULL;
    RETURN NEW;
  END IF;

  IF OLD.status = 'picking_up'::public.order_status
     AND NEW.status = 'delivering'::public.order_status THEN
    -- Preserve the actual handoff time when the driver starts moving later.
    NEW.actual_picked_up_at := COALESCE(
      OLD.actual_picked_up_at, NEW.actual_picked_up_at
    );
  END IF;

  IF OLD.status IS NOT DISTINCT FROM NEW.status
     AND OLD.actual_picked_up_at IS NOT DISTINCT FROM NEW.actual_picked_up_at THEN
    RETURN NEW;
  END IF;

  -- Staff/system recovery workflows are handled by their own authorization
  -- rules. This guard targets status changes initiated by the assigned driver.
  IF OLD.driver_id IS NULL OR auth.uid() IS DISTINCT FROM OLD.driver_id THEN
    IF OLD.actual_picked_up_at IS DISTINCT FROM NEW.actual_picked_up_at
       AND auth.uid() IS NOT NULL
       AND NOT EXISTS (
         SELECT 1 FROM public.users actor
         WHERE actor.id = auth.uid() AND actor.role IN ('support', 'admin')
       ) THEN
      RAISE EXCEPTION 'PICKUP_CONFIRMATION_DRIVER_REQUIRED';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status = 'picking_up'::public.order_status
     AND (
       NEW.status = 'delivering'::public.order_status
       OR (NEW.status = 'picking_up'::public.order_status
           AND OLD.actual_picked_up_at IS NULL
           AND NEW.actual_picked_up_at IS NOT NULL)
     ) THEN
    handoff_stage := 'pickup';
    target_lat := OLD.pickup_lat;
    target_lng := OLD.pickup_lng;
  ELSIF OLD.status = 'delivering'::public.order_status
        AND NEW.status = 'delivered'::public.order_status THEN
    handoff_stage := 'delivery';
    target_lat := OLD.delivery_lat;
    target_lng := OLD.delivery_lng;
  ELSE
    IF OLD.actual_picked_up_at IS DISTINCT FROM NEW.actual_picked_up_at THEN
      RAISE EXCEPTION 'INVALID_PICKUP_CONFIRMATION_TRANSITION';
    END IF;
    RETURN NEW;
  END IF;

  SELECT handoff_proof.*
  INTO proof
  FROM public.order_delivery_proofs AS handoff_proof
  WHERE handoff_proof.order_id = OLD.id
    AND handoff_proof.driver_id = OLD.driver_id
    AND handoff_proof.stage = handoff_stage
  FOR UPDATE;

  IF NOT FOUND OR proof.captured_lat IS NULL
     OR proof.captured_lng IS NULL THEN
    IF handoff_stage = 'pickup' THEN
      RAISE EXCEPTION 'PICKUP_PROOF_LOCATION_REQUIRED'
        USING ERRCODE = '23514';
    END IF;
    RAISE EXCEPTION 'DELIVERY_PROOF_LOCATION_REQUIRED'
      USING ERRCODE = '23514';
  END IF;

  IF NOT public.ST_DWithin(
    public.ST_SetSRID(
      public.ST_MakePoint(proof.captured_lng, proof.captured_lat),
      4326
    )::public.geography,
    public.ST_SetSRID(
      public.ST_MakePoint(target_lng, target_lat),
      4326
    )::public.geography,
    100
  ) THEN
    IF handoff_stage = 'pickup' THEN
      RAISE EXCEPTION 'PICKUP_OUTSIDE_GEOFENCE'
        USING ERRCODE = '23514';
    END IF;
    RAISE EXCEPTION 'DELIVERY_OUTSIDE_GEOFENCE'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS enforce_driver_handoff_geofence_before_status_update ON public.orders;
CREATE TRIGGER enforce_driver_handoff_geofence_before_status_update
BEFORE UPDATE OF status, driver_id, actual_picked_up_at ON public.orders
FOR EACH ROW EXECUTE FUNCTION private.enforce_driver_handoff_geofence();

-- Commit the handoff only after the uploaded proof has passed the same
-- geofence validation as starting delivery. Row locking serializes this
-- command with cancellation; the losing command sees the committed state.
CREATE OR REPLACE FUNCTION public.confirm_driver_pickup(p_order_id uuid)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_driver_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_confirmed_at timestamptz;
BEGIN
  IF v_driver_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users actor
    WHERE actor.id = v_driver_id AND actor.role = 'driver'::public.user_role
  ) THEN RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED'; END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.driver_id IS DISTINCT FROM v_driver_id
    THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED'; END IF;
  IF v_order.status <> 'picking_up'::public.order_status
    THEN RAISE EXCEPTION 'ORDER_NOT_PICKING_UP'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.risk_report_interventions intervention
    WHERE intervention.order_id = v_order.id
      AND intervention.driver_id = v_driver_id
      AND intervention.state IN ('return_required', 'handoff_required')
  ) THEN RAISE EXCEPTION 'CUSTODY_ACTION_REQUIRED'; END IF;

  IF v_order.actual_picked_up_at IS NOT NULL THEN
    RETURN v_order.actual_picked_up_at;
  END IF;

  UPDATE public.orders
  SET actual_picked_up_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE id = p_order_id
  RETURNING actual_picked_up_at INTO v_confirmed_at;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, 'picking_up'::public.order_status, 'Tài xế đã nhận hàng',
    'Tài xế đã xác nhận nhận kiện và đang chờ bắt đầu giao.', v_driver_id
  );
  RETURN v_confirmed_at;
END;
$function$;

REVOKE ALL ON FUNCTION public.confirm_driver_pickup(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_driver_pickup(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.cancel_customer_order(p_order_id uuid, p_customer_id uuid, p_status_note text DEFAULT NULL::text)
 RETURNS TABLE(order_id uuid, driver_id uuid, tracking_code text, new_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_customer_user_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_normalized_note text := NULLIF(btrim(p_status_note), '');
  v_release_amount bigint;
BEGIN
  IF v_customer_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users customer_user
    WHERE customer_user.id = v_customer_user_id
      AND customer_user.role = 'customer'::public.user_role
  ) THEN RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED'; END IF;
  IF p_customer_id IS DISTINCT FROM v_customer_user_id
    THEN RAISE EXCEPTION 'CUSTOMER_ID_MISMATCH'; END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.customer_id IS DISTINCT FROM v_customer_user_id
    THEN RAISE EXCEPTION 'ORDER_NOT_OWNED'; END IF;
  IF v_order.status NOT IN (
    'pending'::public.order_status, 'confirmed'::public.order_status,
    'assigned'::public.order_status, 'picking_up'::public.order_status
  ) THEN RAISE EXCEPTION 'ORDER_NOT_CANCELLABLE'; END IF;
  -- A photo upload is preparatory; only a committed handoff locks cancellation.
  IF v_order.actual_picked_up_at IS NOT NULL
    THEN RAISE EXCEPTION 'ORDER_ALREADY_PICKED_UP'; END IF;

  IF v_order.driver_id IS NOT NULL THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_order.driver_id::text, 0)
    );
    SELECT COALESCE(sum(tx.held_delta), 0)::bigint INTO v_release_amount
    FROM public.driver_wallet_transactions tx
    WHERE tx.driver_id = v_order.driver_id
      AND tx.order_id = v_order.id AND tx.status = 'completed';
    IF v_release_amount > 0 THEN
      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount,
        available_delta, held_delta, idempotency_key, completed_at
      ) VALUES (
        v_order.driver_id, v_order.id, 'cod_release', v_release_amount,
        v_release_amount, -v_release_amount,
        'order:' || v_order.id::text || ':cod_release', clock_timestamp()
      );
    END IF;
  END IF;

  UPDATE public.orders
  SET status = 'cancelled'::public.order_status,
    status_note = v_normalized_note,
    payment_status = CASE
      WHEN delivery_fee_payer = 'sender' AND payment_status = 'paid'
        THEN 'refund_required'
      ELSE payment_status END,
    cancelled_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE id = p_order_id RETURNING * INTO v_order;

  IF v_order.payment_status = 'refund_required' THEN
    UPDATE public.order_payment_sessions session
    SET status = 'refund_required', updated_at = clock_timestamp()
    WHERE session.order_id = v_order.id AND session.status = 'paid';
  END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    v_order.id, 'cancelled'::public.order_status, 'Đơn hàng đã hủy',
    CASE WHEN v_normalized_note IS NULL
      THEN 'Khách hàng đã hủy đơn trước khi tài xế nhận hàng.'
      ELSE 'Khách hàng đã hủy đơn trước khi tài xế nhận hàng. Lý do: '
        || v_normalized_note END,
    v_customer_user_id
  );
  RETURN QUERY SELECT v_order.id, v_order.driver_id,
    v_order.tracking_code, v_order.status::text;
END;
$function$;

-- Apply the same lock to direct status updates as to the customer RPC.
CREATE OR REPLACE FUNCTION public.enforce_customer_cancel_policy()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  IF NEW.status = 'cancelled'::public.order_status THEN
    IF OLD.status IN ('delivering'::public.order_status, 'delivered'::public.order_status) THEN
      RAISE EXCEPTION 'ORDER_NOT_CANCELLABLE';
    END IF;
    IF OLD.actual_picked_up_at IS NOT NULL THEN
      RAISE EXCEPTION 'ORDER_ALREADY_PICKED_UP';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;


-- Keep the progression guard compatible with a fresh migration replay.
CREATE OR REPLACE FUNCTION public.enforce_driver_order_status_progression()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  authorized_custody_transition boolean := false;
  allowed_fields text[] := ARRAY['status', 'updated_at'];
BEGIN
  IF OLD.driver_id = actor_id
    AND EXISTS (
      SELECT 1 FROM public.users actor
      WHERE actor.id = actor_id
        AND actor.role = 'driver'::public.user_role
    )
  THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.risk_report_interventions intervention
      WHERE intervention.order_id = OLD.id
        AND intervention.driver_id = actor_id
        AND (
          (intervention.state = 'return_required'
            AND (
              (OLD.status = 'return_approved'::public.order_status
                AND NEW.status = 'returning'::public.order_status)
              OR (OLD.status = 'returning'::public.order_status
                AND NEW.status = 'returned'::public.order_status)
            )
            AND NEW.driver_id IS NOT DISTINCT FROM OLD.driver_id)
          OR (intervention.state = 'handoff_required'
            AND NEW.status = 'risk_hold'::public.order_status
            AND NEW.driver_id IS NULL)
        )
    ) INTO authorized_custody_transition;

    IF authorized_custody_transition THEN
      IF (to_jsonb(NEW) - 'status' - 'driver_id' - 'risk_hold_report_id'
            - 'status_note' - 'cancelled_at' - 'updated_at') <>
         (to_jsonb(OLD) - 'status' - 'driver_id' - 'risk_hold_report_id'
            - 'status_note' - 'cancelled_at' - 'updated_at') THEN
        RAISE EXCEPTION
          'Custody transition may only update approved order fields.';
      END IF;
      RETURN NEW;
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.risk_report_interventions intervention
      WHERE intervention.order_id = OLD.id
        AND intervention.driver_id = actor_id
        AND intervention.state IN ('return_required', 'handoff_required')
    ) THEN
      RAISE EXCEPTION
        'Custody action must be resolved before delivery progression'
        USING ERRCODE = '23514';
    END IF;

    -- Pickup confirmation commits custody while the vehicle is still parked.
    -- The geofence trigger validates the proof for this timestamp-only update.
    IF OLD.status = 'picking_up'::public.order_status
       AND NEW.status = OLD.status
       AND OLD.actual_picked_up_at IS NULL
       AND NEW.actual_picked_up_at IS NOT NULL
       AND (to_jsonb(NEW) - 'actual_picked_up_at' - 'updated_at') =
           (to_jsonb(OLD) - 'actual_picked_up_at' - 'updated_at') THEN
      RETURN NEW;
    END IF;

    IF OLD.status = 'picking_up'::public.order_status
       AND NEW.status = 'delivering'::public.order_status THEN
      allowed_fields := array_append(allowed_fields, 'actual_picked_up_at');
    ELSIF OLD.status = 'delivering'::public.order_status
          AND NEW.status = 'delivered'::public.order_status THEN
      allowed_fields := array_append(allowed_fields, 'actual_delivered_at');
    END IF;

    IF (to_jsonb(NEW) - allowed_fields) <>
       (to_jsonb(OLD) - allowed_fields) THEN
      RAISE EXCEPTION 'Drivers may only update order status fields.';
    END IF;

    IF NOT (
      (OLD.status = 'assigned'::public.order_status
        AND NEW.status = 'picking_up'::public.order_status)
      OR (OLD.status = 'picking_up'::public.order_status
        AND NEW.status = 'delivering'::public.order_status)
      OR (OLD.status = 'delivering'::public.order_status
        AND NEW.status = 'delivered'::public.order_status)
    ) THEN
      RAISE EXCEPTION 'Invalid driver order status transition.';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

