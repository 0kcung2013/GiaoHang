-- Keep preferences on the existing driver profile. NULL preserves unlimited
-- delivery distance for all existing nearby drivers.
ALTER TABLE public.drivers ADD COLUMN nearby_delivery_limit_m integer
  CHECK(nearby_delivery_limit_m IN (5000,10000));
GRANT SELECT(nearby_delivery_limit_m) ON public.drivers TO authenticated;
REVOKE INSERT(nearby_delivery_limit_m),UPDATE(nearby_delivery_limit_m) ON public.drivers FROM anon,authenticated;

CREATE FUNCTION private.guard_driver_delivery_limit() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF current_user IN ('anon','authenticated') AND
    ((TG_OP='INSERT' AND NEW.nearby_delivery_limit_m IS NOT NULL) OR
      (TG_OP='UPDATE' AND NEW.nearby_delivery_limit_m IS DISTINCT FROM OLD.nearby_delivery_limit_m)) THEN
    RAISE EXCEPTION 'DISPATCH_PREFERENCES_RPC_REQUIRED';
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER drivers_guard_delivery_limit BEFORE INSERT OR UPDATE ON public.drivers
FOR EACH ROW EXECUTE FUNCTION private.guard_driver_delivery_limit();

-- Required sixth argument distinguishes this overload from the existing
-- five-argument API. Older apps can still save their modes without clearing it.
CREATE FUNCTION public.set_driver_dispatch_preferences(
  p_mode text,p_area_id text,p_destination_lat double precision,
  p_destination_lng double precision,p_destination_label text,p_nearby_delivery_limit_m integer
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'DRIVER_REQUIRED'; END IF;
  IF p_nearby_delivery_limit_m IS NOT NULL AND p_nearby_delivery_limit_m NOT IN(5000,10000) THEN
    RAISE EXCEPTION 'INVALID_DELIVERY_LIMIT';
  END IF;
  -- Reuse owner validation, advisory lock, KYC and the pending-offer guard.
  PERFORM public.set_driver_dispatch_preferences(p_mode,p_area_id,p_destination_lat,p_destination_lng,p_destination_label);
  UPDATE public.drivers SET nearby_delivery_limit_m=p_nearby_delivery_limit_m WHERE user_id=auth.uid();
END; $$;
REVOKE ALL ON FUNCTION public.set_driver_dispatch_preferences(text,text,double precision,double precision,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.set_driver_dispatch_preferences(text,text,double precision,double precision,text,integer) TO authenticated;

CREATE OR REPLACE FUNCTION private.driver_destination_quote_matches(
  p_quote jsonb,p_driver public.drivers,p_order public.orders
) RETURNS boolean LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE v_match jsonb := p_quote->'destination_route'; v_direct float8; v_delivery float8; v_remaining float8;
BEGIN
  IF p_driver.dispatch_mode<>'destination' THEN RETURN true; END IF;
  IF p_driver.destination_expires_at<=now() THEN RETURN false; END IF;
  v_direct := (v_match->>'direct_meters')::float8;
  v_delivery := (v_match->>'delivery_meters')::float8;
  v_remaining := (v_match->>'remaining_meters')::float8;
  RETURN coalesce(
    abs((v_match->>'destination_lat')::float8-p_driver.destination_lat)<=1e-9
    AND abs((v_match->>'destination_lng')::float8-p_driver.destination_lng)<=1e-9
    AND abs((v_match->>'delivery_lat')::float8-p_order.delivery_lat)<=1e-9
    AND abs((v_match->>'delivery_lng')::float8-p_order.delivery_lng)<=1e-9
    AND (v_match->>'expires_at')::timestamptz=p_driver.destination_expires_at
    AND v_direct>300 AND v_direct<'Infinity'::float8
    AND v_delivery>=0 AND v_delivery<'Infinity'::float8
    AND v_remaining>=0 AND v_remaining<v_direct,false);
EXCEPTION WHEN OTHERS THEN RETURN false;
END; $$;

CREATE FUNCTION private.driver_delivery_limit_quote_matches(
  p_quote jsonb,p_driver public.drivers,p_order public.orders
) RETURNS boolean LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE v_route jsonb := p_quote->'delivery_route'; v_distance float8;
BEGIN
  IF p_driver.dispatch_mode<>'nearby' OR p_driver.nearby_delivery_limit_m IS NULL THEN RETURN true; END IF;
  v_distance := (v_route->>'distance_meters')::float8;
  RETURN coalesce(v_distance>=0 AND v_distance<p_driver.nearby_delivery_limit_m
    AND (v_route->>'quoted_at')::timestamptz BETWEEN now()-interval '30 seconds' AND now()+interval '5 seconds'
    AND abs((v_route->>'origin_lat')::float8-p_order.pickup_lat)<=1e-9
    AND abs((v_route->>'origin_lng')::float8-p_order.pickup_lng)<=1e-9
    AND abs((v_route->>'pickup_lat')::float8-p_order.delivery_lat)<=1e-9
    AND abs((v_route->>'pickup_lng')::float8-p_order.delivery_lng)<=1e-9,false);
EXCEPTION WHEN OTHERS THEN RETURN false;
END; $$;
REVOKE ALL ON FUNCTION private.guard_driver_delivery_limit(),
  private.driver_delivery_limit_quote_matches(jsonb,public.drivers,public.orders),
  private.driver_destination_quote_matches(jsonb,public.drivers,public.orders) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.road_dispatch_candidates(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT COALESCE(jsonb_agg(
    to_jsonb(c) || jsonb_build_object('rating', COALESCE(d.rating, 0)::double precision,
      'dispatch_mode',d.dispatch_mode,'nearby_delivery_limit_m',d.nearby_delivery_limit_m,'destination_lat',d.destination_lat,'destination_lng',d.destination_lng,'destination_expires_at',d.destination_expires_at)
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
      OR NOT private.valid_pickup_road_quote(v_quote,v_driver,v_order,0,private.driver_dispatch_pickup_limit(v_driver,v_order)) OR NOT private.driver_destination_quote_matches(v_quote,v_driver,v_order)
      OR NOT private.driver_delivery_limit_quote_matches(v_quote,v_driver,v_order) THEN CONTINUE; END IF;
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
