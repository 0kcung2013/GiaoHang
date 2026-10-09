-- Driver arrival/cancellation deadlines are server-owned business state.
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS pickup_arrived_at timestamptz;
ALTER TABLE public.drivers ADD COLUMN IF NOT EXISTS acceptance_locked_until timestamptz;
COMMENT ON COLUMN public.orders.pickup_arrived_at IS 'First explicit pickup arrival by the assigned driver; store-closed cancellation unlocks after 10 minutes.';
COMMENT ON COLUMN public.drivers.acceptance_locked_until IS 'Temporary acceptance cooldown after voluntary personal cancellation; independent of KYC and Online PIN.';

-- Existing grants are per-column. Never allow clients to rewrite deadlines.
REVOKE INSERT (pickup_arrived_at), UPDATE (pickup_arrived_at) ON public.orders FROM anon, authenticated;
REVOKE INSERT (acceptance_locked_until), UPDATE (acceptance_locked_until) ON public.drivers FROM anon, authenticated;
GRANT SELECT (pickup_arrived_at) ON public.orders TO authenticated;
GRANT SELECT (acceptance_locked_until) ON public.drivers TO authenticated;

CREATE OR REPLACE FUNCTION private.guard_driver_acceptance_lock()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF current_user IN ('anon', 'authenticated') THEN
    IF (TG_OP = 'INSERT' AND NEW.acceptance_locked_until IS NOT NULL)
      OR (TG_OP = 'UPDATE' AND NEW.acceptance_locked_until IS DISTINCT FROM OLD.acceptance_locked_until) THEN
      RAISE EXCEPTION 'DRIVER_ACCEPTANCE_LOCK_SERVER_OWNED';
    END IF;
  END IF;
  IF NEW.is_available AND NEW.acceptance_locked_until > clock_timestamp() THEN
    -- Keep online intent, but accepting/dispatching are blocked separately.
    -- Do not silently flip availability; the expiry restores eligibility.
    IF TG_OP = 'UPDATE' AND NEW.is_available IS DISTINCT FROM OLD.is_available THEN
      RAISE EXCEPTION 'DRIVER_ACCEPTANCE_LOCKED';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER drivers_guard_acceptance_lock
BEFORE INSERT OR UPDATE ON public.drivers
FOR EACH ROW EXECUTE FUNCTION private.guard_driver_acceptance_lock();

CREATE OR REPLACE FUNCTION private.guard_order_driver_cancellation()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE v_locked_until timestamptz;
BEGIN
  IF current_user IN ('anon', 'authenticated') THEN
    IF (TG_OP = 'INSERT' AND NEW.pickup_arrived_at IS NOT NULL)
      OR (TG_OP = 'UPDATE' AND NEW.pickup_arrived_at IS DISTINCT FROM OLD.pickup_arrived_at) THEN
      RAISE EXCEPTION 'PICKUP_ARRIVAL_SERVER_OWNED';
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.driver_id = auth.uid()
      AND NEW.status = 'cancelled'::public.order_status
      AND NEW.status IS DISTINCT FROM OLD.status THEN
      RAISE EXCEPTION 'DRIVER_CANCELLATION_COMMAND_REQUIRED';
    END IF;
  END IF;
  -- Serialize assignment against cancellation using the driver row.
  -- The order row is already locked by accept/claim/cancel.
  IF TG_OP = 'UPDATE'
    AND NEW.driver_id IS NOT NULL AND NEW.driver_id IS DISTINCT FROM OLD.driver_id THEN
    SELECT acceptance_locked_until INTO v_locked_until
    FROM public.drivers WHERE user_id = NEW.driver_id FOR UPDATE;
    IF v_locked_until > clock_timestamp() THEN
      RAISE EXCEPTION 'DRIVER_ACCEPTANCE_LOCKED';
    END IF;
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.driver_id IS DISTINCT FROM OLD.driver_id THEN
    NEW.pickup_arrived_at := NULL;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER orders_05_guard_driver_cancellation
BEFORE INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION private.guard_order_driver_cancellation();

CREATE OR REPLACE FUNCTION public.get_driver_acceptance_state()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_actor uuid := auth.uid(); v_deadline timestamptz;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_actor AND role = 'driver') THEN
    RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED';
  END IF;
  SELECT acceptance_locked_until INTO v_deadline FROM public.drivers WHERE user_id = v_actor;
  IF NOT FOUND THEN RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND'; END IF;
  RETURN jsonb_build_object('server_now', clock_timestamp(), 'locked_until', v_deadline);
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_driver_pickup_arrival(p_order_id uuid, p_lat double precision, p_lng double precision)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_actor uuid := auth.uid(); v_order public.orders%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_actor AND role = 'driver') THEN
    RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED';
  END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.driver_id IS DISTINCT FROM v_actor THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED'; END IF;
  IF v_order.status <> 'picking_up'::public.order_status OR v_order.actual_picked_up_at IS NOT NULL THEN
    RAISE EXCEPTION 'ORDER_NOT_CANCELLABLE';
  END IF;
  IF v_order.pickup_arrived_at IS NULL THEN
    IF p_lat IS NULL OR p_lng IS NULL OR NOT (p_lat BETWEEN -90 AND 90 AND p_lng BETWEEN -180 AND 180) THEN
      RAISE EXCEPTION 'PICKUP_LOCATION_REQUIRED';
    END IF;
    IF NOT public.ST_DWithin(
      public.ST_SetSRID(public.ST_MakePoint(p_lng, p_lat), 4326)::public.geography,
      public.ST_SetSRID(public.ST_MakePoint(v_order.pickup_lng, v_order.pickup_lat), 4326)::public.geography, 100
    ) THEN RAISE EXCEPTION 'PICKUP_OUTSIDE_GEOFENCE'; END IF;
    UPDATE public.orders SET pickup_arrived_at = clock_timestamp()
    WHERE id = p_order_id RETURNING * INTO v_order;
    INSERT INTO public.order_status_logs(order_id, status, title, description, logged_by)
    VALUES (p_order_id, v_order.status, 'Tài xế đã đến điểm lấy',
      'Đã xác nhận đến điểm lấy. Có thể hủy vì quán đóng cửa sau 10 phút.', v_actor);
  END IF;
  RETURN jsonb_build_object('pickup_arrived_at', v_order.pickup_arrived_at, 'server_now', clock_timestamp());
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_driver_order(p_order_id uuid, p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_release bigint;
  v_locked_until timestamptz;
  v_now timestamptz;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_actor AND role = 'driver') THEN
    RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED';
  END IF;
  IF p_reason IS NULL OR p_reason NOT IN ('store_closed', 'personal') THEN
    RAISE EXCEPTION 'CANCELLATION_REASON_INVALID';
  END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  -- Retry after a lost response: do not extend an already committed cooldown.
  IF p_reason = 'personal' AND v_order.driver_id IS DISTINCT FROM v_actor AND EXISTS (
    SELECT 1 FROM public.order_status_logs log
    WHERE log.order_id = p_order_id AND log.logged_by = v_actor
      AND log.title = 'Tài xế hủy nhận đơn' AND log.status = 'pending'
  ) THEN
    SELECT acceptance_locked_until INTO v_locked_until FROM public.drivers WHERE user_id = v_actor;
    RETURN jsonb_build_object('order_id', p_order_id, 'new_status', v_order.status,
      'locked_until', v_locked_until, 'server_now', clock_timestamp());
  END IF;
  IF v_order.driver_id IS DISTINCT FROM v_actor THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED'; END IF;
  IF p_reason = 'store_closed' AND v_order.status = 'cancelled'
    AND v_order.status_note = 'Quán đóng cửa' THEN
    RETURN jsonb_build_object('order_id', p_order_id, 'new_status', 'cancelled',
      'locked_until', NULL, 'server_now', clock_timestamp());
  END IF;
  IF v_order.status NOT IN ('assigned', 'picking_up') OR v_order.actual_picked_up_at IS NOT NULL THEN
    RAISE EXCEPTION 'ORDER_ALREADY_PICKED_UP';
  END IF;
  -- A submitted pickup proof also blocks abandonment until staff resolves custody.
  IF EXISTS (SELECT 1 FROM public.order_delivery_proofs
    WHERE order_id = p_order_id AND driver_id = v_actor AND stage = 'pickup') THEN
    RAISE EXCEPTION 'ORDER_ALREADY_PICKED_UP';
  END IF;
  IF EXISTS (SELECT 1 FROM public.risk_report_interventions WHERE order_id = p_order_id
    AND state IN ('return_required','handoff_required')) THEN
    RAISE EXCEPTION 'CUSTODY_ACTION_REQUIRED';
  END IF;
  v_now := clock_timestamp();
  IF p_reason = 'store_closed' AND (v_order.pickup_arrived_at IS NULL
    OR v_order.pickup_arrived_at + interval '10 minutes' > v_now) THEN
    RAISE EXCEPTION 'STORE_CANCELLATION_WAIT_REQUIRED';
  END IF;
  -- Lock in order -> driver -> wallet order, consistent with assignment.
  PERFORM 1 FROM public.drivers WHERE user_id = v_actor FOR UPDATE;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_actor::text, 0));
  SELECT COALESCE(sum(tx.held_delta),0)::bigint INTO v_release
  FROM public.driver_wallet_transactions tx
  WHERE tx.driver_id = v_actor AND tx.order_id = p_order_id AND tx.status = 'completed';
  IF v_release > 0 THEN
    INSERT INTO public.driver_wallet_transactions(
      driver_id,order_id,transaction_type,amount,available_delta,held_delta,idempotency_key,completed_at)
    VALUES (v_actor,p_order_id,'cod_release',v_release,v_release,-v_release,
      'order:' || p_order_id::text || ':driver:' || v_actor::text || ':cancel_release',v_now);
  END IF;
  IF p_reason = 'personal' THEN
    v_locked_until := clock_timestamp() + interval '30 minutes';
    UPDATE public.drivers SET acceptance_locked_until = v_locked_until, updated_at = clock_timestamp()
    WHERE user_id = v_actor;
    UPDATE public.orders SET driver_id = NULL, status = 'pending', pickup_arrived_at = NULL,
      offered_driver_id = NULL, offer_expires_at = NULL,
      assignment_expires_at = clock_timestamp() + interval '15 minutes', assignment_timed_out_at = NULL,
      estimated_pickup_at = NULL, estimated_delivery_at = NULL,
      rejected_by = CASE WHEN COALESCE(rejected_by,'[]'::jsonb) ? v_actor::text
        THEN rejected_by ELSE COALESCE(rejected_by,'[]'::jsonb) || jsonb_build_array(v_actor::text) END,
      status_note = 'Tài xế hủy vì lý do cá nhân. Đang tìm tài xế khác.'
    WHERE id = p_order_id;
    INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
    VALUES (p_order_id,'pending','Tài xế hủy nhận đơn',
      'Lý do cá nhân. Đơn quay về tìm tài xế; tài xế tạm khóa nhận đơn 30 phút.',v_actor);
    PERFORM private.dispatch_next_order_offer(p_order_id,2000);
    INSERT INTO public.notifications(user_id,title,body,type,is_read,order_id)
    VALUES (v_order.customer_id,'Đang tìm tài xế khác',
      'Tài xế đã hủy nhận đơn vì lý do cá nhân. Đơn của bạn đang tìm tài xế khác.',
      'order_update',false,p_order_id);
  ELSE
    UPDATE public.orders SET status = 'cancelled', status_note = 'Quán đóng cửa',
      cancelled_at = clock_timestamp(),
      payment_status = CASE WHEN delivery_fee_payer = 'sender' AND payment_status = 'paid'
        THEN 'refund_required' ELSE payment_status END
    WHERE id = p_order_id RETURNING * INTO v_order;
    IF v_order.payment_status = 'refund_required' THEN
      UPDATE public.order_payment_sessions SET status = 'refund_required', updated_at = clock_timestamp()
      WHERE order_id = p_order_id AND status = 'paid';
    END IF;
    INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
    VALUES (p_order_id,'cancelled','Đơn hàng đã hủy',
      'Quán đóng cửa. Tài xế đã xác nhận đến điểm lấy và chờ đủ 10 phút.',v_actor);
    INSERT INTO public.notifications(user_id,title,body,type,is_read,order_id)
    VALUES (v_order.customer_id,'Đơn hàng đã hủy',
      'Quán đóng cửa sau khi tài xế đến điểm lấy và chờ đủ 10 phút.',
      'order_update',false,p_order_id);
  END IF;
  RETURN jsonb_build_object('order_id',p_order_id,
    'new_status', CASE WHEN p_reason = 'personal' THEN 'pending' ELSE 'cancelled' END,
    'locked_until',v_locked_until,'server_now',clock_timestamp());
END;
$$;

REVOKE ALL ON FUNCTION private.guard_driver_acceptance_lock(), private.guard_order_driver_cancellation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_driver_acceptance_state(),
  public.confirm_driver_pickup_arrival(uuid,double precision,double precision),
  public.cancel_driver_order(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_driver_acceptance_state(),
  public.confirm_driver_pickup_arrival(uuid,double precision,double precision),
  public.cancel_driver_order(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.accept_order(p_order_id uuid)
 RETURNS TABLE(order_id uuid, customer_id uuid, tracking_code text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
  v_order public.orders%ROWTYPE;
  v_is_available boolean;
  v_approval_status public.approval_status;
  v_available_balance bigint;
  v_required_balance bigint;
BEGIN
  IF v_driver_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF EXISTS (SELECT 1 FROM public.drivers d WHERE d.user_id = v_driver_user_id
    AND d.acceptance_locked_until > clock_timestamp()) THEN
    RAISE EXCEPTION 'DRIVER_ACCEPTANCE_LOCKED';
  END IF;
  SELECT driver_profile.is_available, driver_profile.approval_status
  INTO v_is_available, v_approval_status
  FROM public.drivers AS driver_profile
  WHERE driver_profile.user_id = v_driver_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND'; END IF;
  IF v_approval_status IS DISTINCT FROM 'approved'::public.approval_status
    THEN RAISE EXCEPTION 'DRIVER_NOT_APPROVED'; END IF;
  IF v_is_available IS DISTINCT FROM true
    THEN RAISE EXCEPTION 'DRIVER_OFFLINE'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.orders AS active_order
    WHERE active_order.driver_id = v_driver_user_id
      AND active_order.status IN (
        'assigned'::public.order_status,
        'picking_up'::public.order_status,
        'delivering'::public.order_status
      )
  ) THEN RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER'; END IF;

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.payment_status NOT IN ('not_required', 'paid') THEN
    RAISE EXCEPTION 'ORDER_PAYMENT_INCOMPLETE';
  END IF;
  IF v_order.driver_id IS NOT NULL OR v_order.status NOT IN (
    'pending'::public.order_status, 'confirmed'::public.order_status
  ) THEN RAISE EXCEPTION 'ORDER_NOT_AVAILABLE'; END IF;
  IF v_order.assignment_timed_out_at IS NOT NULL
     OR v_order.assignment_expires_at <= clock_timestamp()
    THEN RAISE EXCEPTION 'ASSIGNMENT_EXPIRED'; END IF;
  IF v_order.offered_driver_id IS DISTINCT FROM v_driver_user_id
    THEN RAISE EXCEPTION 'ORDER_NOT_OFFERED_TO_DRIVER'; END IF;
  IF v_order.offer_expires_at IS NULL
     OR v_order.offer_expires_at <= clock_timestamp()
    THEN RAISE EXCEPTION 'OFFER_EXPIRED'; END IF;

  v_required_balance := v_order.driver_advance_amount;
  IF v_required_balance > 0 THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_driver_user_id::text, 0)
    );
    SELECT COALESCE(sum(tx.available_delta), 0)::bigint
    INTO v_available_balance
    FROM public.driver_wallet_transactions AS tx
    WHERE tx.driver_id = v_driver_user_id
      AND tx.status = 'completed';
    IF v_available_balance < v_required_balance THEN
      RAISE EXCEPTION 'INSUFFICIENT_WALLET_BALANCE';
    END IF;
  END IF;

  BEGIN
    UPDATE public.orders
    SET
      driver_id = v_driver_user_id,
      status = 'assigned'::public.order_status,
      offered_driver_id = NULL,
      offer_expires_at = NULL,
      updated_at = clock_timestamp()
    WHERE id = p_order_id
    RETURNING * INTO v_order;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER';
  END;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, 'assigned'::public.order_status,
    'Đã có tài xế nhận đơn',
    'Tài xế đã chấp nhận lời mời. Tiền hàng chỉ được trừ khi xác nhận nhận kiện.',
    v_driver_user_id
  );
  RETURN QUERY SELECT v_order.id, v_order.customer_id, v_order.tracking_code;
END;
$function$;


CREATE OR REPLACE FUNCTION public.claim_free_pick_order(p_order_id uuid)
 RETURNS TABLE(order_id uuid, customer_id uuid, tracking_code text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  driver_user_id uuid := auth.uid();
  driver_profile public.drivers%ROWTYPE;
  free_order public.orders%ROWTYPE;
BEGIN
  IF driver_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT * INTO driver_profile
  FROM public.drivers
  WHERE user_id = driver_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND'; END IF;
  IF driver_profile.acceptance_locked_until > clock_timestamp() THEN
    RAISE EXCEPTION 'DRIVER_ACCEPTANCE_LOCKED';
  END IF;
  IF driver_profile.current_lat IS NULL
     OR driver_profile.current_lng IS NULL
     OR driver_profile.location_updated_at <
        clock_timestamp() - interval '3 minutes' THEN
    RAISE EXCEPTION 'DRIVER_LOCATION_STALE';
  END IF;

  SELECT * INTO free_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF free_order.driver_id IS NOT NULL
     OR free_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     )
     OR free_order.assignment_timed_out_at IS NOT NULL
     OR free_order.assignment_expires_at <= clock_timestamp() THEN
    RAISE EXCEPTION 'ORDER_NOT_AVAILABLE';
  END IF;
  IF free_order.offered_driver_id IS NOT NULL
     AND free_order.offered_driver_id IS DISTINCT FROM driver_user_id
     AND free_order.offer_expires_at > clock_timestamp() THEN
    RAISE EXCEPTION 'FREE_PICK_ORDER_RESERVED';
  END IF;
  IF NOT public.ST_DWithin(
    public.ST_SetSRID(
      public.ST_MakePoint(
        driver_profile.current_lng,
        driver_profile.current_lat
      ),
      4326
    )::public.geography,
    public.ST_SetSRID(
      public.ST_MakePoint(free_order.pickup_lng, free_order.pickup_lat),
      4326
    )::public.geography,
    50000
  ) THEN RAISE EXCEPTION 'FREE_PICK_OUT_OF_RANGE'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.orders AS active_offer
    WHERE active_offer.id <> p_order_id
      AND active_offer.offered_driver_id = driver_user_id
      AND active_offer.driver_id IS NULL
      AND active_offer.offer_expires_at > clock_timestamp()
      AND active_offer.assignment_timed_out_at IS NULL
      AND active_offer.status IN (
        'pending'::public.order_status,
        'confirmed'::public.order_status
      )
  ) THEN RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_OFFER'; END IF;

  UPDATE public.orders
  SET offered_driver_id = driver_user_id,
      offer_expires_at = LEAST(
        clock_timestamp() + interval '45 seconds',
        free_order.assignment_expires_at
      ),
      status_note = 'TĂ i xáº¿ Ä‘ang nháº­n Ä‘Æ¡n qua FreePick.'
  WHERE id = p_order_id;

  RETURN QUERY
  SELECT accepted.order_id, accepted.customer_id, accepted.tracking_code
  FROM public.accept_order(p_order_id) AS accepted;
END;
$function$;


CREATE OR REPLACE FUNCTION public.get_free_pick_orders_in_view(p_south double precision, p_west double precision, p_north double precision, p_east double precision, p_limit integer DEFAULT 50)
 RETURNS SETOF orders
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  driver_user_id uuid := auth.uid();
  driver_profile public.drivers%ROWTYPE;
BEGIN
  IF driver_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF p_south < -90 OR p_north > 90
     OR p_west < -180 OR p_east > 180
     OR p_south >= p_north OR p_west >= p_east THEN
    RAISE EXCEPTION 'FREE_PICK_VIEWPORT_INVALID';
  END IF;
  IF p_north - p_south > 1 OR p_east - p_west > 1 THEN
    RAISE EXCEPTION 'FREE_PICK_VIEWPORT_TOO_LARGE';
  END IF;

  SELECT * INTO driver_profile
  FROM public.drivers
  WHERE user_id = driver_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND'; END IF;
  IF driver_profile.acceptance_locked_until > clock_timestamp() THEN
    RAISE EXCEPTION 'DRIVER_ACCEPTANCE_LOCKED';
  END IF;
  IF driver_profile.approval_status IS DISTINCT FROM
     'approved'::public.approval_status THEN
    RAISE EXCEPTION 'DRIVER_NOT_APPROVED';
  END IF;
  IF driver_profile.is_available IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'DRIVER_OFFLINE';
  END IF;
  IF driver_profile.current_lat IS NULL
     OR driver_profile.current_lng IS NULL
     OR driver_profile.location_updated_at < now() - interval '3 minutes' THEN
    RAISE EXCEPTION 'DRIVER_LOCATION_STALE';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.orders AS active_order
    WHERE active_order.driver_id = driver_user_id
      AND active_order.status IN (
        'assigned'::public.order_status,
        'picking_up'::public.order_status,
        'delivering'::public.order_status
      )
  ) THEN RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.orders AS active_offer
    WHERE active_offer.offered_driver_id = driver_user_id
      AND active_offer.driver_id IS NULL
      AND active_offer.offer_expires_at > now()
      AND active_offer.assignment_timed_out_at IS NULL
      AND active_offer.status IN (
        'pending'::public.order_status,
        'confirmed'::public.order_status
      )
  ) THEN RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_OFFER'; END IF;

  RETURN QUERY
  SELECT free_order.*
  FROM public.orders AS free_order
  WHERE free_order.driver_id IS NULL
    AND free_order.status IN (
      'pending'::public.order_status,
      'confirmed'::public.order_status
    )
    AND free_order.payment_status IN ('not_required', 'paid')
    AND free_order.assignment_timed_out_at IS NULL
    AND free_order.assignment_expires_at > now()
    AND (
      free_order.offered_driver_id IS NULL
      OR free_order.offer_expires_at IS NULL
      OR free_order.offer_expires_at <= now()
    )
    AND free_order.pickup_lat BETWEEN p_south AND p_north
    AND free_order.pickup_lng BETWEEN p_west AND p_east
    AND public.ST_DWithin(
      public.ST_SetSRID(
        public.ST_MakePoint(
          driver_profile.current_lng,
          driver_profile.current_lat
        ),
        4326
      )::public.geography,
      public.ST_SetSRID(
        public.ST_MakePoint(free_order.pickup_lng, free_order.pickup_lat),
        4326
      )::public.geography,
      50000
    )
  ORDER BY free_order.created_at ASC, free_order.id ASC
  LIMIT LEAST(GREATEST(p_limit, 1), 50);
END;
$function$;


CREATE OR REPLACE FUNCTION public.set_driver_online_with_location(p_lat double precision, p_lng double precision, p_pin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
  v_now timestamptz := clock_timestamp();
  v_pin_hash text;
  v_failed_attempts smallint;
  v_locked_until timestamptz;
  v_pin_matches boolean := false;
  v_offered_order_id uuid;
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

  SELECT
    driver.online_pin_hash,
    driver.online_pin_failed_attempts,
    driver.online_pin_locked_until
  INTO
    v_pin_hash,
    v_failed_attempts,
    v_locked_until
  FROM public.drivers AS driver
  WHERE driver.user_id = v_driver_user_id
    AND driver.approval_status = 'approved'::public.approval_status
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPROVED_DRIVER_REQUIRED';
  END IF;

  IF EXISTS (SELECT 1 FROM public.drivers d WHERE d.user_id = v_driver_user_id
    AND d.acceptance_locked_until > clock_timestamp()) THEN
    RAISE EXCEPTION 'DRIVER_ACCEPTANCE_LOCKED';
  END IF;

  IF v_pin_hash IS NULL THEN
    RETURN jsonb_build_object('status', 'pin_not_configured');
  END IF;

  IF v_locked_until IS NOT NULL AND v_locked_until > v_now THEN
    RETURN jsonb_build_object(
      'status', 'locked',
      'locked_until', v_locked_until
    );
  END IF;

  IF p_pin IS NOT NULL AND p_pin ~ '^[0-9]{6}$' THEN
    v_pin_matches := extensions.crypt(p_pin, v_pin_hash) = v_pin_hash;
  END IF;

  IF NOT v_pin_matches THEN
    v_failed_attempts := LEAST(v_failed_attempts + 1, 5);

    IF v_failed_attempts >= 5 THEN
      v_locked_until := v_now + interval '5 minutes';
      UPDATE public.drivers AS driver
      SET
        online_pin_failed_attempts = 0,
        online_pin_locked_until = v_locked_until,
        updated_at = v_now
      WHERE driver.user_id = v_driver_user_id;

      RETURN jsonb_build_object(
        'status', 'locked',
        'locked_until', v_locked_until
      );
    END IF;

    UPDATE public.drivers AS driver
    SET
      online_pin_failed_attempts = v_failed_attempts,
      online_pin_locked_until = NULL,
      updated_at = v_now
    WHERE driver.user_id = v_driver_user_id;

    RETURN jsonb_build_object(
      'status', 'invalid_pin',
      'remaining_attempts', 5 - v_failed_attempts
    );
  END IF;

  UPDATE public.drivers AS driver
  SET
    current_lat = p_lat,
    current_lng = p_lng,
    location_updated_at = v_now,
    is_available = true,
    online_pin_failed_attempts = 0,
    online_pin_locked_until = NULL,
    updated_at = v_now
  WHERE driver.user_id = v_driver_user_id;

  IF NOT EXISTS (
    SELECT 1
    FROM public.orders AS active_return
    WHERE active_return.driver_id = v_driver_user_id
      AND active_return.status IN (
        'return_approved'::public.order_status,
        'returning'::public.order_status
      )
  ) THEN
    v_offered_order_id :=
      private.dispatch_waiting_orders_for_driver(v_driver_user_id);
  END IF;

  RETURN jsonb_build_object(
    'status', 'online',
    'offered_order_id', v_offered_order_id
  );
END;
$function$;


CREATE OR REPLACE FUNCTION public.get_my_driver_account_profile()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_role public.user_role;
  v_result jsonb;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;

  SELECT actor.role
  INTO v_role
  FROM public.users AS actor
  WHERE actor.id = v_actor_id;

  IF v_role IS DISTINCT FROM 'driver'::public.user_role THEN
    RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED';
  END IF;

  SELECT jsonb_build_object(
    'id', driver.id,
    'driver_id', driver.id,
    'user_id', driver.user_id,
    'full_name', app_user.full_name,
    'email', app_user.email,
    'phone', app_user.phone,
    'avatar_url', app_user.avatar_url,
    'created_at', app_user.created_at,
    'member_since', app_user.created_at,
    'vehicle_type', driver.vehicle_type,
    'license_plate', driver.license_plate,
    'vehicle_brand_model', driver.vehicle_brand_model,
    'vehicle_color', driver.vehicle_color,
    'is_available', driver.is_available,
    'acceptance_locked_until', driver.acceptance_locked_until,
    'current_lat', driver.current_lat,
    'current_lng', driver.current_lng,
    'updated_at', driver.updated_at,
    'location_updated_at', driver.location_updated_at,
    'total_deliveries', driver.total_deliveries,
    'approval_status', driver.approval_status::text,
    'verified_at', driver.verified_at,
    'submitted_at', driver.submitted_at,
    'rejection_reason', driver.rejection_reason,
    'id_card_number', driver.id_card_number,
    'id_card_front_url', driver.id_card_front_url,
    'id_card_back_url', driver.id_card_back_url,
    'driver_license_number', driver.driver_license_number,
    'driver_license_url', driver.driver_license_url,
    'vehicle_photo_url', driver.vehicle_photo_url
  )
  INTO v_result
  FROM public.drivers AS driver
  JOIN public.users AS app_user ON app_user.id = driver.user_id
  WHERE driver.user_id = v_actor_id;

  RETURN v_result;
END;
$function$;


CREATE OR REPLACE FUNCTION public.find_nearest_drivers(pickup_lat double precision, pickup_lng double precision, radius_meters double precision DEFAULT 2000, max_results integer DEFAULT 10)
 RETURNS TABLE(id uuid, user_id uuid, full_name text, vehicle_type text, license_plate text, current_lat double precision, current_lng double precision, distance_meters double precision, rating double precision, location_updated_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  WITH candidate_distances AS (
    SELECT
      driver_profile.id,
      driver_profile.user_id,
      driver_user.full_name,
      driver_profile.vehicle_type,
      driver_profile.license_plate,
      driver_profile.current_lat,
      driver_profile.current_lng,
      public.ST_Distance(
        public.ST_SetSRID(
          public.ST_MakePoint(
            driver_profile.current_lng,
            driver_profile.current_lat
          ),
          4326
        )::public.geography,
        public.ST_SetSRID(
          public.ST_MakePoint(pickup_lng, pickup_lat),
          4326
        )::public.geography
      ) AS distance_meters,
      COALESCE(driver_profile.rating, 0)::double precision AS rating,
      driver_profile.location_updated_at
    FROM public.drivers AS driver_profile
    JOIN public.users AS driver_user
      ON driver_user.id = driver_profile.user_id
    WHERE auth.uid() IS NOT NULL
      AND pickup_lat BETWEEN -90 AND 90
      AND pickup_lng BETWEEN -180 AND 180
      AND radius_meters > 0
      AND driver_profile.is_available = true
      AND (driver_profile.acceptance_locked_until IS NULL
        OR driver_profile.acceptance_locked_until <= now())
      AND driver_profile.approval_status =
        'approved'::public.approval_status
      AND driver_profile.current_lat IS NOT NULL
      AND driver_profile.current_lng IS NOT NULL
      AND driver_profile.location_updated_at >= now() - interval '3 minutes'
      AND NOT EXISTS (
        SELECT 1
        FROM public.orders AS active_order
        WHERE active_order.driver_id = driver_profile.user_id
          AND active_order.status IN (
            'assigned'::public.order_status,
            'picking_up'::public.order_status,
            'delivering'::public.order_status
          )
      )
      AND public.ST_DWithin(
        public.ST_SetSRID(
          public.ST_MakePoint(
            driver_profile.current_lng,
            driver_profile.current_lat
          ),
          4326
        )::public.geography,
        public.ST_SetSRID(
          public.ST_MakePoint(pickup_lng, pickup_lat),
          4326
        )::public.geography,
        LEAST(GREATEST(radius_meters, 1), 2000)
      )
  )
  SELECT
    candidate.id,
    candidate.user_id,
    candidate.full_name,
    candidate.vehicle_type,
    candidate.license_plate,
    candidate.current_lat,
    candidate.current_lng,
    candidate.distance_meters,
    candidate.rating,
    candidate.location_updated_at
  FROM candidate_distances AS candidate
  ORDER BY candidate.distance_meters ASC, candidate.user_id ASC
  LIMIT LEAST(GREATEST(max_results, 1), 50);
$function$;


CREATE OR REPLACE FUNCTION private.dispatch_next_order_offer_unbounded(p_order_id uuid, p_radius_meters double precision DEFAULT 2000)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  offer_order public.orders%ROWTYPE;
  candidate record;
  v_now timestamptz := clock_timestamp();
  excluded_drivers jsonb;
  offer_deadline timestamptz;
BEGIN
  SELECT *
  INTO offer_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN RETURN NULL; END IF;

  IF COALESCE(offer_order.note, '') = 'FREEPICK_DEMO_PERSISTENT' THEN
    UPDATE public.orders
    SET offered_driver_id = NULL,
        offer_expires_at = NULL,
        status_note = NULL
    WHERE id = p_order_id;
    RETURN NULL;
  END IF;

  IF offer_order.driver_id IS NOT NULL
     OR offer_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     )
     OR offer_order.assignment_timed_out_at IS NOT NULL THEN
    RETURN NULL;
  END IF;

  excluded_drivers := COALESCE(offer_order.rejected_by, '[]'::jsonb);

  IF offer_order.assignment_expires_at <= v_now THEN
    IF offer_order.offered_driver_id IS NOT NULL
       AND NOT (excluded_drivers ? offer_order.offered_driver_id::text) THEN
      excluded_drivers := excluded_drivers
        || pg_catalog.jsonb_build_array(offer_order.offered_driver_id::text);
    END IF;
    UPDATE public.orders
    SET assignment_timed_out_at = v_now,
        offered_driver_id = NULL,
        offer_expires_at = NULL,
        rejected_by = excluded_drivers,
        status_note = 'Không có tài xế nhận đơn trong vòng 15 phút.'
    WHERE id = p_order_id AND assignment_timed_out_at IS NULL;
    IF FOUND THEN
      INSERT INTO public.order_status_logs(
        order_id, status, title, description, logged_by
      ) VALUES (
        p_order_id, offer_order.status, 'Chưa tìm thấy tài xế',
        'Không có tài xế nhận đơn trong vòng 15 phút.', NULL
      );
    END IF;
    RETURN NULL;
  END IF;

  IF offer_order.offered_driver_id IS NOT NULL
     AND offer_order.offer_expires_at > v_now THEN
    RETURN offer_order.offered_driver_id;
  END IF;

  IF offer_order.offered_driver_id IS NOT NULL THEN
    IF NOT (excluded_drivers ? offer_order.offered_driver_id::text) THEN
      excluded_drivers := excluded_drivers
        || pg_catalog.jsonb_build_array(offer_order.offered_driver_id::text);
    END IF;
    INSERT INTO public.order_status_logs(
      order_id, status, title, description, logged_by
    ) VALUES (
      p_order_id, offer_order.status, 'Lời mời tài xế hết hạn',
      'Tài xế không phản hồi lời mời trong vòng 45 giây.', NULL
    );
    UPDATE public.orders
    SET rejected_by = excluded_drivers,
        offered_driver_id = NULL,
        offer_expires_at = NULL
    WHERE id = p_order_id;
  END IF;

  FOR candidate IN
    WITH candidate_distances AS (
      SELECT
        driver_profile.user_id,
        public.ST_Distance(
          public.ST_SetSRID(
            public.ST_MakePoint(
              driver_profile.current_lng,
              driver_profile.current_lat
            ),
            4326
          )::public.geography,
          public.ST_SetSRID(
            public.ST_MakePoint(
              offer_order.pickup_lng,
              offer_order.pickup_lat
            ),
            4326
          )::public.geography
        ) AS distance_meters
      FROM public.drivers AS driver_profile
      WHERE driver_profile.is_available = true
        AND (driver_profile.acceptance_locked_until IS NULL
          OR driver_profile.acceptance_locked_until <= clock_timestamp())
        AND driver_profile.approval_status =
          'approved'::public.approval_status
        AND driver_profile.current_lat IS NOT NULL
        AND driver_profile.current_lng IS NOT NULL
        AND driver_profile.location_updated_at >=
          clock_timestamp() - interval '3 minutes'
        AND NOT (excluded_drivers ? driver_profile.user_id::text)
        AND COALESCE(
          (
            SELECT sum(wallet_tx.available_delta)
            FROM public.driver_wallet_transactions AS wallet_tx
            WHERE wallet_tx.driver_id = driver_profile.user_id
              AND wallet_tx.status = 'completed'
          ),
          0
        ) >= offer_order.driver_advance_amount
        AND NOT EXISTS (
          SELECT 1 FROM public.orders AS active_order
          WHERE active_order.driver_id = driver_profile.user_id
            AND active_order.status IN (
              'assigned'::public.order_status,
              'picking_up'::public.order_status,
              'delivering'::public.order_status
            )
        )
        AND NOT EXISTS (
          SELECT 1 FROM public.orders AS active_offer
          WHERE active_offer.id <> p_order_id
            AND active_offer.offered_driver_id = driver_profile.user_id
            AND active_offer.driver_id IS NULL
            AND active_offer.assignment_timed_out_at IS NULL
            AND active_offer.status IN (
              'pending'::public.order_status,
              'confirmed'::public.order_status
            )
            AND active_offer.offer_expires_at > clock_timestamp()
        )
        AND public.ST_DWithin(
          public.ST_SetSRID(
            public.ST_MakePoint(
              driver_profile.current_lng,
              driver_profile.current_lat
            ),
            4326
          )::public.geography,
          public.ST_SetSRID(
            public.ST_MakePoint(
              offer_order.pickup_lng,
              offer_order.pickup_lat
            ),
            4326
          )::public.geography,
          LEAST(GREATEST(p_radius_meters, 1), 2000)
        )
    )
    SELECT ranked.user_id, ranked.distance_meters
    FROM candidate_distances AS ranked
    ORDER BY ranked.distance_meters ASC, ranked.user_id ASC
  LOOP
    BEGIN
      offer_deadline := LEAST(
        clock_timestamp() + interval '45 seconds',
        offer_order.assignment_expires_at
      );
      UPDATE public.orders
      SET offered_driver_id = candidate.user_id,
          offer_expires_at = offer_deadline,
          rejected_by = excluded_drivers,
          status_note = NULL
      WHERE id = p_order_id
        AND driver_id IS NULL
        AND offered_driver_id IS NULL
        AND assignment_timed_out_at IS NULL
        AND assignment_expires_at > clock_timestamp()
        AND status IN (
          'pending'::public.order_status,
          'confirmed'::public.order_status
        );
      IF FOUND THEN
        INSERT INTO public.notifications(
          user_id, title, body, type, is_read, order_id
        ) VALUES (
          candidate.user_id,
          'Đơn giao hàng mới',
          pg_catalog.format(
            'Đơn %s đang chờ bạn nhận. Điểm lấy: %s',
            offer_order.tracking_code,
            offer_order.pickup_address
          ),
          'order_update', false, p_order_id
        );
        INSERT INTO public.order_status_logs(
          order_id, status, title, description, logged_by
        ) VALUES (
          p_order_id,
          offer_order.status,
          'Đã gửi lời mời tài xế',
          pg_catalog.format(
            'Hệ thống đã gửi lời mời trong 45 giây cho tài xế gần nhất (%s m).',
            pg_catalog.round(COALESCE(candidate.distance_meters, 0))::text
          ),
          NULL
        );
        RETURN candidate.user_id;
      END IF;
    EXCEPTION WHEN unique_violation THEN
      CONTINUE;
    END;
  END LOOP;
  RETURN NULL;
END;
$function$;


CREATE OR REPLACE FUNCTION private.dispatch_waiting_orders_for_driver(p_driver_user_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
     OR v_driver.acceptance_locked_until > clock_timestamp()
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
$function$;
CREATE OR REPLACE FUNCTION public.get_driver_order_cancellation_state(p_order_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_actor uuid := auth.uid(); v_order public.orders%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_actor AND role = 'driver') THEN
    RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED';
  END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.driver_id IS DISTINCT FROM v_actor THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED'; END IF;
  RETURN jsonb_build_object('status',v_order.status,'pickup_arrived_at',v_order.pickup_arrived_at,
    'pickup_confirmed',v_order.actual_picked_up_at IS NOT NULL OR EXISTS (
      SELECT 1 FROM public.order_delivery_proofs WHERE order_id = p_order_id AND driver_id = v_actor AND stage = 'pickup'),
    'server_now',clock_timestamp());
END;
$$;
REVOKE ALL ON FUNCTION public.get_driver_order_cancellation_state(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_driver_order_cancellation_state(uuid) TO authenticated;
CREATE OR REPLACE FUNCTION private.guard_offer_driver_active_return()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NEW.offered_driver_id IS NULL
     OR NEW.offered_driver_id IS NOT DISTINCT FROM OLD.offered_driver_id THEN
    RETURN NEW;
  END IF;

  IF EXISTS (SELECT 1 FROM public.drivers d WHERE d.user_id = NEW.offered_driver_id
    AND d.acceptance_locked_until > clock_timestamp()) THEN
    RAISE unique_violation USING MESSAGE = 'DRIVER_ACCEPTANCE_LOCKED';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.orders AS active_return
    WHERE active_return.id <> NEW.id
      AND active_return.driver_id = NEW.offered_driver_id
      AND active_return.status IN (
        'return_approved'::public.order_status,
        'returning'::public.order_status
      )
  ) THEN
    RAISE unique_violation USING MESSAGE = 'DRIVER_HAS_ACTIVE_RETURN';
  END IF;

  RETURN NEW;
END;
$function$;
