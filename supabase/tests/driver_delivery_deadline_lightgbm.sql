-- Initial ETA + 25 minutes; all fixture writes roll back.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT set_config('giaohang.road_dispatch_requested','yes',true);
SELECT set_config('request.jwt.claims','{}',true);

DO $$
DECLARE
  v_customer uuid; v_driver uuid; v_order uuid;
  v_case record; v_started timestamptz; v_first timestamptz; v_again timestamptz;
  v_eta jsonb; v_logs bigint;
BEGIN
  SELECT id INTO STRICT v_customer FROM public.users WHERE role='customer' LIMIT 1;
  SELECT d.user_id INTO STRICT v_driver FROM public.drivers d
  WHERE NOT EXISTS (SELECT 1 FROM public.orders o WHERE o.driver_id=d.user_id
    AND o.status IN ('assigned','picking_up','delivering')) LIMIT 1;

  -- Different initial ETA durations must all receive exactly 25 minutes.
  FOR v_case IN SELECT * FROM (VALUES
    (389,25,'osrm'), (900,35,'osrm'), (600,28,'osrm'),
    (1500,48,'distance_fallback')
  ) AS cases(route_seconds,budget_minutes,source) LOOP
    v_order:=gen_random_uuid();
    INSERT INTO public.orders(id,customer_id,status,pickup_address,pickup_lat,pickup_lng,
      delivery_address,delivery_lat,delivery_lng,tracking_code)
    VALUES(v_order,v_customer,'confirmed','Deadline test pickup',10.7849,106.6684,
      'Deadline test delivery',10.793838,106.651842,'TEST-DEADLINE-AI-'||v_order::text);
    UPDATE public.orders SET driver_id=v_driver,status='assigned' WHERE id=v_order;
    SELECT delivery_eta INTO v_eta FROM public.orders WHERE id=v_order;

    SELECT estimated_delivery_at INTO v_first
    FROM public.accept_driver_order_with_deadline(
      v_order,v_driver,v_case.route_seconds,false,v_case.source,true);
    IF v_first IS NOT NULL THEN RAISE EXCEPTION 'Deadline created without ETA'; END IF;
    v_started:=(v_eta->>'assigned_at')::timestamptz;
    v_eta:=v_eta||jsonb_build_object('calculation_mode','assignment_once_v1',
      'phase','fixed','computed_at',clock_timestamp(),
      'initial_predicted_at',v_started+make_interval(mins=>v_case.budget_minutes),
      'predicted_at',v_started+make_interval(mins=>v_case.budget_minutes),
      'initial_total_minutes',v_case.budget_minutes);
    PERFORM public.commit_order_delivery_eta(v_order,v_driver,'assigned',NULL,NULL,NULL,v_eta);
    SELECT estimated_delivery_at INTO v_first FROM public.orders WHERE id=v_order;
    IF v_first IS DISTINCT FROM v_started+make_interval(mins=>v_case.budget_minutes+25)
      THEN RAISE EXCEPTION 'Deadline is not initial ETA plus 25 minutes'; END IF;

    SELECT count(*) INTO v_logs FROM public.order_status_logs WHERE order_id=v_order;
    SELECT estimated_delivery_at INTO v_again
    FROM public.accept_driver_order_with_deadline(v_order,v_driver,86400,false,'osrm',true);
    IF v_again IS DISTINCT FROM v_first OR
      (SELECT count(*) FROM public.order_status_logs WHERE order_id=v_order) <> v_logs THEN
      RAISE EXCEPTION 'A changed traffic quote recalculated an existing deadline';
    END IF;
    IF (SELECT count(*) FROM public.order_status_logs WHERE order_id=v_order
      AND title='Đã xác lập hạn giao') <> 1 THEN
      RAISE EXCEPTION 'Deadline audit was not recorded exactly once';
    END IF;
    -- Release this fixture before reusing the driver for the next case.
    UPDATE public.orders SET driver_id=NULL,status='confirmed' WHERE id=v_order;
    IF (SELECT estimated_delivery_at FROM public.orders WHERE id=v_order) IS NOT NULL
      THEN RAISE EXCEPTION 'Reassignment retained old deadline'; END IF;
  END LOOP;

  IF has_function_privilege('authenticated',
    'public.accept_driver_order_with_deadline(uuid,uuid,integer,boolean,text,boolean)','execute') OR
    has_function_privilege('anon',
    'public.accept_driver_order_with_deadline(uuid,uuid,integer,boolean,text,boolean)','execute') THEN
    RAISE EXCEPTION 'Clients can supply their own adjusted route quote';
  END IF;
END;
$$;
ROLLBACK;
