-- Exercise the actual automatic candidate/commit path; all fixtures rollback.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT set_config('giaohang.road_dispatch_requested','yes',true);
SELECT set_config('request.jwt.claims','{}',true);
DO $$
DECLARE d uuid; c uuid; held uuid:=gen_random_uuid(); next_order uuid:=gen_random_uuid(); third_order uuid:=gen_random_uuid();
 candidates jsonb; selected uuid; quote jsonb;
BEGIN
 SELECT user_id INTO STRICT d FROM public.drivers WHERE NOT EXISTS(
  SELECT 1 FROM public.orders WHERE driver_id=drivers.user_id
   AND status IN ('assigned','picking_up','delivering','return_approved','returning')) LIMIT 1;
 SELECT id INTO STRICT c FROM public.users WHERE role='customer' LIMIT 1;
 UPDATE public.drivers SET is_available=true,approval_status='approved',acceptance_locked_until=NULL,
   current_lat=11.035441,current_lng=106.619023,location_updated_at=clock_timestamp() WHERE user_id=d;
 INSERT INTO public.orders(id,customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,
  delivery_address,delivery_lat,delivery_lng,tracking_code)
 VALUES(held,c,d,'delivering','Hold fixture',11.036086,106.623027,'Hold destination',11.035441,106.619023,'TEST-HOLD-AUTO-'||held);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
 PERFORM public.confirm_driver_delivery_arrival(held);
 PERFORM public.set_driver_recipient_hold(held,30);
 PERFORM set_config('request.jwt.claims','{}',true);
 INSERT INTO public.orders(id,customer_id,status,pickup_address,pickup_lat,pickup_lng,
  delivery_address,delivery_lat,delivery_lng,tracking_code,assignment_expires_at)
 -- Reproduce GH-10379 / GH-10312: a valid hold does not waive the pickup radius.
 VALUES(next_order,c,'pending','Far pickup',10.9856068030991,106.673910357355,'Next destination',10.986,106.674,
  'TEST-HOLD-AUTO-'||next_order,clock_timestamp()+interval '15 minutes'),
 (third_order,c,'pending','Third pickup',11.035941,106.619023,'Third destination',11.036441,106.619023,
  'TEST-HOLD-AUTO-'||third_order,clock_timestamp()+interval '15 minutes');
 candidates:=public.road_dispatch_candidates(next_order);
 IF candidates @> jsonb_build_array(jsonb_build_object('user_id',d)) THEN
  RAISE EXCEPTION 'HELD_DRIVER_RECEIVED_FAR_PICKUP_INVITATION'; END IF;
 -- Changing only the pickup location must make this same held driver eligible.
 UPDATE public.orders SET pickup_address='Nearby pickup',pickup_lat=11.035941,
  pickup_lng=106.619023 WHERE id=next_order;
 candidates:=public.road_dispatch_candidates(next_order);
 IF NOT candidates @> jsonb_build_array(jsonb_build_object('user_id',d)) THEN
  RAISE EXCEPTION 'HOLD_AUTO_DISPATCH_MISSING: held driver excluded from actual invitation candidates';
 END IF;
 -- Even an otherwise eligible held driver must be excluded after the hold is due.
 UPDATE public.orders SET delivery_hold=delivery_hold||jsonb_build_object('until',clock_timestamp()-interval '1 second') WHERE id=held;
 IF public.road_dispatch_candidates(next_order) @> jsonb_build_array(jsonb_build_object('user_id',d)) THEN
  RAISE EXCEPTION 'HOLD_DUE_DRIVER_RECEIVED_NEW_INVITATION'; END IF;
 UPDATE public.orders SET delivery_hold=delivery_hold||jsonb_build_object('until',clock_timestamp()+interval '30 minutes') WHERE id=held;
 quote:=jsonb_build_object('user_id',d,'origin_lat',11.035441,'origin_lng',106.619023,
  'pickup_lat',11.035941,'pickup_lng',106.619023,'distance_meters',100,'duration_seconds',20,'quoted_at',clock_timestamp());
 -- A nearby point may still have a road route outside the automatic radius.
 IF public.commit_road_driver_offer(next_order,jsonb_build_array(
   quote||jsonb_build_object('distance_meters',2001))) IS NOT NULL THEN
  RAISE EXCEPTION 'HELD_DRIVER_RECEIVED_OUT_OF_ROAD_RADIUS_INVITATION'; END IF;
 selected:=public.commit_road_driver_offer(next_order,jsonb_build_array(quote));
 IF selected IS DISTINCT FROM d OR NOT EXISTS(SELECT 1 FROM public.notifications WHERE order_id=next_order AND user_id=d)
 THEN RAISE EXCEPTION 'HOLD_AUTO_OFFER_COMMIT_FAILED'; END IF;
 IF public.road_dispatch_candidates(third_order) @> jsonb_build_array(jsonb_build_object('user_id',d)) THEN
  RAISE EXCEPTION 'SECOND_SIMULTANEOUS_INVITATION_ALLOWED'; END IF;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
 PERFORM public.accept_order(next_order);
 -- Reprioritise the original parcel before its appointment; no third invitation.
 PERFORM public.set_driver_recipient_hold(held,NULL);
 PERFORM set_config('request.jwt.claims','{}',true);
 IF public.road_dispatch_candidates(third_order) @> jsonb_build_array(jsonb_build_object('user_id',d)) THEN
  RAISE EXCEPTION 'THIRD_ORDER_AUTO_INVITATION_ALLOWED'; END IF;
 IF public.commit_road_driver_offer(third_order,jsonb_build_array(quote)) IS NOT NULL THEN
  RAISE EXCEPTION 'THIRD_ORDER_COMMIT_AFTER_EARLY_RESUME_ALLOWED'; END IF;
 RAISE NOTICE 'PASS held driver: far pickup excluded, near pickup offered and accepted, road radius, due hold, one offer and workload limits';
END; $$;
ROLLBACK;
