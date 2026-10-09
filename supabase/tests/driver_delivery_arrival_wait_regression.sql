-- Run in a transaction; fixture orders and driver positions always roll back.
BEGIN;
DO $$
DECLARE
  v_driver uuid; v_customer uuid; v_order uuid := gen_random_uuid();
  v_report uuid := gen_random_uuid(); v_snapshot jsonb; v_again jsonb; v_count bigint;
BEGIN
  SELECT user_id INTO v_driver FROM public.drivers LIMIT 1;
  SELECT id INTO v_customer FROM public.users WHERE role = 'customer' LIMIT 1;
  IF v_driver IS NULL OR v_customer IS NULL THEN RAISE EXCEPTION 'Requires driver and customer fixtures'; END IF;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO public.orders(id,customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,
    delivery_address,delivery_lat,delivery_lng,tracking_code,actual_picked_up_at,estimated_delivery_at)
  VALUES(v_order,v_customer,v_driver,'delivering','Arrival regression',10,106,
    'Arrival regression',10.01,106.01,'TEST-ARRIVAL-' || v_order::text,clock_timestamp(),clock_timestamp()+interval '1 hour');
  PERFORM set_config('request.jwt.claim.sub', v_customer::text, true);
  BEGIN
    PERFORM public.get_driver_delivery_arrival(v_order);
    RAISE EXCEPTION 'Customer read allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('request.jwt.claim.sub', v_driver::text, true);
  PERFORM set_config('test.arrival_order',v_order::text,true);
  PERFORM set_config('test.arrival_driver',v_driver::text,true);
  v_snapshot := public.get_driver_delivery_arrival(v_order);
  IF v_snapshot->>'delivery_arrived_at' IS NOT NULL OR (v_snapshot->>'can_report_recipient')::boolean THEN
    RAISE EXCEPTION 'Arrival should start unconfirmed';
  END IF;
  BEGIN
    PERFORM public.create_participant_risk_report(v_report,v_order,'contact_issue','Recipient unreachable test',ARRAY[]::text[],10.01,106.01,clock_timestamp(),ARRAY[]::uuid[]);
    RAISE EXCEPTION 'Report before arrival accepted';
  EXCEPTION WHEN check_violation THEN IF SQLERRM <> 'DELIVERY_ARRIVAL_REQUIRED' THEN RAISE; END IF; END;
  UPDATE public.drivers SET current_lat=10.01,current_lng=106.01,location_updated_at=clock_timestamp()-interval '2 minutes' WHERE user_id=v_driver;
  BEGIN
    PERFORM public.confirm_driver_delivery_arrival(v_order);
    RAISE EXCEPTION 'Stale location accepted';
  EXCEPTION WHEN check_violation THEN IF SQLERRM <> 'DELIVERY_LOCATION_STALE' THEN RAISE; END IF; END;
  UPDATE public.drivers SET current_lat=11,current_lng=107,location_updated_at=clock_timestamp() WHERE user_id=v_driver;
  BEGIN
    PERFORM public.confirm_driver_delivery_arrival(v_order);
    RAISE EXCEPTION 'Outside geofence accepted';
  EXCEPTION WHEN check_violation THEN IF SQLERRM <> 'DELIVERY_OUTSIDE_GEOFENCE' THEN RAISE; END IF; END;
  UPDATE public.drivers SET current_lat=10.01,current_lng=106.01,location_updated_at=clock_timestamp() WHERE user_id=v_driver;
  v_snapshot := public.confirm_driver_delivery_arrival(v_order);
  v_again := public.confirm_driver_delivery_arrival(v_order);
  SELECT count(*) INTO v_count FROM public.order_status_logs WHERE order_id=v_order AND title='Tài xế đã đến điểm giao';
  IF v_count <> 1 OR v_snapshot->>'delivery_arrived_at' IS DISTINCT FROM v_again->>'delivery_arrived_at' THEN
    RAISE EXCEPTION 'Retry reset the clock or duplicated the audit';
  END IF;
  BEGIN
    PERFORM public.create_participant_risk_report(v_report,v_order,'contact_issue','Recipient unreachable test',ARRAY[]::text[],10.01,106.01,clock_timestamp(),ARRAY[]::uuid[]);
    RAISE EXCEPTION 'Early report accepted';
  EXCEPTION WHEN check_violation THEN IF SQLERRM <> 'RECIPIENT_WAIT_REQUIRED' THEN RAISE; END IF; END;
  -- Safety remains available before ten minutes; revert its transaction effects.
  BEGIN
    PERFORM public.create_participant_risk_report(gen_random_uuid(),v_order,'safety','Safety regression test',ARRAY[]::text[],10.01,106.01,clock_timestamp(),ARRAY[]::uuid[]);
    RAISE EXCEPTION 'ROLLBACK_SAFETY_FIXTURE';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'ROLLBACK_SAFETY_FIXTURE' THEN RAISE; END IF; END;
  UPDATE public.order_status_logs SET created_at=clock_timestamp()-interval '10 minutes'+interval '5 seconds'
  WHERE order_id=v_order AND title='Tài xế đã đến điểm giao';
  IF (public.get_driver_delivery_arrival(v_order)->>'can_report_recipient')::boolean THEN
    RAISE EXCEPTION '9m55s unlocked report';
  END IF;
  UPDATE public.order_status_logs SET created_at=clock_timestamp()-interval '10 minutes'
  WHERE order_id=v_order AND title='Tài xế đã đến điểm giao';
  IF NOT (public.get_driver_delivery_arrival(v_order)->>'can_report_recipient')::boolean THEN
    RAISE EXCEPTION 'Ten minutes did not unlock report';
  END IF;
  BEGIN
    PERFORM public.create_participant_risk_report(v_report,v_order,'contact_issue','Recipient unreachable test',ARRAY[]::text[],10.01,106.01,clock_timestamp(),ARRAY[]::uuid[]);
    SET CONSTRAINTS risk_reports_require_recipient_call_evidence IMMEDIATE;
    RAISE EXCEPTION 'Missing call evidence accepted';
  EXCEPTION WHEN check_violation THEN IF SQLERRM <> 'RECIPIENT_CALL_EVIDENCE_REQUIRED' THEN RAISE; END IF; END;
  PERFORM public.create_participant_risk_report(v_report,v_order,'contact_issue','Recipient unreachable test',
    ARRAY['r2://media/orders/'||v_order::text||'/risk-evidence/'||v_report::text||'/calls.jpg'],10.01,106.01,clock_timestamp(),ARRAY[]::uuid[]);
  SET CONSTRAINTS risk_reports_require_recipient_call_evidence IMMEDIATE;
  IF NOT EXISTS (SELECT 1 FROM public.risk_report_events WHERE risk_report_id=v_report AND details->>'verification_type'='recipient_wait') THEN
    RAISE EXCEPTION 'Missing staff verification context';
  END IF;
  IF EXISTS (SELECT 1 FROM public.order_returns WHERE order_id=v_order) THEN
    RAISE EXCEPTION 'Reporting automatically approved return';
  END IF;
  IF has_function_privilege('anon','public.confirm_driver_delivery_arrival(uuid)','execute') THEN
    RAISE EXCEPTION 'Anonymous confirmation allowed';
  END IF;
END;
$$;
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  BEGIN
    INSERT INTO public.order_status_logs(order_id,status,title,logged_by,created_at)
    VALUES(current_setting('test.arrival_order')::uuid,'delivering','Tài xế đã đến điểm giao',
      current_setting('test.arrival_driver')::uuid,clock_timestamp()-interval '11 minutes');
    RAISE EXCEPTION 'Client forged an arrival audit';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM <> 'DELIVERY_ARRIVAL_SERVER_OWNED' THEN RAISE; END IF;
  END;
END;
$$;
RESET ROLE;
ROLLBACK;
