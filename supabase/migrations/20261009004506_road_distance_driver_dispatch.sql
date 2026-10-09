-- Road quotes are transient; orders, driver wallets, notifications and logs are reused.
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

DO $setup$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'road_dispatch_secret') THEN
    PERFORM vault.create_secret(gen_random_uuid()::text || gen_random_uuid()::text,
      'road_dispatch_secret', 'Database to road dispatcher authentication');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'road_dispatch_url') THEN
    PERFORM vault.create_secret('https://erlpzwfbpjogvaulcxni.supabase.co/functions/v1/dispatch-road-orders',
      'road_dispatch_url', 'Road dispatch endpoint');
  END IF;
END;
$setup$;

CREATE OR REPLACE FUNCTION private.request_road_dispatch()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE v_secret text; v_url text;
BEGIN
  IF current_setting('giaohang.road_dispatch_requested', true) = 'yes' THEN RETURN; END IF;
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'road_dispatch_secret';
  SELECT decrypted_secret INTO v_url FROM vault.decrypted_secrets WHERE name = 'road_dispatch_url';
  IF v_secret IS NULL OR v_url IS NULL THEN RAISE EXCEPTION 'ROAD_DISPATCH_NOT_CONFIGURED'; END IF;
  PERFORM net.http_post(url := v_url, body := '{}'::jsonb,
    headers := jsonb_build_object('Content-Type','application/json','x-road-dispatch-secret',v_secret),
    timeout_milliseconds := 30000);
  PERFORM set_config('giaohang.road_dispatch_requested','yes',true);
END;
$fn$;

CREATE OR REPLACE FUNCTION private.road_driver_candidates(p_order_id uuid)
RETURNS TABLE(user_id uuid, current_lat double precision, current_lng double precision)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $fn$
  SELECT d.user_id, d.current_lat, d.current_lng
  FROM public.orders o CROSS JOIN public.drivers d
  WHERE o.id = p_order_id
    AND o.driver_id IS NULL AND o.status IN ('pending','confirmed')
    AND o.assignment_timed_out_at IS NULL AND o.assignment_expires_at > now()
    AND o.payment_status IN ('paid','not_required')
    AND COALESCE(o.note,'') <> 'FREEPICK_DEMO_PERSISTENT'
    AND (o.offered_driver_id IS NULL OR o.offer_expires_at <= now())
    AND d.is_available AND d.approval_status = 'approved'
    AND (d.acceptance_locked_until IS NULL OR d.acceptance_locked_until <= now())
    AND d.current_lat IS NOT NULL AND d.current_lng IS NOT NULL
    AND d.location_updated_at >= now() - interval '3 minutes'
    AND NOT (COALESCE(o.rejected_by,'[]'::jsonb) ? d.user_id::text)
    AND COALESCE((SELECT sum(w.available_delta) FROM public.driver_wallet_transactions w
      WHERE w.driver_id = d.user_id AND w.status = 'completed'),0) >= o.driver_advance_amount
    AND NOT EXISTS (SELECT 1 FROM public.orders a WHERE a.driver_id = d.user_id
      AND a.status IN ('assigned','picking_up','delivering','return_approved','returning'))
    AND NOT EXISTS (SELECT 1 FROM public.orders a WHERE a.id <> o.id
      AND a.offered_driver_id = d.user_id AND a.driver_id IS NULL
      AND a.assignment_timed_out_at IS NULL AND a.status IN ('pending','confirmed')
      AND a.offer_expires_at > now())
    -- Geographic distance only limits API work. Include a 200 m snapping margin.
    AND public.ST_DWithin(public.ST_SetSRID(public.ST_MakePoint(d.current_lng,d.current_lat),4326)::public.geography,
      public.ST_SetSRID(public.ST_MakePoint(o.pickup_lng,o.pickup_lat),4326)::public.geography,2200)
  ORDER BY d.user_id;
$fn$;

CREATE OR REPLACE FUNCTION public.road_dispatch_work(p_secret text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE v_secret text; v_work jsonb;
BEGIN
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'road_dispatch_secret';
  IF p_secret IS NULL OR v_secret IS NULL OR p_secret <> v_secret THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object('id',w.id,'pickup_lat',w.pickup_lat,
    'pickup_lng',w.pickup_lng) ORDER BY w.created_at,w.id),'[]'::jsonb) INTO v_work
  FROM (SELECT o.id,o.pickup_lat,o.pickup_lng,o.created_at FROM public.orders o
    WHERE o.driver_id IS NULL AND o.status IN ('pending','confirmed')
      AND o.assignment_timed_out_at IS NULL AND o.assignment_expires_at > now()
      AND o.payment_status IN ('paid','not_required')
      AND COALESCE(o.note,'') <> 'FREEPICK_DEMO_PERSISTENT'
      AND o.offered_driver_id IS NULL
    ORDER BY o.created_at,o.id LIMIT 20) w;
  RETURN v_work;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.road_dispatch_candidates(p_order_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $fn$
  SELECT COALESCE(jsonb_agg(to_jsonb(c)),'[]'::jsonb) FROM private.road_driver_candidates(p_order_id) c;
$fn$;

CREATE OR REPLACE FUNCTION private.valid_pickup_road_quote(
  p_quote jsonb, p_driver public.drivers, p_order public.orders, p_min double precision, p_max double precision)
RETURNS boolean LANGUAGE plpgsql STABLE SET search_path = '' AS $fn$
DECLARE v_distance double precision; v_quoted_at timestamptz;
BEGIN
  IF p_quote IS NULL OR jsonb_typeof(p_quote) <> 'object' THEN RETURN false; END IF;
  v_distance := (p_quote->>'distance_meters')::double precision;
  v_quoted_at := (p_quote->>'quoted_at')::timestamptz;
  RETURN COALESCE(
    v_distance >= p_min AND v_distance <= p_max
    AND (p_quote->>'duration_seconds')::double precision >= 0
    AND v_quoted_at BETWEEN now() - interval '30 seconds' AND now() + interval '5 seconds'
    AND (p_quote->>'pickup_lat')::double precision = p_order.pickup_lat
    AND (p_quote->>'pickup_lng')::double precision = p_order.pickup_lng
    AND public.ST_DWithin(
      public.ST_SetSRID(public.ST_MakePoint(p_driver.current_lng,p_driver.current_lat),4326)::public.geography,
      public.ST_SetSRID(public.ST_MakePoint((p_quote->>'origin_lng')::double precision,
        (p_quote->>'origin_lat')::double precision),4326)::public.geography,30),false);
EXCEPTION WHEN OTHERS THEN RETURN false;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.commit_road_driver_offer(p_order_id uuid,p_candidates jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE v_order public.orders%ROWTYPE; v_driver public.drivers%ROWTYPE; v_quote jsonb;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR v_order.offered_driver_id IS NOT NULL OR NOT EXISTS
    (SELECT 1 FROM private.road_driver_candidates(p_order_id)) THEN RETURN NULL; END IF;
  IF jsonb_typeof(p_candidates) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'INVALID_ROAD_QUOTES'; END IF;
  FOR v_quote IN SELECT q FROM jsonb_array_elements(p_candidates) q
    ORDER BY (q->>'distance_meters')::double precision,
      (q->>'duration_seconds')::double precision,q->>'user_id'
  LOOP
    PERFORM pg_advisory_xact_lock(hashtextextended('driver-assignment:' || (v_quote->>'user_id'),0));
    SELECT d.* INTO v_driver FROM public.drivers d
      JOIN private.road_driver_candidates(p_order_id) c ON c.user_id = d.user_id
      WHERE d.user_id = (v_quote->>'user_id')::uuid FOR UPDATE OF d;
    IF NOT FOUND OR v_driver.is_available IS DISTINCT FROM true
      OR v_driver.approval_status <> 'approved'
      OR v_driver.acceptance_locked_until > clock_timestamp()
      OR v_driver.location_updated_at < clock_timestamp() - interval '3 minutes'
      OR NOT private.valid_pickup_road_quote(v_quote,v_driver,v_order,0,2000) THEN CONTINUE; END IF;
    BEGIN
      UPDATE public.orders SET offered_driver_id = v_driver.user_id,
        offer_expires_at = LEAST(clock_timestamp() + interval '45 seconds',assignment_expires_at),
        status_note = NULL WHERE id = p_order_id AND driver_id IS NULL AND offered_driver_id IS NULL
        AND assignment_timed_out_at IS NULL AND assignment_expires_at > clock_timestamp()
        AND status IN ('pending','confirmed');
      IF FOUND THEN
        INSERT INTO public.notifications(user_id,title,body,type,is_read,order_id)
          VALUES(v_driver.user_id,'Đơn giao hàng mới',
            format('Đơn %s đang chờ bạn nhận. Điểm lấy: %s',v_order.tracking_code,v_order.pickup_address),
            'order_update',false,p_order_id);
        INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
          VALUES(p_order_id,v_order.status,'Đã gửi lời mời tài xế',
            format('Lời mời 45 giây; khoảng cách theo tuyến đường OSRM: %s m.',
              round((v_quote->>'distance_meters')::numeric)),NULL);
        RETURN v_driver.user_id;
      END IF;
    EXCEPTION WHEN unique_violation THEN CONTINUE;
    END;
  END LOOP;
  RETURN NULL;
END;
$fn$;

-- Only trusted Edge Functions may submit quotes or inspect dispatch candidates.
REVOKE ALL ON FUNCTION public.road_dispatch_work(text),
  public.road_dispatch_candidates(uuid), public.commit_road_driver_offer(uuid,jsonb)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.road_dispatch_work(text),
  public.road_dispatch_candidates(uuid),public.commit_road_driver_offer(uuid,jsonb) TO service_role;
REVOKE ALL ON FUNCTION private.request_road_dispatch(),private.road_driver_candidates(uuid),
  private.valid_pickup_road_quote(jsonb,public.drivers,public.orders,double precision,double precision)
  FROM PUBLIC,anon,authenticated;

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

  IF offer_order.payment_status IN ('paid','not_required') THEN
    PERFORM private.request_road_dispatch();
  END IF;
  RETURN NULL;
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
      4200
    )
  ORDER BY free_order.created_at ASC, free_order.id ASC
  LIMIT LEAST(GREATEST(p_limit, 1), 50);
END;
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
    driver_profile,free_order,2000.000001,4000) THEN
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
        clock_timestamp() + interval '45 seconds',
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

CREATE OR REPLACE FUNCTION public.accept_driver_order_with_road_quote(
  p_order_id uuid,p_driver_id uuid,p_route_duration_s integer,p_free_pick boolean,
  p_quote_source text,p_existing_only boolean,p_pickup_quote jsonb)
RETURNS TABLE(order_id uuid,customer_id uuid,tracking_code text,estimated_delivery_at timestamptz)
LANGUAGE plpgsql SET search_path = '' AS $fn$
DECLARE v_previous text := current_setting('giaohang.road_pickup_quote',true);
BEGIN
  PERFORM set_config('giaohang.road_pickup_quote',COALESCE(p_pickup_quote::text,''),true);
  RETURN QUERY SELECT * FROM public.accept_driver_order_with_deadline(
    p_order_id,p_driver_id,p_route_duration_s,p_free_pick,p_quote_source,p_existing_only);
  PERFORM set_config('giaohang.road_pickup_quote',COALESCE(v_previous,''),true);
END;
$fn$;
REVOKE ALL ON FUNCTION public.accept_driver_order_with_road_quote(uuid,uuid,integer,boolean,text,boolean,jsonb)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.accept_driver_order_with_road_quote(uuid,uuid,integer,boolean,text,boolean,jsonb)
  TO service_role;
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
        LEAST(GREATEST(radius_meters, 1), 2000) + 200
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
REVOKE ALL ON FUNCTION public.road_lookup_candidates(double precision,double precision,double precision,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.road_lookup_candidates(double precision,double precision,double precision,integer) TO service_role;
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
$function$
;
