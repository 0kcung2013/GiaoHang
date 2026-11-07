BEGIN;
DO $test$
DECLARE v_driver public.drivers%ROWTYPE; v_order public.orders%ROWTYPE;
  v_quote jsonb; v_distance float8; v_cap integer;
BEGIN
  v_driver.dispatch_mode := 'destination';
  v_driver.destination_lat := 11.12345678901234; v_driver.destination_lng := 106.12345678901234;
  v_driver.destination_expires_at := now()+interval '1 hour';
  v_order.pickup_lat := 11; v_order.pickup_lng := 106;
  v_order.delivery_lat := 11.1; v_order.delivery_lng := 106.1;
  v_quote := jsonb_build_object('distance_meters',3000,'destination_route',jsonb_build_object(
    'destination_lat',v_driver.destination_lat,'destination_lng',v_driver.destination_lng,
    'delivery_lat',v_order.delivery_lat,'delivery_lng',v_order.delivery_lng,
    'expires_at',v_driver.destination_expires_at,'direct_meters',10000,'delivery_meters',25000,'remaining_meters',9999));
  IF NOT private.driver_destination_quote_matches(v_quote,v_driver,v_order) THEN
    RAISE EXCEPTION 'Any strictly closer delivery must match, even after a long detour'; END IF;
  IF private.driver_destination_quote_matches(jsonb_set(v_quote,'{destination_route,remaining_meters}','10000'),v_driver,v_order)
    OR private.driver_destination_quote_matches(jsonb_set(v_quote,'{destination_route,remaining_meters}','10001'),v_driver,v_order) THEN
    RAISE EXCEPTION 'Equal or farther delivery must not match'; END IF;

  v_driver.dispatch_mode := 'nearby';
  v_quote := jsonb_build_object('delivery_route',jsonb_build_object('distance_meters',4999.9,'quoted_at',now(),
    'origin_lat',v_order.pickup_lat,'origin_lng',v_order.pickup_lng,'pickup_lat',v_order.delivery_lat,'pickup_lng',v_order.delivery_lng));
  FOREACH v_cap IN ARRAY ARRAY[5000,10000] LOOP
    v_driver.nearby_delivery_limit_m := v_cap;
    FOREACH v_distance IN ARRAY ARRAY[4999.9,5000,9999.9,10000,50000]::float8[] LOOP
      IF private.driver_delivery_limit_quote_matches(jsonb_set(v_quote,'{delivery_route,distance_meters}',to_jsonb(v_distance)),v_driver,v_order)
        IS DISTINCT FROM (v_distance<v_cap) THEN RAISE EXCEPTION 'Strict delivery limit failed: % / %',v_distance,v_cap; END IF;
    END LOOP;
  END LOOP;
  v_driver.nearby_delivery_limit_m := 5000;
  IF private.driver_delivery_limit_quote_matches(NULL,v_driver,v_order) THEN RAISE EXCEPTION 'Missing delivery quote accepted'; END IF;
  IF private.driver_delivery_limit_quote_matches(jsonb_set(v_quote,'{delivery_route,quoted_at}',to_jsonb(now()-interval '1 minute')),v_driver,v_order)
    THEN RAISE EXCEPTION 'Stale delivery quote accepted'; END IF;
  IF private.driver_delivery_limit_quote_matches(jsonb_set(v_quote,'{delivery_route,pickup_lat}','11.10001'),v_driver,v_order)
    THEN RAISE EXCEPTION 'Changed delivery coordinates accepted'; END IF;
  v_driver.nearby_delivery_limit_m := NULL;
  IF NOT private.driver_delivery_limit_quote_matches(NULL,v_driver,v_order) THEN RAISE EXCEPTION 'Unlimited delivery requires a quote'; END IF;
  v_driver.nearby_delivery_limit_m := 5000; v_driver.dispatch_mode := 'area';
  IF NOT private.driver_delivery_limit_quote_matches(NULL,v_driver,v_order) THEN RAISE EXCEPTION 'Nearby limit applied to area mode'; END IF;
END; $test$;
ROLLBACK;
