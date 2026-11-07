-- Approved by the user on 2026-11-03: rating breaks exact road-distance ties.
-- Reuse existing ratings; no new table, field, RLS policy or storage pipeline.

CREATE OR REPLACE FUNCTION public.road_dispatch_candidates(p_order_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $function$
  SELECT COALESCE(jsonb_agg(
    to_jsonb(c) || jsonb_build_object('rating', COALESCE(d.rating, 0)::double precision)
    ORDER BY c.user_id
  ), '[]'::jsonb)
  FROM private.road_driver_candidates(p_order_id) c
  JOIN public.drivers d ON d.user_id = c.user_id;
$function$;

CREATE OR REPLACE FUNCTION public.commit_road_driver_offer(p_order_id uuid, p_candidates jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_order public.orders%ROWTYPE; v_driver public.drivers%ROWTYPE; v_quote jsonb;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR v_order.offered_driver_id IS NOT NULL OR NOT EXISTS
    (SELECT 1 FROM private.road_driver_candidates(p_order_id)) THEN RETURN NULL; END IF;
  IF jsonb_typeof(p_candidates) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'INVALID_ROAD_QUOTES'; END IF;
  -- Rating comes from the driver profile, never from submitted quote JSON.
  FOR v_quote IN
    SELECT q FROM jsonb_array_elements(p_candidates) q
    JOIN public.drivers AS ranked_driver
      ON ranked_driver.user_id = (q->>'user_id')::uuid
    ORDER BY (q->>'distance_meters')::double precision ASC,
      COALESCE(ranked_driver.rating, 0) DESC,
      (q->>'duration_seconds')::double precision ASC, q->>'user_id' ASC
  LOOP
    PERFORM pg_advisory_xact_lock(hashtextextended('driver-assignment:' || (v_quote->>'user_id'),0));
    IF NOT private.driver_account_access_gate((v_quote->>'user_id')::uuid) THEN CONTINUE; END IF;
    SELECT d.* INTO v_driver FROM public.drivers d
      JOIN private.road_driver_candidates(p_order_id) c ON c.user_id = d.user_id
      WHERE d.user_id = (v_quote->>'user_id')::uuid FOR UPDATE OF d;
    IF NOT FOUND OR v_driver.is_available IS DISTINCT FROM true
      OR v_driver.approval_status <> 'approved'
      OR v_driver.acceptance_locked_until > clock_timestamp()
      OR v_driver.location_updated_at < clock_timestamp() - interval '3 minutes'
      OR NOT private.valid_pickup_road_quote(v_quote,v_driver,v_order,0,private.business_number(v_order.business_policy,'auto_radius_m')::double precision) THEN CONTINUE; END IF;
    BEGIN
      UPDATE public.orders SET offered_driver_id = v_driver.user_id,
        offer_expires_at = LEAST(clock_timestamp() + make_interval(secs=>private.business_number(v_order.business_policy,'offer_seconds')::double precision),assignment_expires_at),
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
            format('Lời mời %s giây; khoảng cách theo tuyến đường OSRM: %s m.',
              private.business_number(v_order.business_policy,'offer_seconds'),
              round((v_quote->>'distance_meters')::numeric)),NULL);
        RETURN v_driver.user_id;
      END IF;
    EXCEPTION WHEN unique_violation THEN CONTINUE;
    END;
  END LOOP;
  RETURN NULL;
END;
$function$;

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
  ORDER BY candidate.distance_meters ASC, candidate.rating DESC, candidate.user_id ASC
;
$function$
;

REVOKE ALL ON FUNCTION public.road_dispatch_candidates(uuid),
  public.commit_road_driver_offer(uuid,jsonb),
  public.road_lookup_candidates(double precision,double precision,double precision,integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.road_dispatch_candidates(uuid),
  public.commit_road_driver_offer(uuid,jsonb),
  public.road_lookup_candidates(double precision,double precision,double precision,integer)
  TO service_role;
