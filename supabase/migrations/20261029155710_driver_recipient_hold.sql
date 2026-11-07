-- One held parcel plus one working order; no new status enum or table.
ALTER TABLE public.orders ADD COLUMN delivery_hold jsonb;
COMMENT ON COLUMN public.orders.delivery_hold IS 'Server-owned recipient-requested hold; custody and COD remain with driver.';

CREATE FUNCTION private.is_recipient_hold(p_hold jsonb) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT coalesce(p_hold->>'state'='holding',false);
$$;
REVOKE ALL ON FUNCTION private.is_recipient_hold(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.is_recipient_hold(jsonb) TO authenticated,service_role;

DROP INDEX public.orders_one_active_per_driver_idx;
CREATE UNIQUE INDEX orders_one_active_per_driver_idx ON public.orders(driver_id)
 WHERE driver_id IS NOT NULL AND status IN ('assigned','picking_up','delivering','return_approved','returning')
 AND NOT private.is_recipient_hold(delivery_hold);
CREATE UNIQUE INDEX orders_one_recipient_hold_per_driver_idx ON public.orders(driver_id)
 WHERE driver_id IS NOT NULL AND status='delivering' AND private.is_recipient_hold(delivery_hold);

CREATE FUNCTION private.guard_recipient_hold() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
DECLARE finish_at timestamptz;
BEGIN
 IF current_user IN ('anon','authenticated') AND (
   (TG_OP='INSERT' AND NEW.delivery_hold IS NOT NULL) OR
   (TG_OP='UPDATE' AND NEW.delivery_hold IS DISTINCT FROM OLD.delivery_hold)) THEN
   RAISE EXCEPTION 'HOLD_SERVER_OWNED' USING ERRCODE='42501';
 END IF;
 IF TG_OP='UPDATE' AND private.is_recipient_hold(OLD.delivery_hold)
   AND (NEW.status<>'delivering' OR NEW.driver_id IS DISTINCT FROM OLD.driver_id) THEN
   finish_at:=least(clock_timestamp(),(OLD.delivery_hold->>'until')::timestamptz+interval '5 minutes');
   NEW.delivery_hold:=OLD.delivery_hold||jsonb_build_object('state','finished','ended_at',finish_at);
   NEW.estimated_delivery_at:=(OLD.delivery_hold->>'original_deadline')::timestamptz
       +greatest(interval '0',finish_at-(OLD.delivery_hold->>'started_at')::timestamptz);
 END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER orders_02_guard_recipient_hold BEFORE INSERT OR UPDATE ON public.orders
 FOR EACH ROW EXECUTE FUNCTION private.guard_recipient_hold();
REVOKE ALL ON FUNCTION private.guard_recipient_hold() FROM PUBLIC;

CREATE FUNCTION public.set_driver_recipient_hold(p_order_id uuid,p_minutes integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); o public.orders%ROWTYPE; d public.drivers%ROWTYPE;
 t timestamptz:=clock_timestamp(); h jsonb; finish_at timestamptz;
BEGIN
 IF actor IS NULL OR NOT EXISTS(SELECT 1 FROM public.users WHERE id=actor AND role='driver')
 THEN RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED' USING ERRCODE='42501'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text,0));
 SELECT * INTO o FROM public.orders WHERE id=p_order_id FOR UPDATE;
 IF NOT FOUND OR o.driver_id IS DISTINCT FROM actor THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED' USING ERRCODE='42501'; END IF;
 IF o.status<>'delivering' THEN RAISE EXCEPTION 'HOLD_INVALID_STATUS'; END IF;
 IF EXISTS(SELECT 1 FROM public.risk_report_interventions WHERE order_id=o.id
   AND state IN ('awaiting_triage','return_required','handoff_required')) THEN RAISE EXCEPTION 'HOLD_SUPPORT_ACTION_PENDING'; END IF;
 h:=o.delivery_hold;
 IF p_minutes IS NOT NULL THEN
   IF p_minutes<1 OR p_minutes>60 THEN RAISE EXCEPTION 'HOLD_DURATION_INVALID'; END IF;
   IF private.is_recipient_hold(h) THEN RETURN jsonb_build_object('order',to_jsonb(o),'server_now',t); END IF;
   IF h IS NOT NULL THEN RAISE EXCEPTION 'HOLD_ALREADY_USED'; END IF;
   IF EXISTS(SELECT 1 FROM public.orders WHERE driver_id=actor AND id<>o.id
     AND status IN ('assigned','picking_up','delivering','return_approved','returning')) THEN RAISE EXCEPTION 'HOLD_OTHER_ORDER_ACTIVE'; END IF;
   SELECT * INTO d FROM public.drivers WHERE user_id=actor;
   IF d.location_updated_at IS NULL OR d.location_updated_at<t-interval '60 seconds'
     OR d.location_updated_at>t+interval '5 seconds' OR d.current_lat IS NULL OR d.current_lng IS NULL
   THEN RAISE EXCEPTION 'DELIVERY_LOCATION_STALE'; END IF;
   IF NOT public.ST_DWithin(public.ST_SetSRID(public.ST_MakePoint(d.current_lng,d.current_lat),4326)::public.geography,
     public.ST_SetSRID(public.ST_MakePoint(o.delivery_lng,o.delivery_lat),4326)::public.geography,100)
   THEN RAISE EXCEPTION 'DELIVERY_OUTSIDE_GEOFENCE'; END IF;
   h:=jsonb_build_object('state','holding','started_at',t,'until',t+make_interval(mins=>p_minutes),
     'original_deadline',o.estimated_delivery_at,'fee_mode','participant_agreement');
   UPDATE public.orders SET delivery_hold=h,estimated_delivery_at=estimated_delivery_at+make_interval(mins=>p_minutes+5)
    WHERE id=o.id RETURNING * INTO o;
   INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
    VALUES(o.id,o.status,'Khách hẹn giao lại sau',h::text,actor);
   INSERT INTO public.notifications(user_id,title,body,type,is_read,order_id)
    VALUES(o.customer_id,'Khách hẹn giao lại sau',format('Tài xế giữ hàng, hẹn giao lại lúc %s. Phí đợi do tài xế và người nhận thỏa thuận.',
      to_char((h->>'until')::timestamptz AT TIME ZONE 'Asia/Ho_Chi_Minh','HH24:MI')),'system',false,o.id);
 ELSE
   IF NOT private.is_recipient_hold(h) THEN RETURN jsonb_build_object('order',to_jsonb(o),'server_now',t); END IF;
   IF EXISTS(SELECT 1 FROM public.orders WHERE driver_id=actor AND id<>o.id
    AND status IN ('assigned','picking_up','delivering','return_approved','returning')
    AND NOT private.is_recipient_hold(delivery_hold)) THEN RAISE EXCEPTION 'HOLD_OTHER_ORDER_ACTIVE'; END IF;
   finish_at:=least(t,(h->>'until')::timestamptz+interval '5 minutes');
   UPDATE public.orders SET delivery_hold=h||jsonb_build_object('state','resumed','ended_at',t),
    estimated_delivery_at=(h->>'original_deadline')::timestamptz+greatest(interval '0',finish_at-(h->>'started_at')::timestamptz)
    WHERE id=o.id RETURNING * INTO o;
   INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
    VALUES(o.id,o.status,'Tiếp tục giao đơn đang giữ',o.delivery_hold::text,actor);
 END IF;
 RETURN jsonb_build_object('order',to_jsonb(o),'server_now',clock_timestamp());
END; $$;
REVOKE ALL ON FUNCTION public.set_driver_recipient_hold(uuid,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.set_driver_recipient_hold(uuid,integer) TO authenticated;

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
      AND (NOT private.is_recipient_hold(active_order.delivery_hold)
        OR (active_order.delivery_hold->>'until')::timestamptz<=clock_timestamp()
        OR active_order.delivery_hold->>'return_report_id' IS NOT NULL)
      AND active_order.status IN (
        'assigned'::public.order_status,
        'picking_up'::public.order_status,
        'delivering'::public.order_status,
        'return_approved'::public.order_status,
        'returning'::public.order_status
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
      private.business_number(free_order.business_policy,'free_pick_radius_m')+200
    )
  ORDER BY free_order.created_at ASC, free_order.id ASC
  LIMIT LEAST(GREATEST(p_limit, 1), 50);
END;
$function$
;

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
          AND (NOT private.is_recipient_hold(active_order.delivery_hold)
        OR (active_order.delivery_hold->>'until')::timestamptz<=clock_timestamp()
        OR active_order.delivery_hold->>'return_report_id' IS NOT NULL)
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
$function$
;

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
  IF EXISTS(SELECT 1 FROM public.orders WHERE driver_id=auth.uid()
    AND status='delivering' AND private.is_recipient_hold(delivery_hold)
    AND (delivery_hold->>'until')::timestamptz<=clock_timestamp()) THEN
    RAISE EXCEPTION 'HOLD_REDELIVERY_DUE'; END IF;
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
  PERFORM pg_advisory_xact_lock(hashtextextended('driver-assignment:' || driver_user_id::text,0));
  IF NOT private.valid_pickup_road_quote(
    NULLIF(current_setting('giaohang.road_pickup_quote',true),'')::jsonb,
    driver_profile,free_order,(private.business_number(free_order.business_policy,'auto_radius_m')+0.000001)::double precision,private.business_number(free_order.business_policy,'free_pick_radius_m')::double precision) THEN
    RAISE EXCEPTION 'ROAD_ROUTE_QUOTE_REQUIRED';
  END IF;
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
        clock_timestamp() + make_interval(secs=>private.business_number(free_order.business_policy,'offer_seconds')::double precision),
        free_order.assignment_expires_at
      ),
      status_note = 'Tài xế đang nhận đơn qua FreePick.'
  WHERE id = p_order_id;

  RETURN QUERY
  SELECT accepted.order_id, accepted.customer_id, accepted.tracking_code
  FROM public.accept_order(p_order_id) AS accepted;
END;
$function$
;

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
      AND (NOT private.is_recipient_hold(active_order.delivery_hold)
        OR (active_order.delivery_hold->>'until')::timestamptz<=clock_timestamp()
        OR active_order.delivery_hold->>'return_report_id' IS NOT NULL)
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
$function$
;

CREATE OR REPLACE FUNCTION public.road_lookup_candidates(pickup_lat double precision, pickup_lng double precision, radius_meters double precision DEFAULT 2000, max_results integer DEFAULT 10)
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
    WHERE pickup_lat BETWEEN -90 AND 90
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
          AND (NOT private.is_recipient_hold(active_order.delivery_hold)
        OR (active_order.delivery_hold->>'until')::timestamptz<=clock_timestamp()
        OR active_order.delivery_hold->>'return_report_id' IS NOT NULL)
      AND active_order.status IN (
            'assigned'::public.order_status,
            'picking_up'::public.order_status,
            'delivering'::public.order_status,
            'return_approved'::public.order_status,
            'returning'::public.order_status
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
        LEAST(GREATEST(radius_meters,1),private.business_number(private.current_business_settings(),'auto_radius_m')) + 200
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
;
$function$
;

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
  IF EXISTS(SELECT 1 FROM public.orders WHERE driver_id=auth.uid()
    AND status='delivering' AND private.is_recipient_hold(delivery_hold)
    AND (delivery_hold->>'until')::timestamptz<=clock_timestamp()) THEN
    RAISE EXCEPTION 'HOLD_REDELIVERY_DUE'; END IF;
  IF v_driver_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('driver-assignment:' || v_driver_user_id::text,0));
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
      AND (NOT private.is_recipient_hold(active_order.delivery_hold)
        OR (active_order.delivery_hold->>'until')::timestamptz<=clock_timestamp()
        OR active_order.delivery_hold->>'return_report_id' IS NOT NULL)
      AND active_order.status IN (
        'assigned'::public.order_status,
        'picking_up'::public.order_status,
        'delivering'::public.order_status,
        'return_approved'::public.order_status,
        'returning'::public.order_status
      )
  ) THEN RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER'; END IF;

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
  -- A negative fee balance also blocks zero-COD orders.
  IF v_required_balance >= 0 THEN
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
$function$
;

CREATE OR REPLACE FUNCTION private.record_driver_monitoring_position_single(p_order_id uuid, p_lat double precision, p_lng double precision, p_accuracy double precision, p_captured_at timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_state jsonb;
  v_now timestamptz;
  v_previous timestamptz;
  v_candidate timestamptz;
  v_distance double precision;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id FOR UPDATE;
  IF NOT FOUND OR v_order.driver_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED' USING ERRCODE='42501';
  END IF;
  IF v_order.status NOT IN ('assigned','picking_up','delivering','return_approved','returning') THEN
    RETURN jsonb_build_object('accepted',false);
  END IF;
  v_now := clock_timestamp();
  IF p_lat IS NULL OR p_lng IS NULL OR p_accuracy IS NULL OR p_captured_at IS NULL
    OR NOT (p_lat BETWEEN -90 AND 90 AND p_lng BETWEEN -180 AND 180)
    OR NOT (p_accuracy BETWEEN 0 AND 50)
    OR p_captured_at < v_now-interval '90 seconds'
    OR p_captured_at > v_now+interval '15 seconds' THEN
    RETURN jsonb_build_object('accepted',false,'reason','invalid_or_stale_sample','server_now',v_now);
  END IF;
  v_state := v_order.driver_monitoring;
  IF v_state IS NULL THEN RETURN jsonb_build_object('accepted',false,'reason','monitoring_not_initialized'); END IF;
  v_previous := (v_state->>'last_captured_at')::timestamptz;
  IF v_previous IS NOT NULL AND p_captured_at <= v_previous THEN
    RETURN jsonb_build_object('accepted',false,'reason','duplicate_or_out_of_order');
  END IF;
  -- KhĂ´ng cĂ´ng nháº­n má»™t bÆ°á»›c nháº£y vá»‹ trĂ­ phi thá»±c táº¿ lĂ  GPS cĂ²n hoáº¡t Ä‘á»™ng.
  IF v_previous IS NOT NULL AND v_state->>'last_lat' IS NOT NULL
    AND private.monitoring_distance_m((v_state->>'last_lat')::double precision,
      (v_state->>'last_lng')::double precision,p_lat,p_lng)
      > 35*extract(epoch FROM p_captured_at-v_previous)+100 THEN
    RETURN jsonb_build_object('accepted',false,'reason','implausible_jump');
  END IF;
  v_state := (v_state - ARRAY['gps_reminded_at','gps_warned_at','gps_escalated_gap_at'])
    || jsonb_build_object('last_received_at',v_now,'last_captured_at',p_captured_at,
      'last_lat',p_lat,'last_lng',p_lng,'last_accuracy',p_accuracy);
  IF v_state->>'anchor_lat' IS NULL THEN
    v_state := v_state || jsonb_build_object('anchor_lat',p_lat,'anchor_lng',p_lng);
  END IF;
  IF private.monitoring_distance_m(p_lat,p_lng,v_order.pickup_lat,v_order.pickup_lng)+p_accuracy <=100 THEN
    v_state := v_state || jsonb_build_object('at_pickup_at',coalesce(
      (v_state->>'at_pickup_at')::timestamptz,v_now));
  END IF;
  IF v_state->>'departed_at' IS NULL THEN
    v_distance := private.monitoring_distance_m((v_state->>'anchor_lat')::double precision,
      (v_state->>'anchor_lng')::double precision,p_lat,p_lng);
    IF v_distance-p_accuracy >=100 THEN
      v_candidate := (v_state->>'departure_candidate_at')::timestamptz;
      IF v_candidate IS NULL THEN
        v_state := v_state || jsonb_build_object('departure_candidate_at',v_now);
      ELSIF v_now >= v_candidate+interval '10 seconds' THEN
        v_state := v_state || jsonb_build_object('departed_at',v_candidate);
        -- Chá»‰ bá» Ä‘Ăºng 5 phĂºt chuáº©n bá»‹ náº¿u xuáº¥t phĂ¡t sá»›m; khĂ´ng tĂ­nh láº¡i cĂ¡c cháº·ng.
        IF v_order.status IN ('assigned','picking_up') THEN
          UPDATE public.orders SET delivery_eta=private.apply_fixed_eta_departure(
            delivery_eta,v_candidate) WHERE id=p_order_id;
        END IF;
      END IF;
    ELSE v_state := v_state - 'departure_candidate_at'; END IF;
  END IF;
  UPDATE public.orders SET driver_monitoring=v_state WHERE id=p_order_id;
  RETURN jsonb_build_object('accepted',true,'state',v_state,'server_now',v_now);
END;
$function$
;
REVOKE ALL ON FUNCTION private.record_driver_monitoring_position_single(uuid,double precision,double precision,double precision,timestamptz) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.record_driver_monitoring_position(p_order_id uuid,p_lat double precision,p_lng double precision,p_accuracy double precision,p_captured_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb; held record;
BEGIN
 result:=private.record_driver_monitoring_position_single(p_order_id,p_lat,p_lng,p_accuracy,p_captured_at);
 IF result->>'accepted'='true' THEN
   -- One physical fix refreshes monitoring for every parcel still in custody.
   FOR held IN SELECT id FROM public.orders WHERE driver_id=auth.uid() AND id<>p_order_id
     AND status='delivering' AND private.is_recipient_hold(delivery_hold) ORDER BY id
   LOOP
     PERFORM private.record_driver_monitoring_position_single(held.id,p_lat,p_lng,p_accuracy,p_captured_at);
   END LOOP;
 END IF;
 RETURN result;
END; $$;
REVOKE ALL ON FUNCTION public.record_driver_monitoring_position(uuid,double precision,double precision,double precision,timestamptz) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.record_driver_monitoring_position(uuid,double precision,double precision,double precision,timestamptz) TO authenticated;



CREATE OR REPLACE FUNCTION private.guard_recipient_contact_report()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_order public.orders%ROWTYPE; v_arrived timestamptz;
BEGIN
  IF EXISTS(SELECT 1 FROM public.orders o WHERE o.id=NEW.order_id AND o.driver_id=NEW.reported_by
    AND o.delivery_hold->>'return_report_id'=NEW.id::text) THEN RETURN NEW; END IF;
  IF NEW.category <> 'contact_issue' OR NEW.source <> 'manual'
    OR NOT EXISTS (SELECT 1 FROM public.users WHERE id = NEW.reported_by AND role = 'driver') THEN
    RETURN NEW;
  END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = NEW.order_id FOR UPDATE;
  IF v_order.status = 'delivering' THEN
    SELECT created_at INTO v_arrived FROM public.order_status_logs
    WHERE order_id = NEW.order_id AND logged_by = NEW.reported_by
      AND title = 'Tài xế đã đến điểm giao';
    IF v_arrived IS NULL THEN
      RAISE EXCEPTION 'DELIVERY_ARRIVAL_REQUIRED' USING ERRCODE = '23514';
    END IF;
    IF clock_timestamp() < v_arrived + interval '10 minutes' THEN
      RAISE EXCEPTION 'RECIPIENT_WAIT_REQUIRED' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION private.record_recipient_contact_wait()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_arrived timestamptz;
BEGIN
  IF EXISTS(SELECT 1 FROM public.orders o WHERE o.id=NEW.order_id AND o.driver_id=NEW.reported_by
    AND o.delivery_hold->>'return_report_id'=NEW.id::text) THEN RETURN NEW; END IF;
  IF NEW.category = 'contact_issue' AND NEW.source = 'manual' AND NEW.reporter_role_snapshot = 'driver' THEN
    SELECT created_at INTO v_arrived FROM public.order_status_logs
    WHERE order_id = NEW.order_id AND logged_by = NEW.reported_by
      AND title = 'Tài xế đã đến điểm giao';
    IF v_arrived IS NOT NULL THEN
      INSERT INTO public.risk_report_events(risk_report_id, actor_id, event_type, to_status, note, details)
      VALUES(NEW.id,NEW.reported_by,'note_added',NEW.status,
        'Bắt đầu chờ: ' || to_char(v_arrived AT TIME ZONE 'Asia/Ho_Chi_Minh','DD/MM/YYYY HH24:MI:SS')
          || '. Khoảng gọi đến: ' || to_char((v_arrived + interval '10 minutes') AT TIME ZONE 'Asia/Ho_Chi_Minh','DD/MM/YYYY HH24:MI:SS')
          || ' (giờ Việt Nam). CSKH đối chiếu số người nhận và ít nhất 3 cuộc gọi trong khoảng này; ghi kết quả xác minh trước khi duyệt hoàn hàng.',
        jsonb_build_object('verification_type','recipient_wait','delivery_arrived_at',v_arrived,
          'call_window_ends_at',v_arrived + interval '10 minutes',
          'minimum_call_attempts',3,'call_evidence_review_required',true));
    END IF;
  END IF;
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION private.require_recipient_call_evidence()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF EXISTS(SELECT 1 FROM public.orders o WHERE o.id=NEW.order_id AND o.driver_id=NEW.reported_by
    AND o.delivery_hold->>'return_report_id'=NEW.id::text) THEN RETURN NEW; END IF;
  IF NEW.category = 'contact_issue' AND NEW.source = 'manual'
    AND NEW.reporter_role_snapshot = 'driver'
    AND EXISTS (SELECT 1 FROM public.order_status_logs WHERE order_id = NEW.order_id
      AND logged_by = NEW.reported_by AND title = 'Tài xế đã đến điểm giao')
    AND NOT EXISTS (SELECT 1 FROM public.risk_report_evidence
      WHERE risk_report_id = NEW.id AND evidence_type = 'photo'
        AND storage_path IS NOT NULL AND length(trim(storage_path)) > 0) THEN
    RAISE EXCEPTION 'RECIPIENT_CALL_EVIDENCE_REQUIRED' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE FUNCTION public.request_recipient_hold_return(p_order_id uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE o public.orders%ROWTYPE; d public.drivers%ROWTYPE; rid uuid; t timestamptz:=clock_timestamp();
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,0));
 SELECT * INTO o FROM public.orders WHERE id=p_order_id FOR UPDATE;
 IF NOT FOUND OR o.driver_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED' USING ERRCODE='42501'; END IF;
 IF o.delivery_hold->>'return_report_id' IS NOT NULL THEN RETURN (o.delivery_hold->>'return_report_id')::uuid; END IF;
 IF o.status<>'delivering' OR o.delivery_hold IS NULL OR t<(o.delivery_hold->>'until')::timestamptz+interval '5 minutes'
 THEN RAISE EXCEPTION 'HOLD_RETURN_TOO_EARLY'; END IF;
 IF EXISTS(SELECT 1 FROM public.orders WHERE driver_id=auth.uid() AND id<>o.id AND status IN ('assigned','picking_up','delivering','return_approved','returning')
   AND NOT private.is_recipient_hold(delivery_hold)) THEN RAISE EXCEPTION 'HOLD_OTHER_ORDER_ACTIVE'; END IF;
 SELECT * INTO d FROM public.drivers WHERE user_id=auth.uid();
 IF d.location_updated_at IS NULL OR d.location_updated_at<t-interval '60 seconds' OR d.location_updated_at>t+interval '5 seconds'
   OR d.current_lat IS NULL OR d.current_lng IS NULL THEN RAISE EXCEPTION 'DELIVERY_LOCATION_STALE'; END IF;
 IF NOT public.ST_DWithin(public.ST_SetSRID(public.ST_MakePoint(d.current_lng,d.current_lat),4326)::public.geography,
   public.ST_SetSRID(public.ST_MakePoint(o.delivery_lng,o.delivery_lat),4326)::public.geography,100)
 THEN RAISE EXCEPTION 'DELIVERY_OUTSIDE_GEOFENCE'; END IF;
 rid:=gen_random_uuid();
 UPDATE public.orders SET delivery_hold=delivery_hold||jsonb_build_object('return_report_id',rid) WHERE id=o.id;
 PERFORM public.create_participant_risk_report(rid,o.id,'contact_issue',
   '[Yêu cầu hoàn hàng] Đã hết giờ khách hẹn giao lại và chờ thêm 5 phút. Người nhận chưa nhận hàng. Đề nghị CSKH duyệt hoàn.',
   ARRAY[]::text[],d.current_lat,d.current_lng,t,ARRAY[]::uuid[]);
 INSERT INTO public.risk_report_events(risk_report_id,actor_id,event_type,to_status,note,details)
 SELECT rid,auth.uid(),'note_added',status,'Hết thời gian giữ đơn; đã quay lại điểm giao. Phí đợi do hai bên thỏa thuận.',o.delivery_hold
 FROM public.risk_reports WHERE id=rid;
 RETURN rid;
END; $$;
REVOKE ALL ON FUNCTION public.request_recipient_hold_return(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.request_recipient_hold_return(uuid) TO authenticated;



