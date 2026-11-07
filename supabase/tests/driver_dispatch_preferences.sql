-- Run after the dispatch-preferences migration and catalog import.
-- Uses two idle driver fixtures; every change and notification rolls back.
BEGIN;
SET LOCAL statement_timeout='20s';
SELECT set_config('giaohang.road_dispatch_requested','yes',true);
DO $test$
DECLARE
  v_users uuid[]; v_customer uuid; v_order_id uuid := gen_random_uuid();
  v_order public.orders; v_driver public.drivers; v_quote jsonb; v_near jsonb;
  v_selected uuid; v_failed boolean;
BEGIN
  IF has_function_privilege('anon','public.set_driver_dispatch_preferences(text,text,double precision,double precision,text)','EXECUTE')
    OR has_function_privilege('authenticated','public.commit_road_driver_offer(uuid,jsonb)','EXECUTE')
    OR has_column_privilege('authenticated','public.driver_operating_areas','boundary','SELECT') THEN
    RAISE EXCEPTION 'Unexpected public permissions'; END IF;

  SELECT array_agg(user_id ORDER BY user_id) INTO v_users FROM (
    SELECT d.user_id FROM public.drivers d JOIN auth.users a ON a.id=d.user_id
    WHERE (a.banned_until IS NULL OR a.banned_until<=now())
      AND NOT EXISTS(SELECT 1 FROM public.orders o WHERE o.driver_id=d.user_id
        AND o.status IN ('assigned','picking_up','delivering','return_approved','returning'))
      AND NOT EXISTS(SELECT 1 FROM public.orders o WHERE o.offered_driver_id=d.user_id
        AND o.driver_id IS NULL AND o.status IN ('pending','confirmed') AND o.assignment_timed_out_at IS NULL)
    ORDER BY d.user_id LIMIT 2
  ) idle;
  IF cardinality(v_users) IS DISTINCT FROM 2 THEN RAISE EXCEPTION 'Two idle driver fixtures required'; END IF;
  SELECT id INTO v_customer FROM public.users WHERE role='customer' LIMIT 1;
  UPDATE public.drivers SET is_available=true, approval_status='approved', acceptance_locked_until=NULL,
    current_lat=10.781,current_lng=106.7,location_updated_at=clock_timestamp(),
    dispatch_mode='nearby',operating_area_id=NULL,destination_lat=NULL,destination_lng=NULL,destination_label=NULL,destination_expires_at=NULL,nearby_delivery_limit_m=NULL
    WHERE user_id=ANY(v_users);
  INSERT INTO public.driver_operating_areas(id,province_code,province_name,name,boundary)
    VALUES('dispatch-test','test','Test','Test',public.ST_Multi(public.ST_GeomFromText('POLYGON((106.6 10.7,106.8 10.7,106.8 10.9,106.6 10.9,106.6 10.7))',4326)));
  INSERT INTO public.orders(id,customer_id,status,pickup_address,pickup_lat,pickup_lng,
    delivery_address,delivery_lat,delivery_lng,tracking_code)
    VALUES(v_order_id,v_customer,'pending','Dispatch test',10.78,106.7,'Dispatch test',10.79,106.71,'DISPATCH-TEST-'||v_order_id::text);
  SELECT * INTO v_order FROM public.orders WHERE id=v_order_id;

  PERFORM set_config('request.jwt.claim.sub',v_users[1]::text,true);
  PERFORM public.set_driver_dispatch_preferences('nearby',NULL,NULL,NULL,NULL,5000);
  IF (SELECT nearby_delivery_limit_m FROM public.drivers WHERE user_id=v_users[1])<>5000 THEN
    RAISE EXCEPTION 'Delivery limit not saved'; END IF;
  v_failed := false;
  BEGIN PERFORM public.set_driver_dispatch_preferences('nearby',NULL,NULL,NULL,NULL,3000);
  EXCEPTION WHEN OTHERS THEN IF SQLERRM='INVALID_DELIVERY_LIMIT' THEN v_failed:=true; ELSE RAISE; END IF; END;
  IF NOT v_failed THEN RAISE EXCEPTION 'Unsupported delivery limit accepted'; END IF;
  PERFORM public.set_driver_dispatch_preferences('area','dispatch-test');
  SELECT * INTO v_driver FROM public.drivers WHERE user_id=v_users[1];
  IF v_driver.nearby_delivery_limit_m<>5000 THEN RAISE EXCEPTION 'Legacy API cleared nearby delivery preference'; END IF;
  IF NOT private.driver_area_matches(v_driver,v_order) THEN RAISE EXCEPTION 'Both endpoints inside must match'; END IF;
  v_order.delivery_lat := 11;
  IF private.driver_area_matches(v_driver,v_order) THEN RAISE EXCEPTION 'Delivery outside area must not match'; END IF;
  v_order.delivery_lat := 10.79; v_order.pickup_lat := 11;
  IF private.driver_area_matches(v_driver,v_order) THEN RAISE EXCEPTION 'Pickup outside area must not match'; END IF;
  v_order.pickup_lat := 10.78;
  UPDATE public.driver_operating_areas SET enabled=false WHERE id='dispatch-test';
  IF private.driver_area_matches(v_driver,v_order) THEN RAISE EXCEPTION 'Disabled area must not match'; END IF;
  UPDATE public.driver_operating_areas SET enabled=true WHERE id='dispatch-test';

  v_failed := false;
  BEGIN PERFORM public.set_driver_dispatch_preferences('area','missing');
  EXCEPTION WHEN OTHERS THEN IF SQLERRM='OPERATING_AREA_UNAVAILABLE' THEN v_failed:=true; ELSE RAISE; END IF; END;
  IF NOT v_failed THEN RAISE EXCEPTION 'Missing area was accepted'; END IF;
  PERFORM set_config('request.jwt.claim.sub',v_customer::text,true);
  v_failed := false;
  BEGIN PERFORM public.set_driver_dispatch_preferences('nearby');
  EXCEPTION WHEN OTHERS THEN IF SQLERRM='DRIVER_REQUIRED' THEN v_failed:=true; ELSE RAISE; END IF; END;
  IF NOT v_failed THEN RAISE EXCEPTION 'Customer changed dispatch preferences'; END IF;
  PERFORM set_config('request.jwt.claim.sub',v_users[1]::text,true);
  PERFORM public.set_driver_dispatch_preferences('destination',NULL,11.08,106.6,'Home');
  SELECT * INTO v_driver FROM public.drivers WHERE user_id=v_users[1];
  IF v_driver.destination_expires_at NOT BETWEEN now()+interval '7 hours 59 minutes' AND now()+interval '8 hours 1 minute'
    THEN RAISE EXCEPTION 'Destination expiry must use server time'; END IF;
  IF (SELECT dispatch_mode FROM public.drivers WHERE user_id=v_users[2])<>'nearby'
    THEN RAISE EXCEPTION 'RPC modified another driver'; END IF;

  v_quote := jsonb_build_object('user_id',v_users[1],'origin_lat',10.781,'origin_lng',106.7,
    'pickup_lat',10.78,'pickup_lng',106.7,'distance_meters',2800,'duration_seconds',300,'quoted_at',clock_timestamp(),
    'destination_route',jsonb_build_object('destination_lat',11.08,'destination_lng',106.6,
      'delivery_lat',v_order.delivery_lat,'delivery_lng',v_order.delivery_lng,'expires_at',v_driver.destination_expires_at,
      'direct_meters',10000,'delivery_meters',3000,'remaining_meters',5000));
  v_near := (v_quote-'destination_route')||jsonb_build_object('user_id',v_users[2],'distance_meters',400);
  IF NOT private.driver_destination_quote_matches(v_quote,v_driver,v_order) THEN RAISE EXCEPTION 'Valid direction rejected'; END IF;
  IF private.driver_destination_quote_matches(v_near,v_driver,v_order) THEN RAISE EXCEPTION 'Missing direction evidence accepted'; END IF;
  IF private.driver_destination_quote_matches(jsonb_set(v_quote,'{destination_route,destination_lat}','11.2'),v_driver,v_order)
    THEN RAISE EXCEPTION 'Stale destination quote accepted'; END IF;
  IF private.driver_destination_quote_matches(jsonb_set(v_quote,'{destination_route,remaining_meters}','11000'),v_driver,v_order)
    THEN RAISE EXCEPTION 'Reverse direction accepted'; END IF;
  v_driver.destination_expires_at := now()-interval '1 minute';
  IF private.driver_destination_quote_matches(v_quote,v_driver,v_order) THEN RAISE EXCEPTION 'Expired destination accepted'; END IF;

  v_selected := public.commit_road_driver_offer(v_order_id,jsonb_build_array(v_near,v_quote));
  IF v_selected IS DISTINCT FROM v_users[1] THEN RAISE EXCEPTION 'Destination driver must win over nearer driver'; END IF;
  v_failed := false;
  BEGIN PERFORM public.set_driver_dispatch_preferences('nearby');
  EXCEPTION WHEN OTHERS THEN IF SQLERRM='DISPATCH_OFFER_PENDING' THEN v_failed:=true; ELSE RAISE; END IF; END;
  IF NOT v_failed THEN RAISE EXCEPTION 'Mode changed during pending offer'; END IF;

  UPDATE public.orders SET offered_driver_id=NULL,offer_expires_at=NULL WHERE id=v_order_id;
  v_quote := v_quote||jsonb_build_object('distance_meters',3001,'quoted_at',clock_timestamp());
  v_near := v_near||jsonb_build_object('quoted_at',clock_timestamp());
  v_selected := public.commit_road_driver_offer(v_order_id,jsonb_build_array(v_quote,v_near));
  IF v_selected IS DISTINCT FROM v_users[2] THEN RAISE EXCEPTION 'Destination driver beyond 3km must lose'; END IF;
  UPDATE public.orders SET offered_driver_id=NULL,offer_expires_at=NULL WHERE id=v_order_id;
  UPDATE public.orders SET rejected_by=jsonb_build_array(v_users[1]::text) WHERE id=v_order_id;
  v_quote := v_quote||jsonb_build_object('distance_meters',2800,'quoted_at',clock_timestamp());
  v_selected := public.commit_road_driver_offer(v_order_id,jsonb_build_array(v_quote,v_near));
  IF v_selected IS DISTINCT FROM v_users[2] THEN RAISE EXCEPTION 'Rejected destination driver was offered again'; END IF;

  -- Revalidate delivery caps at the real commit boundary, not just in Edge JS.
  UPDATE public.orders SET offered_driver_id=NULL,offer_expires_at=NULL,rejected_by='[]'::jsonb WHERE id=v_order_id;
  PERFORM public.set_driver_dispatch_preferences('nearby',NULL,NULL,NULL,NULL,5000);
  PERFORM set_config('request.jwt.claim.sub',v_users[2]::text,true);
  PERFORM public.set_driver_dispatch_preferences('nearby',NULL,NULL,NULL,NULL,10000);
  v_quote := (v_quote-'destination_route')||jsonb_build_object('distance_meters',100,'quoted_at',clock_timestamp(),
    'delivery_route',jsonb_build_object('distance_meters',5000,'quoted_at',clock_timestamp(),
      'origin_lat',v_order.pickup_lat,'origin_lng',v_order.pickup_lng,'pickup_lat',v_order.delivery_lat,'pickup_lng',v_order.delivery_lng));
  v_near := v_near||jsonb_build_object('delivery_route',v_quote->'delivery_route','quoted_at',clock_timestamp());
  v_selected := public.commit_road_driver_offer(v_order_id,jsonb_build_array(v_quote,v_near));
  IF v_selected IS DISTINCT FROM v_users[2] THEN RAISE EXCEPTION 'Closer driver exceeded strict 5km cap but still won'; END IF;
  UPDATE public.orders SET offered_driver_id=NULL,offer_expires_at=NULL WHERE id=v_order_id;
  v_quote := jsonb_set(v_quote,'{delivery_route,distance_meters}','10000');
  v_near := jsonb_set(v_near,'{delivery_route,distance_meters}','10000');
  IF public.commit_road_driver_offer(v_order_id,jsonb_build_array(v_quote,v_near)) IS NOT NULL THEN
    RAISE EXCEPTION 'Both delivery caps must reject exactly 10km'; END IF;
  PERFORM set_config('request.jwt.claim.sub',v_users[1]::text,true);
  PERFORM public.set_driver_dispatch_preferences('nearby',NULL,NULL,NULL,NULL,NULL);
  v_selected := public.commit_road_driver_offer(v_order_id,jsonb_build_array(v_quote,v_near));
  IF v_selected IS DISTINCT FROM v_users[1] THEN RAISE EXCEPTION 'Unlimited driver rejected a long delivery'; END IF;
END;
$test$;
ROLLBACK;
