-- Existing test accounts are locked briefly; all changes are rolled back.
BEGIN;
SELECT set_config('giaohang.road_dispatch_requested','yes',true);
DO $test$
DECLARE
  v_drivers uuid[]; v_customer uuid; v_order uuid := gen_random_uuid();
  v_second uuid := gen_random_uuid(); v_selected uuid; v_quote_a jsonb; v_quote_b jsonb;
  v_profile public.drivers%ROWTYPE; v_snapshot public.orders%ROWTYPE;
  v_deadline timestamptz; v_retry_deadline timestamptz;
BEGIN
  SELECT array_agg(user_id) INTO v_drivers FROM (
    SELECT d.user_id FROM public.drivers d WHERE NOT EXISTS(
      SELECT 1 FROM public.orders o WHERE o.driver_id=d.user_id
        AND o.status IN ('assigned','picking_up','delivering','return_approved','returning'))
      AND NOT EXISTS(SELECT 1 FROM public.orders o WHERE o.offered_driver_id=d.user_id
        AND o.driver_id IS NULL AND o.status IN ('pending','confirmed')
        AND o.assignment_timed_out_at IS NULL)
    ORDER BY d.user_id LIMIT 2) eligible;
  IF cardinality(v_drivers) <> 2 THEN RAISE EXCEPTION 'Test requires two idle driver accounts'; END IF;
  SELECT id INTO v_customer FROM public.users WHERE role='customer' LIMIT 1;
  IF v_customer IS NULL THEN RAISE EXCEPTION 'Test requires a customer account'; END IF;
  UPDATE public.drivers SET is_available=true,approval_status='approved',
    acceptance_locked_until=NULL,current_lng=106.7,
    current_lat=CASE WHEN user_id=v_drivers[1] THEN 10.781 ELSE 10.783 END,
    location_updated_at=clock_timestamp() WHERE user_id=ANY(v_drivers);
  INSERT INTO public.orders(id,customer_id,status,pickup_address,pickup_lat,pickup_lng,
    delivery_address,delivery_lat,delivery_lng,tracking_code)
    VALUES(v_order,v_customer,'pending','Road regression pickup',10.78,106.7,
      'Road regression delivery',10.79,106.71,'ROAD-TEST-'||v_order::text),
      (v_second,v_customer,'pending','Road regression pickup',10.78,106.7,
      'Road regression delivery',10.79,106.71,'ROAD-TEST-'||v_second::text);
  IF (SELECT offered_driver_id FROM public.orders WHERE id=v_order) IS NOT NULL THEN
    RAISE EXCEPTION 'Insert synchronously assigned using direct distance';
  END IF;
  v_quote_a := jsonb_build_object('user_id',v_drivers[1],'origin_lat',10.781,'origin_lng',106.7,
    'pickup_lat',10.78,'pickup_lng',106.7,'distance_meters',2800,'duration_seconds',200,'quoted_at',now());
  v_quote_b := v_quote_a || jsonb_build_object('user_id',v_drivers[2],
    'origin_lat',10.783,'distance_meters',900);
  v_selected := public.commit_road_driver_offer(v_order,jsonb_build_array(v_quote_a,v_quote_b));
  IF v_selected IS DISTINCT FROM v_drivers[2] THEN RAISE EXCEPTION 'Road distance did not win'; END IF;
  IF (SELECT offer_expires_at FROM public.orders WHERE id=v_order) NOT BETWEEN
    now()+interval '44 seconds' AND clock_timestamp()+interval '45 seconds' THEN
    RAISE EXCEPTION 'Offer window changed';
  END IF;
  IF public.commit_road_driver_offer(v_order,jsonb_build_array(v_quote_b)) IS NOT NULL THEN
    RAISE EXCEPTION 'Retry replaced an existing offer';
  END IF;
  IF public.commit_road_driver_offer(v_second,jsonb_build_array(v_quote_b)) IS NOT NULL THEN
    RAISE EXCEPTION 'Driver received two simultaneous offers';
  END IF;
  IF public.commit_road_driver_offer(v_second,jsonb_build_array(
    v_quote_a||jsonb_build_object('distance_meters',500,'quoted_at',now()-interval '31 seconds'))) IS NOT NULL THEN
    RAISE EXCEPTION 'Stale quote accepted';
  END IF;
  UPDATE public.drivers SET is_available=false WHERE user_id=v_drivers[1];
  IF public.commit_road_driver_offer(v_second,jsonb_build_array(
    v_quote_a||jsonb_build_object('distance_meters',500))) IS NOT NULL THEN
    RAISE EXCEPTION 'Offline driver received offer';
  END IF;
  SELECT * INTO v_profile FROM public.drivers WHERE user_id=v_drivers[1];
  SELECT * INTO v_snapshot FROM public.orders WHERE id=v_second;
  IF private.valid_pickup_road_quote(v_quote_a||jsonb_build_object('origin_lat',10.785),
    v_profile,v_snapshot,0,4000) THEN RAISE EXCEPTION 'Moved GPS quote accepted'; END IF;
  IF private.valid_pickup_road_quote(NULL,v_profile,v_snapshot,2000.000001,4000) THEN
    RAISE EXCEPTION 'FreePick can accept without route proof';
  END IF;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_drivers[1],'role','authenticated')::text,true);
  BEGIN
    PERFORM public.claim_free_pick_order(v_second);
    RAISE EXCEPTION 'Direct FreePick bypass accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'ROAD_ROUTE_QUOTE_REQUIRED' THEN RAISE; END IF;
  END;
  IF has_function_privilege('authenticated','public.commit_road_driver_offer(uuid,jsonb)','execute')
    OR has_function_privilege('authenticated',
      'public.accept_driver_order_with_road_quote(uuid,uuid,integer,boolean,text,boolean,jsonb)','execute') THEN
    RAISE EXCEPTION 'Client can forge road quotes';
  END IF;
  -- Reject and timeout must queue road dispatch rather than synchronously re-rank GPS.
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_drivers[2],'role','authenticated')::text,true);
  PERFORM public.reject_order(v_order,v_drivers[2]::text);
  IF (SELECT offered_driver_id FROM public.orders WHERE id=v_order) IS NOT NULL
    OR NOT ((SELECT rejected_by FROM public.orders WHERE id=v_order) ? v_drivers[2]::text) THEN
    RAISE EXCEPTION 'Reject did not clear and queue the next offer';
  END IF;
  UPDATE public.drivers SET is_available=true WHERE user_id=v_drivers[1];
  v_selected := public.commit_road_driver_offer(v_order,jsonb_build_array(v_quote_b,
    v_quote_a||jsonb_build_object('distance_meters',1400)));
  IF v_selected IS DISTINCT FROM v_drivers[1] THEN RAISE EXCEPTION 'Rejected driver was reselected'; END IF;
  UPDATE public.orders SET offer_expires_at=clock_timestamp()-interval '1 second' WHERE id=v_order;
  PERFORM private.dispatch_next_order_offer(v_order,2000);
  IF (SELECT offered_driver_id FROM public.orders WHERE id=v_order) IS NOT NULL
    OR NOT ((SELECT rejected_by FROM public.orders WHERE id=v_order) ? v_drivers[1]::text) THEN
    RAISE EXCEPTION 'Timeout did not exclude the expired offer';
  END IF;
  UPDATE public.orders SET assignment_expires_at=clock_timestamp()-interval '1 second' WHERE id=v_order;
  PERFORM private.dispatch_next_order_offer(v_order,2000);
  IF (SELECT assignment_timed_out_at FROM public.orders WHERE id=v_order) IS NULL THEN
    RAISE EXCEPTION 'Assignment deadline stopped working';
  END IF;
  -- A trusted valid FreePick quote must still accept and establish the old server deadline.
  PERFORM set_config('request.jwt.claims','',true);
  BEGIN
    PERFORM public.accept_driver_order_with_road_quote(v_second,v_drivers[1],300,true,'osrm',false,
      v_quote_a||jsonb_build_object('distance_meters',3000.1));
    RAISE EXCEPTION 'FreePick accepted a road route beyond 3 km';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'ROAD_ROUTE_QUOTE_REQUIRED' THEN RAISE; END IF;
  END;
  SELECT estimated_delivery_at INTO v_deadline
    FROM public.accept_driver_order_with_road_quote(v_second,v_drivers[1],300,true,'osrm',false,v_quote_a);
  IF (SELECT driver_id FROM public.orders WHERE id=v_second) IS DISTINCT FROM v_drivers[1]
    OR v_deadline < now()+interval '25 minutes' THEN RAISE EXCEPTION 'Valid FreePick quote failed'; END IF;
  SELECT estimated_delivery_at INTO v_retry_deadline
    FROM public.accept_driver_order_with_road_quote(v_second,v_drivers[1],900,true,'osrm',false,v_quote_a);
  IF v_retry_deadline IS DISTINCT FROM v_deadline THEN RAISE EXCEPTION 'Retry extended delivery deadline'; END IF;
  RAISE NOTICE 'PASS road ranking, uniqueness, freshness, eligibility, reject, timeout, FreePick and acceptance';
END;
$test$;
ROLLBACK;
