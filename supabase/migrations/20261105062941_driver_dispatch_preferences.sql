-- Operating areas have their own versioned geographic reference data. Existing
-- tables contain no district boundaries; preferences stay on the driver row.
CREATE TABLE public.driver_operating_areas (
  id text PRIMARY KEY,
  province_code text NOT NULL,
  province_name text NOT NULL,
  name text NOT NULL,
  boundary public.geometry(MultiPolygon,4326) NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  source_version text NOT NULL DEFAULT 'geoBoundaries-VNM-2020-9469f09;provinces-v1-2026-11-05',
  CHECK (public.ST_IsValid(boundary) AND NOT public.ST_IsEmpty(boundary))
);
CREATE INDEX driver_operating_areas_province_idx ON public.driver_operating_areas(province_code) WHERE enabled;
ALTER TABLE public.driver_operating_areas ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.driver_operating_areas FROM anon, authenticated;
GRANT SELECT (id,province_code,province_name,name,enabled,source_version) ON public.driver_operating_areas TO authenticated;
CREATE POLICY operating_areas_read ON public.driver_operating_areas FOR SELECT TO authenticated USING (enabled);
GRANT ALL ON public.driver_operating_areas TO service_role;

ALTER TABLE public.drivers
  ADD COLUMN dispatch_mode text NOT NULL DEFAULT 'nearby',
  ADD COLUMN operating_area_id text REFERENCES public.driver_operating_areas(id),
  ADD COLUMN destination_lat double precision,
  ADD COLUMN destination_lng double precision,
  ADD COLUMN destination_label text,
  ADD COLUMN destination_expires_at timestamptz,
  ADD CONSTRAINT driver_dispatch_preferences_valid CHECK (
    (dispatch_mode='nearby' AND operating_area_id IS NULL AND destination_lat IS NULL AND destination_lng IS NULL AND destination_label IS NULL AND destination_expires_at IS NULL)
    OR (dispatch_mode='area' AND operating_area_id IS NOT NULL AND destination_lat IS NULL AND destination_lng IS NULL AND destination_label IS NULL AND destination_expires_at IS NULL)
    OR (dispatch_mode='destination' AND operating_area_id IS NULL AND destination_lat BETWEEN -90 AND 90 AND destination_lng BETWEEN -180 AND 180
      AND destination_lat IS NOT NULL AND destination_lng IS NOT NULL AND destination_label IS NOT NULL AND length(destination_label) BETWEEN 1 AND 300 AND destination_expires_at IS NOT NULL)
  );
GRANT SELECT(dispatch_mode,operating_area_id,destination_lat,destination_lng,destination_label,destination_expires_at) ON public.drivers TO authenticated;
REVOKE INSERT(dispatch_mode,operating_area_id,destination_lat,destination_lng,destination_label,destination_expires_at),
  UPDATE(dispatch_mode,operating_area_id,destination_lat,destination_lng,destination_label,destination_expires_at) ON public.drivers FROM anon,authenticated;

CREATE FUNCTION private.guard_driver_dispatch_preferences() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF current_user IN ('anon','authenticated') AND
    ((TG_OP='INSERT' AND NEW.dispatch_mode<>'nearby') OR
     (TG_OP='UPDATE' AND ROW(NEW.dispatch_mode,NEW.operating_area_id,NEW.destination_lat,NEW.destination_lng,NEW.destination_label,NEW.destination_expires_at)
       IS DISTINCT FROM ROW(OLD.dispatch_mode,OLD.operating_area_id,OLD.destination_lat,OLD.destination_lng,OLD.destination_label,OLD.destination_expires_at))) THEN
    RAISE EXCEPTION 'DISPATCH_PREFERENCES_RPC_REQUIRED';
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER drivers_guard_dispatch_preferences BEFORE INSERT OR UPDATE ON public.drivers
  FOR EACH ROW EXECUTE FUNCTION private.guard_driver_dispatch_preferences();

CREATE FUNCTION public.set_driver_dispatch_preferences(p_mode text,p_area_id text DEFAULT NULL,
  p_destination_lat double precision DEFAULT NULL,p_destination_lng double precision DEFAULT NULL,p_destination_label text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_user uuid := auth.uid();
BEGIN
  IF v_user IS NULL OR NOT EXISTS(SELECT 1 FROM public.drivers WHERE user_id=v_user AND approval_status='approved') THEN
    RAISE EXCEPTION 'DRIVER_REQUIRED';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('driver-assignment:'||v_user::text,0));
  IF EXISTS(SELECT 1 FROM public.orders WHERE offered_driver_id=v_user AND driver_id IS NULL
    AND status IN ('pending','confirmed') AND offer_expires_at>clock_timestamp() AND assignment_timed_out_at IS NULL) THEN
    RAISE EXCEPTION 'DISPATCH_OFFER_PENDING';
  END IF;
  IF p_mode NOT IN ('nearby','area','destination') OR p_mode IS NULL THEN RAISE EXCEPTION 'INVALID_DISPATCH_MODE'; END IF;
  IF p_mode='area' AND NOT EXISTS(SELECT 1 FROM public.driver_operating_areas WHERE id=p_area_id AND enabled) THEN
    RAISE EXCEPTION 'OPERATING_AREA_UNAVAILABLE';
  END IF;
  IF p_mode='destination' AND (p_destination_lat IS NULL OR p_destination_lng IS NULL
    OR NOT (p_destination_lat BETWEEN -90 AND 90 AND p_destination_lng BETWEEN -180 AND 180)
    OR nullif(btrim(p_destination_label),'') IS NULL OR length(p_destination_label)>300) THEN
    RAISE EXCEPTION 'INVALID_DESTINATION';
  END IF;
  UPDATE public.drivers SET dispatch_mode=p_mode,
    operating_area_id=CASE WHEN p_mode='area' THEN p_area_id END,
    destination_lat=CASE WHEN p_mode='destination' THEN p_destination_lat END,
    destination_lng=CASE WHEN p_mode='destination' THEN p_destination_lng END,
    destination_label=CASE WHEN p_mode='destination' THEN btrim(p_destination_label) END,
    destination_expires_at=CASE WHEN p_mode='destination' THEN clock_timestamp()+interval '8 hours' END
    WHERE user_id=v_user;
END; $$;

CREATE FUNCTION private.driver_area_matches(p_driver public.drivers,p_order public.orders)
RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
  SELECT CASE WHEN p_driver.dispatch_mode<>'area' THEN true ELSE EXISTS(
    SELECT 1 FROM public.driver_operating_areas a WHERE a.id=p_driver.operating_area_id AND a.enabled
      AND public.ST_Covers(a.boundary,public.ST_SetSRID(public.ST_MakePoint(p_order.pickup_lng,p_order.pickup_lat),4326))
      AND public.ST_Covers(a.boundary,public.ST_SetSRID(public.ST_MakePoint(p_order.delivery_lng,p_order.delivery_lat),4326))
  ) END;
$$;

-- A destination driver can reach pickups up to 3km away; other modes retain the
-- order's existing automatic radius. No change to FreePick's query or acceptance.
CREATE FUNCTION private.driver_dispatch_pickup_limit(p_driver public.drivers,p_order public.orders)
RETURNS double precision LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT CASE WHEN p_driver.dispatch_mode='destination' THEN 3000
   ELSE private.business_number(p_order.business_policy,'auto_radius_m')::double precision END;
$$;

CREATE FUNCTION private.driver_destination_quote_matches(p_quote jsonb,p_driver public.drivers,p_order public.orders)
RETURNS boolean LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE v_match jsonb := p_quote->'destination_route'; v_direct float8; v_delivery float8; v_remaining float8;
BEGIN
  IF p_driver.dispatch_mode<>'destination' THEN RETURN true; END IF;
  IF p_driver.destination_expires_at<=now() THEN RETURN false; END IF;
  v_direct := (v_match->>'direct_meters')::float8;
  v_delivery := (v_match->>'delivery_meters')::float8;
  v_remaining := (v_match->>'remaining_meters')::float8;
  RETURN coalesce(
    (v_match->>'destination_lat')::float8=p_driver.destination_lat
    AND (v_match->>'destination_lng')::float8=p_driver.destination_lng
    AND (v_match->>'delivery_lat')::float8=p_order.delivery_lat
    AND (v_match->>'delivery_lng')::float8=p_order.delivery_lng
    AND (v_match->>'expires_at')::timestamptz=p_driver.destination_expires_at
    AND v_direct>300 AND v_delivery>=0 AND v_remaining>=0
    AND v_remaining+100<v_direct
    AND (p_quote->>'distance_meters')::float8+v_delivery+v_remaining <= v_direct+greatest(2000,v_direct*0.25),false);
EXCEPTION WHEN OTHERS THEN RETURN false;
END; $$;

REVOKE ALL ON FUNCTION private.guard_driver_dispatch_preferences(),private.driver_area_matches(public.drivers,public.orders),
 private.driver_dispatch_pickup_limit(public.drivers,public.orders),private.driver_destination_quote_matches(jsonb,public.drivers,public.orders)
 FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.set_driver_dispatch_preferences(text,text,double precision,double precision,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.set_driver_dispatch_preferences(text,text,double precision,double precision,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.road_dispatch_work(p_secret text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_secret text; v_work jsonb;
BEGIN
 SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name='road_dispatch_secret';
 IF p_secret IS NULL OR v_secret IS NULL OR p_secret<>v_secret THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(w) ORDER BY w.created_at,w.id),'[]'::jsonb) INTO v_work
 FROM (SELECT o.id,o.pickup_lat,o.pickup_lng,o.delivery_lat,o.delivery_lng,o.created_at,o.business_policy
   FROM public.orders o WHERE o.driver_id IS NULL AND o.status IN ('pending','confirmed')
   AND o.assignment_timed_out_at IS NULL AND o.assignment_expires_at>now()
   AND o.payment_status IN ('paid','not_required') AND coalesce(o.note,'')<>'FREEPICK_DEMO_PERSISTENT'
   AND o.offered_driver_id IS NULL ORDER BY o.created_at,o.id LIMIT 20) w;
 RETURN v_work;
END; $$;
CREATE OR REPLACE FUNCTION private.road_driver_candidates(p_order_id uuid)
 RETURNS TABLE(user_id uuid, current_lat double precision, current_lng double precision)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT d.user_id, d.current_lat, d.current_lng
  FROM public.orders o CROSS JOIN public.drivers d
  WHERE o.id = p_order_id
    AND o.driver_id IS NULL AND o.status IN ('pending','confirmed')
    AND o.assignment_timed_out_at IS NULL AND o.assignment_expires_at > now()
    AND o.payment_status IN ('paid','not_required')
    AND COALESCE(o.note,'') <> 'FREEPICK_DEMO_PERSISTENT'
    AND (o.offered_driver_id IS NULL OR o.offer_expires_at <= now())
    AND EXISTS(SELECT 1 FROM auth.users a WHERE a.id=d.user_id
      AND (a.banned_until IS NULL OR a.banned_until<=statement_timestamp()))
    AND d.is_available AND d.approval_status = 'approved'
    AND (d.acceptance_locked_until IS NULL OR d.acceptance_locked_until <= now())
    AND private.driver_area_matches(d,o)
    AND (d.dispatch_mode<>'destination' OR (d.destination_expires_at>now() AND NOT public.ST_DWithin(public.ST_SetSRID(public.ST_MakePoint(d.current_lng,d.current_lat),4326)::public.geography,public.ST_SetSRID(public.ST_MakePoint(d.destination_lng,d.destination_lat),4326)::public.geography,300)))
    AND d.current_lat IS NOT NULL AND d.current_lng IS NOT NULL
    AND d.location_updated_at >= now() - interval '3 minutes'
    AND NOT (COALESCE(o.rejected_by,'[]'::jsonb) ? d.user_id::text)
    AND COALESCE((SELECT sum(w.available_delta) FROM public.driver_wallet_transactions w
      WHERE w.driver_id = d.user_id AND w.status = 'completed'),0) >= o.driver_advance_amount
    AND NOT EXISTS (SELECT 1 FROM public.orders a WHERE a.driver_id = d.user_id
      AND a.status IN ('assigned','picking_up','delivering','return_approved','returning')
      AND (NOT private.is_recipient_hold(a.delivery_hold)
        OR coalesce((a.delivery_hold->>'until')::timestamptz <= clock_timestamp(),true)
        OR a.delivery_hold->>'return_report_id' IS NOT NULL))
    AND NOT EXISTS (SELECT 1 FROM public.orders a WHERE a.id <> o.id
      AND a.offered_driver_id = d.user_id AND a.driver_id IS NULL
      AND a.assignment_timed_out_at IS NULL AND a.status IN ('pending','confirmed')
      AND a.offer_expires_at > now())
    -- Geographic distance only limits API work. Include a 200 m snapping margin.
    AND public.ST_DWithin(public.ST_SetSRID(public.ST_MakePoint(d.current_lng,d.current_lat),4326)::public.geography,
      public.ST_SetSRID(public.ST_MakePoint(o.pickup_lng,o.pickup_lat),4326)::public.geography,private.driver_dispatch_pickup_limit(d,o)+200)
  ORDER BY d.user_id;
$function$

;
CREATE OR REPLACE FUNCTION public.road_dispatch_candidates(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT COALESCE(jsonb_agg(
    to_jsonb(c) || jsonb_build_object('rating', COALESCE(d.rating, 0)::double precision,
      'dispatch_mode',d.dispatch_mode,'destination_lat',d.destination_lat,'destination_lng',d.destination_lng,'destination_expires_at',d.destination_expires_at)
    ORDER BY c.user_id
  ), '[]'::jsonb)
  FROM private.road_driver_candidates(p_order_id) c
  JOIN public.drivers d ON d.user_id = c.user_id;
$function$

;
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
    ORDER BY (ranked_driver.dispatch_mode='destination') DESC, (q->>'distance_meters')::double precision ASC,
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
      OR NOT private.valid_pickup_road_quote(v_quote,v_driver,v_order,0,private.driver_dispatch_pickup_limit(v_driver,v_order)) OR NOT private.driver_destination_quote_matches(v_quote,v_driver,v_order) THEN CONTINUE; END IF;
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
$function$

;
