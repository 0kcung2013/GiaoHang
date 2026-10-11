-- Run after the migration. All fixtures and writes are rolled back.
BEGIN;
DO $test$
DECLARE
  customer_id uuid := gen_random_uuid();
  driver_id uuid := gen_random_uuid();
  support_id uuid := gen_random_uuid();
  v_order_id uuid := gen_random_uuid();
  report_id uuid := gen_random_uuid();
  next_report_id uuid := gen_random_uuid();
  original_return_id uuid;
  mission public.order_returns%ROWTYPE;
  rejected boolean;
BEGIN
  INSERT INTO public.users(id,email,full_name,role) VALUES
    (customer_id,customer_id::text||'@example.invalid','Return test customer','customer'),
    (driver_id,driver_id::text||'@example.invalid','Return test driver','driver'),
    (support_id,support_id::text||'@example.invalid','Return test support','support');

  INSERT INTO public.orders(id,customer_id,driver_id,status,
    pickup_address,pickup_lat,pickup_lng,delivery_address,delivery_lat,delivery_lng,
    actual_picked_up_at,tracking_code,delivery_fee)
  VALUES (v_order_id,customer_id,driver_id,'delivering',
    'Test pickup',10.775,106.68,'Test delivery',10.785,106.69,
    clock_timestamp()-interval '1 hour','TEST-'||v_order_id::text,30000);

  INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by,created_at)
  VALUES(v_order_id,'delivering','Tài xế đã đến điểm giao','Test arrival',
    driver_id,clock_timestamp()-interval '11 minutes');
  PERFORM set_config('request.jwt.claim.sub',driver_id::text,true);
  INSERT INTO public.risk_reports(id,order_id,reported_by,updated_by,reporter_role_snapshot,
    category,title,description)
  VALUES(report_id,v_order_id,driver_id,driver_id,'driver','contact_issue',
    'Test unreachable recipient','Test customer did not answer at the delivery address.');
  PERFORM set_config('request.jwt.claim.sub',support_id::text,true);
  UPDATE public.risk_reports SET assigned_to=support_id,status='investigating',
    updated_by=support_id WHERE id=report_id;
  SELECT * INTO mission FROM public.support_approve_return(report_id,'recipient_unreachable',
    'sender','Test pickup',10.775,106.68,10.785,106.69,1600,300,
    'osrm','platform',0,15000,NULL);
  original_return_id := mission.id;
  PERFORM set_config('request.jwt.claim.sub',driver_id::text,true);
  PERFORM public.start_order_return(v_order_id);

  IF NOT public.can_cancel_order_return(v_order_id) THEN RAISE EXCEPTION 'Contact return should be cancellable'; END IF;
  rejected := false;
  BEGIN
    UPDATE public.orders SET status='delivering' WHERE id=v_order_id;
  EXCEPTION WHEN OTHERS THEN rejected:=true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'Direct transition must remain blocked'; END IF;

  PERFORM set_config('request.jwt.claim.sub',customer_id::text,true);
  rejected:=false;
  BEGIN
    PERFORM public.cancel_order_return(v_order_id,'Customer requested redelivery');
  EXCEPTION WHEN insufficient_privilege THEN rejected:=true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'Other actor cancelled a return'; END IF;
  PERFORM set_config('request.jwt.claim.sub',driver_id::text,true);
  rejected:=false;
  BEGIN
    PERFORM public.cancel_order_return(v_order_id,'');
  EXCEPTION WHEN invalid_parameter_value THEN rejected:=true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'Empty cancellation reason accepted'; END IF;

  SELECT * INTO mission FROM public.cancel_order_return(v_order_id,'Customer requested redelivery');
  IF mission.status<>'cancelled' OR mission.fee_status<>'waived'
    OR mission.returned_at IS NOT NULL THEN RAISE EXCEPTION 'Cancelled mission was not preserved'; END IF;
  IF (SELECT status FROM public.orders WHERE id=v_order_id)<>'delivering'
  THEN RAISE EXCEPTION 'Order did not resume delivery'; END IF;
  IF (SELECT state FROM public.risk_report_interventions WHERE risk_report_id=report_id)<>'continue_delivery'
  THEN RAISE EXCEPTION 'Custody intervention still blocks delivery'; END IF;
  IF (SELECT status FROM public.risk_reports WHERE id=report_id)<>'resolved'
  THEN RAISE EXCEPTION 'Contact case was not resolved'; END IF;
  IF EXISTS(SELECT 1 FROM public.driver_wallet_transactions WHERE order_id=v_order_id)
  THEN RAISE EXCEPTION 'Cancellation unexpectedly paid return income'; END IF;
  IF (SELECT count(*) FROM public.risk_report_events WHERE risk_report_id=report_id
    AND details->>'action'='return_cancelled')<>1
  THEN RAISE EXCEPTION 'Cancellation audit missing or duplicated'; END IF;

  PERFORM public.cancel_order_return(v_order_id,'Duplicate retry');
  IF (SELECT count(*) FROM public.risk_report_events WHERE risk_report_id=report_id
    AND details->>'action'='return_cancelled')<>1
  THEN RAISE EXCEPTION 'Retry created a duplicate audit event'; END IF;
  rejected:=false;
  BEGIN PERFORM public.confirm_order_return(v_order_id,'Test receiver',NULL);
  EXCEPTION WHEN OTHERS THEN rejected:=true; END;
  IF NOT rejected THEN RAISE EXCEPTION 'Cancelled return could still complete'; END IF;

  -- A new support-approved attempt reuses the mission, preserving prior case audit.
  INSERT INTO public.risk_reports(id,order_id,reported_by,updated_by,reporter_role_snapshot,
    category,title,description)
  VALUES(next_report_id,v_order_id,driver_id,driver_id,'driver','safety',
    'Test safety return','Test safety incident requires support instructions.');
  PERFORM set_config('request.jwt.claim.sub',support_id::text,true);
  UPDATE public.risk_reports SET assigned_to=support_id,status='investigating',
    updated_by=support_id WHERE id=next_report_id;
  SELECT * INTO mission FROM public.support_approve_return(next_report_id,'recipient_unreachable',
    'sender','Test pickup',10.775,106.68,10.785,106.69,1600,300,
    'osrm','platform',0,15000,NULL);
  IF mission.id<>original_return_id OR mission.status<>'approved' OR mission.started_at IS NOT NULL
  THEN RAISE EXCEPTION 'Support could not approve a fresh return attempt'; END IF;
  PERFORM set_config('request.jwt.claim.sub',driver_id::text,true);
  PERFORM public.start_order_return(v_order_id);
  IF public.can_cancel_order_return(v_order_id) THEN RAISE EXCEPTION 'Safety return exposed direct cancellation'; END IF;
  rejected:=false;
  BEGIN PERFORM public.cancel_order_return(v_order_id,'Customer requested redelivery');
  EXCEPTION WHEN check_violation THEN rejected:=true; END;
  IF NOT rejected THEN RAISE EXCEPTION 'Safety return allowed cancellation'; END IF;
END;
$test$;
ROLLBACK;
SELECT 'return redelivery checks passed; all fixtures rolled back' AS result;

