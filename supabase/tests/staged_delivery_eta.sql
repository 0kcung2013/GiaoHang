-- All fixture orders/logs/notifications roll back. No persistent GPS is written.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT set_config('giaohang.road_dispatch_requested','yes',true);
SELECT set_config('request.jwt.claims','{}',true);

DO $$
DECLARE
  v_customer uuid; v_driver uuid; v_order uuid:=gen_random_uuid();
  v_deadline timestamptz:=clock_timestamp()+interval '25 minutes';
  v_anchor timestamptz; v_departure timestamptz; v_snapshot jsonb; v_saved jsonb; v_result jsonb;
BEGIN
  SELECT id INTO STRICT v_customer FROM public.users WHERE role='customer' LIMIT 1;
  SELECT d.user_id INTO STRICT v_driver FROM public.drivers d
  WHERE NOT EXISTS (SELECT 1 FROM public.orders o WHERE o.driver_id=d.user_id
    AND o.status IN ('assigned','picking_up','delivering')) LIMIT 1;
  INSERT INTO public.orders(id,customer_id,status,pickup_address,pickup_lat,pickup_lng,
    delivery_address,delivery_lat,delivery_lng,tracking_code)
  VALUES(v_order,v_customer,'confirmed','ETA test pickup',10.78,106.68,
    'ETA test delivery',10.80,106.71,'TEST-ETA-'||v_order::text);
  UPDATE public.orders SET driver_id=v_driver,status='assigned',estimated_delivery_at=v_deadline WHERE id=v_order;
  SELECT (delivery_eta->>'assigned_at')::timestamptz INTO v_anchor FROM public.orders WHERE id=v_order;
  IF v_anchor IS NULL THEN RAISE EXCEPTION 'Assignment timestamp missing'; END IF;
  v_snapshot:=jsonb_build_object('version',2,'calculation_mode','assignment_once_v1',
    'driver_id',v_driver,'assigned_at',v_anchor,'departed_at',NULL,'phase','fixed',
    'computed_at',clock_timestamp(),'initial_predicted_at',v_anchor+interval '29 minutes',
    'predicted_at',v_anchor+interval '29 minutes','initial_total_minutes',29,
    'remaining_minutes',29,'preparation_removed_minutes',0,
    'preparation_minutes',5,'pickup_minutes',5,'handoff_minutes',5);
  v_saved:=public.commit_order_delivery_eta(v_order,v_driver,'assigned',NULL,NULL,NULL,v_snapshot);
  IF v_saved IS DISTINCT FROM v_snapshot THEN RAISE EXCEPTION 'Initial forecast was not committed'; END IF;
  v_deadline:=v_anchor+interval '54 minutes';
  IF (SELECT estimated_delivery_at FROM public.orders WHERE id=v_order) IS DISTINCT FROM v_deadline
    THEN RAISE EXCEPTION 'Changed operational deadline'; END IF;

  -- First committed forecast wins even if a later response has a newer timestamp.
  v_result:=public.commit_order_delivery_eta(v_order,v_driver,'assigned',NULL,NULL,NULL,
    v_snapshot||jsonb_build_object('computed_at',clock_timestamp(),'predicted_at',clock_timestamp()+interval '1 hour'));
  IF v_result IS DISTINCT FROM v_saved THEN RAISE EXCEPTION 'Recalculated fixed ETA'; END IF;

  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_customer,'role','authenticated')::text,true);
  BEGIN
    PERFORM public.mark_driver_eta_departure(v_order);
    RAISE EXCEPTION 'Customer was allowed to confirm departure';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_driver,'role','authenticated')::text,true);
  PERFORM public.mark_driver_eta_departure(v_order);
  SELECT delivery_eta INTO v_saved FROM public.orders WHERE id=v_order;
  v_departure:=(v_saved->>'departed_at')::timestamptz;
  IF v_departure IS NULL OR (v_saved->>'predicted_at')::timestamptz <> v_anchor+interval '24 minutes'
    OR (v_saved->>'preparation_removed_minutes')::integer <> 5
    OR v_saved->>'computed_at' IS DISTINCT FROM v_snapshot->>'computed_at'
    OR (v_saved->>'pickup_minutes')::integer <> 5 OR (v_saved->>'handoff_minutes')::integer <> 5
    THEN RAISE EXCEPTION 'Early departure did not remove exactly five minutes'; END IF;
  PERFORM public.mark_driver_eta_departure(v_order);
  IF (SELECT delivery_eta FROM public.orders WHERE id=v_order) IS DISTINCT FROM v_saved
    THEN RAISE EXCEPTION 'Departure retry altered fixed ETA'; END IF;
  IF (SELECT estimated_delivery_at FROM public.orders WHERE id=v_order) IS DISTINCT FROM v_deadline
    THEN RAISE EXCEPTION 'Departure changed operational deadline'; END IF;

  -- Early arrival and completion of phases keep the entire fixed forecast.
  -- Use a system fixture transition; proof/geofence rules have their own tests.
  PERFORM set_config('request.jwt.claims','{}',true);
  UPDATE public.orders SET status='picking_up',pickup_arrived_at=clock_timestamp() WHERE id=v_order;
  IF (SELECT delivery_eta FROM public.orders WHERE id=v_order) IS DISTINCT FROM v_saved
    THEN RAISE EXCEPTION 'Pickup arrival altered fixed ETA'; END IF;
  UPDATE public.orders SET status='delivering',actual_picked_up_at=clock_timestamp() WHERE id=v_order;
  INSERT INTO public.order_status_logs(order_id,status,title,logged_by,created_at)
    VALUES(v_order,'delivering','Tài xế đã đến điểm giao',v_driver,clock_timestamp());
  IF (SELECT delivery_eta FROM public.orders WHERE id=v_order) IS DISTINCT FROM v_saved
    THEN RAISE EXCEPTION 'Pickup completion or delivery arrival altered fixed ETA'; END IF;
  v_result:=public.commit_order_delivery_eta(v_order,v_driver,'assigned',NULL,NULL,NULL,v_snapshot);
  IF v_result IS DISTINCT FROM v_saved THEN RAISE EXCEPTION 'Response restored preparation after departure'; END IF;

  -- A fresh assignment rejects the previous acceptance anchor, even for the same driver.
  PERFORM set_config('request.jwt.claims','{}',true);
  UPDATE public.orders SET driver_id=NULL,status='confirmed',actual_picked_up_at=NULL,pickup_arrived_at=NULL WHERE id=v_order;
  IF (SELECT delivery_eta FROM public.orders WHERE id=v_order) IS NOT NULL
    THEN RAISE EXCEPTION 'Released assignment kept ETA'; END IF;
  UPDATE public.orders SET driver_id=v_driver,status='assigned' WHERE id=v_order;
  BEGIN
    PERFORM public.commit_order_delivery_eta(v_order,v_driver,'assigned',NULL,NULL,NULL,v_snapshot);
    RAISE EXCEPTION 'Reassignment inherited old acceptance anchor';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'ETA_CONTEXT_CHANGED' THEN RAISE; END IF; END;
  SELECT (delivery_eta->>'assigned_at')::timestamptz INTO v_anchor FROM public.orders WHERE id=v_order;
  v_snapshot:=v_snapshot||jsonb_build_object('assigned_at',v_anchor,'computed_at',clock_timestamp(),
    'initial_predicted_at',v_anchor+interval '29 minutes','predicted_at',v_anchor+interval '29 minutes');

  -- GPS can confirm departure while OSRM is running: adjust without another calculation.
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_driver,'role','authenticated')::text,true);
  PERFORM public.mark_driver_eta_departure(v_order);
  v_saved:=public.commit_order_delivery_eta(v_order,v_driver,'assigned',NULL,NULL,NULL,v_snapshot);
  IF (v_saved->>'predicted_at')::timestamptz <> v_anchor+interval '24 minutes'
    OR v_saved->>'departed_at' IS NULL THEN RAISE EXCEPTION 'Lost concurrent early departure'; END IF;

  -- Departure after the initial five minutes cannot remove the original allowance.
  PERFORM set_config('request.jwt.claims','{}',true);
  UPDATE public.orders SET driver_id=NULL,status='confirmed' WHERE id=v_order;
  UPDATE public.orders SET driver_id=v_driver,status='assigned' WHERE id=v_order;
  v_anchor:=clock_timestamp()-interval '6 minutes';
  UPDATE public.orders SET delivery_eta=delivery_eta||jsonb_build_object('assigned_at',v_anchor) WHERE id=v_order;
  v_snapshot:=v_snapshot||jsonb_build_object('assigned_at',v_anchor,'computed_at',clock_timestamp(),
    'initial_predicted_at',v_anchor+interval '29 minutes','predicted_at',v_anchor+interval '29 minutes');
  PERFORM public.commit_order_delivery_eta(v_order,v_driver,'assigned',NULL,NULL,NULL,v_snapshot);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_driver,'role','authenticated')::text,true);
  PERFORM public.mark_driver_eta_departure(v_order);
  SELECT delivery_eta INTO v_saved FROM public.orders WHERE id=v_order;
  IF (v_saved->>'predicted_at')::timestamptz <> v_anchor+interval '29 minutes'
    OR (v_saved->>'preparation_removed_minutes')::integer <> 0 THEN RAISE EXCEPTION 'Late departure shortened ETA'; END IF;
  v_result:=private.apply_fixed_eta_departure(v_snapshot,v_anchor+interval '5 minutes');
  IF (v_result->>'preparation_removed_minutes')::integer <> 0 THEN RAISE EXCEPTION 'Five-minute boundary shortened ETA'; END IF;

  PERFORM set_config('request.jwt.claims','{}',true);
  UPDATE public.orders SET status='cancelled' WHERE id=v_order;
  BEGIN
    PERFORM public.commit_order_delivery_eta(v_order,v_driver,'assigned',NULL,NULL,NULL,v_snapshot);
    RAISE EXCEPTION 'Terminal order accepted a route response';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'ETA_CONTEXT_CHANGED' THEN RAISE; END IF; END;

  IF has_function_privilege('authenticated',
    'public.commit_order_delivery_eta(uuid,uuid,text,timestamptz,timestamptz,timestamptz,jsonb)','EXECUTE')
    OR has_function_privilege('anon','public.mark_driver_eta_departure(uuid)','EXECUTE')
    OR has_function_privilege('authenticated','private.apply_fixed_eta_departure(jsonb,timestamptz)','EXECUTE')
    OR NOT has_function_privilege('service_role',
    'public.commit_order_delivery_eta(uuid,uuid,text,timestamptz,timestamptz,timestamptz,jsonb)','EXECUTE')
    THEN RAISE EXCEPTION 'ETA RPC grants are unsafe'; END IF;
END;
$$;
SELECT 'fixed ETA regression passed; fixtures roll back' AS result;
ROLLBACK;
