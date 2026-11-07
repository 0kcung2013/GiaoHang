-- Regression at the dispatcher -> JSON -> database validation boundary.
-- No account/order fixtures or writes: composite rows reproduce float8 roundoff.
BEGIN;
DO $test$
DECLARE
  v_driver public.drivers%ROWTYPE;
  v_order public.orders%ROWTYPE;
  v_quote jsonb;
  v_key text;
  v_changed jsonb;
BEGIN
  v_driver.dispatch_mode := 'destination';
  v_driver.destination_lat := 10.93931141044953;
  v_driver.destination_lng := 106.69411657228386;
  v_driver.destination_expires_at := now()+interval '1 hour';
  v_order.delivery_lat := 10.949411460962872;
  v_order.delivery_lng := 106.68822460350657;
  v_quote := jsonb_build_object('distance_meters',219.5,'destination_route',
    jsonb_build_object('destination_lat',v_driver.destination_lat,
      'destination_lng',v_driver.destination_lng,
      'delivery_lat',v_order.delivery_lat,'delivery_lng',v_order.delivery_lng,
      'expires_at',v_driver.destination_expires_at,
      'direct_meters',15535.6,'delivery_meters',13675.2,'remaining_meters',1381.6));

  -- REST/JSON serialization can retain fewer decimal places than float8.
  -- Test each coordinate independently, then the exact reported combination.
  FOREACH v_key IN ARRAY ARRAY['destination_lat','destination_lng','delivery_lat','delivery_lng'] LOOP
    v_changed := jsonb_set(v_quote,ARRAY['destination_route',v_key],
      to_jsonb(round((v_quote#>>ARRAY['destination_route',v_key])::numeric,12)));
    IF NOT private.driver_destination_quote_matches(v_changed,v_driver,v_order) THEN
      RAISE EXCEPTION 'Coordinate JSON roundoff incorrectly rejects %',v_key;
    END IF;
    -- A real destination/order change still invalidates the old quote.
    v_changed := jsonb_set(v_quote,ARRAY['destination_route',v_key],
      to_jsonb((v_quote#>>ARRAY['destination_route',v_key])::numeric+0.00001));
    IF private.driver_destination_quote_matches(v_changed,v_driver,v_order) THEN
      RAISE EXCEPTION 'Changed coordinate incorrectly accepted: %',v_key;
    END IF;
  END LOOP;
  v_changed := v_quote||jsonb_build_object('destination_route',(v_quote->'destination_route')||
    jsonb_build_object('destination_lat',10.9393114104495,'destination_lng',106.694116572284,
      'delivery_lat',10.9494114609629,'delivery_lng',106.688224603507));
  IF NOT private.driver_destination_quote_matches(v_changed,v_driver,v_order) THEN
    RAISE EXCEPTION 'Reported same-direction route lost at JSON validation';
  END IF;
  v_changed := jsonb_set(v_quote,'{destination_route,expires_at}',to_jsonb(now()+interval '2 hours'));
  IF private.driver_destination_quote_matches(v_changed,v_driver,v_order) THEN
    RAISE EXCEPTION 'Changed destination session expiry accepted';
  END IF;
  v_changed := jsonb_set(v_quote,'{destination_route,destination_lat}','"NaN"');
  IF private.driver_destination_quote_matches(v_changed,v_driver,v_order) THEN
    RAISE EXCEPTION 'Nonfinite coordinate accepted';
  END IF;
END;
$test$;
ROLLBACK;
