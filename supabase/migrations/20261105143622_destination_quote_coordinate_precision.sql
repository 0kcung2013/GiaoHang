-- The dispatcher sends coordinates through JSON, which can round float8 values.
-- Use the same 1e-9 degree representation tolerance as valid_pickup_road_quote;
-- this is <0.2 mm, not an expansion of the allowed pickup/route distances.
CREATE OR REPLACE FUNCTION private.driver_destination_quote_matches(
  p_quote jsonb,p_driver public.drivers,p_order public.orders
) RETURNS boolean LANGUAGE plpgsql STABLE SET search_path='' AS $function$
DECLARE
  v_match jsonb := p_quote->'destination_route';
  v_direct float8; v_delivery float8; v_remaining float8;
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
    AND v_direct>300 AND v_delivery>=0 AND v_remaining>=0
    AND v_remaining+100<v_direct
    AND (p_quote->>'distance_meters')::float8+v_delivery+v_remaining <= v_direct+greatest(2000,v_direct*0.25),false);
EXCEPTION WHEN OTHERS THEN RETURN false;
END;
$function$;
REVOKE ALL ON FUNCTION private.driver_destination_quote_matches(jsonb,public.drivers,public.orders)
  FROM PUBLIC,anon,authenticated;
