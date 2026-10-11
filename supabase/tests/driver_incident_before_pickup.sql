-- Focused custody/incident regression; all orders/evidence/audit rows roll back.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT set_config('giaohang.road_dispatch_requested','yes',true);
SELECT set_config('request.jwt.claims','{}',true);

DO $$
DECLARE
  c uuid; d uuid; s uuid; o uuid:=gen_random_uuid(); r uuid:=gen_random_uuid();
  later uuid:=gen_random_uuid(); result record; before_count bigint;
  released public.risk_report_interventions%ROWTYPE;
  snapshot public.orders%ROWTYPE;
  audit_count bigint;
BEGIN
  SELECT id INTO STRICT c FROM public.users WHERE role='customer' LIMIT 1;
  SELECT id INTO STRICT s FROM public.users WHERE role IN ('support','admin') LIMIT 1;
  SELECT user_id INTO STRICT d FROM public.drivers x WHERE NOT EXISTS (
    SELECT 1 FROM public.orders WHERE driver_id=x.user_id
      AND status IN ('assigned','picking_up','delivering')) LIMIT 1;
  INSERT INTO public.orders(id,customer_id,status,pickup_address,pickup_lat,pickup_lng,
    delivery_address,delivery_lat,delivery_lng,tracking_code)
  VALUES(o,c,'confirmed','Incident pickup',10.78,106.68,'Incident delivery',10.80,106.71,
    'TEST-INCIDENT-'||o);
  UPDATE public.orders SET driver_id=d,status='picking_up' WHERE id=o;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);

  BEGIN
    PERFORM public.create_participant_risk_report(r,o,'cargo_issue',
      'Hàng quá kích thước đã khai báo.',ARRAY[]::text[],NULL,NULL,NULL,ARRAY[]::uuid[]);
    RAISE EXCEPTION 'Accepted cargo report without photos';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'CARGO_PHOTO_REQUIRED' THEN RAISE; END IF;
  END;
  PERFORM public.create_participant_risk_report(r,o,'cargo_issue',
    'Hàng quá kích thước đã khai báo.',
    ARRAY['r2://media/orders/'||o||'/risk-evidence/'||r||'/photo.jpg'],NULL,NULL,NULL,ARRAY[]::uuid[]);
  IF (SELECT actual_picked_up_at FROM public.orders WHERE id=o) IS NOT NULL
    OR (SELECT status FROM public.orders WHERE id=o)<>'picking_up'
    OR (SELECT driver_id FROM public.orders WHERE id=o) IS DISTINCT FROM d
  THEN RAISE EXCEPTION 'Reporting automatically changed custody/assignment'; END IF;

  -- Repeated submission must use the existing report rather than creating another.
  BEGIN
    PERFORM public.create_participant_risk_report(later,o,'cargo_issue',
      'Thử gửi lặp báo cáo hàng quá kích thước.',
      ARRAY['r2://media/orders/'||o||'/risk-evidence/'||later||'/photo.jpg'],NULL,NULL,NULL,ARRAY[]::uuid[]);
    RAISE EXCEPTION 'Duplicate report accepted';
  EXCEPTION WHEN unique_violation THEN NULL; END;

  BEGIN
    PERFORM public.confirm_driver_pickup(o);
    RAISE EXCEPTION 'Confirmed pickup while cancellation is pending';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'PICKUP_INCIDENT_PENDING' THEN RAISE; END IF;
  END;
  -- Driver writes/status RPCs cannot bypass the custody confirmation check.
  BEGIN
    UPDATE public.orders SET actual_picked_up_at=clock_timestamp() WHERE id=o;
    RAISE EXCEPTION 'Bypassed pending report through pickup timestamp';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'PICKUP_INCIDENT_PENDING' THEN RAISE; END IF;
  END;
  BEGIN
    UPDATE public.orders SET status='delivering' WHERE id=o;
    RAISE EXCEPTION 'Bypassed pending report through status';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'PICKUP_INCIDENT_PENDING' THEN RAISE; END IF;
  END;

  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',s,'role','authenticated')::text,true);
  PERFORM public.accept_risk_report(r);
  PERFORM public.transition_risk_report(r,'resolved','Đã xác minh, tài xế đồng ý tiếp tục.');
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
  BEGIN
    PERFORM public.confirm_driver_pickup(o);
    RAISE EXCEPTION 'Fixture without proof unexpectedly confirmed';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'PICKUP_PROOF_LOCATION_REQUIRED' THEN RAISE; END IF;
  END;

  -- System fixture establishes real custody; status alone still says picking_up.
  PERFORM set_config('request.jwt.claims','{}',true);
  UPDATE public.orders SET actual_picked_up_at=clock_timestamp() WHERE id=o;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
  SELECT count(*) INTO before_count FROM public.risk_reports WHERE order_id=o;
  BEGIN
    PERFORM public.create_participant_risk_report(later,o,'cargo_issue',
      'Đã nhận hàng nhưng xin hủy vì kích thước.',
      ARRAY['r2://media/orders/'||o||'/risk-evidence/'||later||'/photo.jpg'],NULL,NULL,NULL,ARRAY[]::uuid[]);
    RAISE EXCEPTION 'Cargo cancellation accepted after pickup';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'CARGO_REPORT_AFTER_PICKUP' THEN RAISE; END IF;
  END;
  IF (SELECT count(*) FROM public.risk_reports WHERE order_id=o)<>before_count
    THEN RAISE EXCEPTION 'Failed report left persistent rows'; END IF;

  -- Customer cargo complaints retain their separate support flow.
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated')::text,true);
  PERFORM public.create_participant_risk_report(later,o,'cargo_issue',
    'Khách hàng cần kiểm tra tình trạng hàng.',ARRAY[]::text[],NULL,NULL,NULL,ARRAY[]::uuid[]);

  -- CSKH cannot release the driver once real custody has begun.
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',s,'role','authenticated')::text,true);
  PERFORM public.accept_risk_report(later);
  BEGIN
    PERFORM public.hold_risk_order_before_pickup(later);
    RAISE EXCEPTION 'CSKH released driver after pickup';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'Only an uncollected order can release its driver' THEN RAISE; END IF;
  END;
  PERFORM public.transition_risk_report(later,'resolved','Kết thúc tình huống kiểm thử sau nhận hàng.');

  -- Reset only this synthetic order to exercise the approved pre-pickup flow.
  PERFORM set_config('request.jwt.claims','{}',true);
  UPDATE public.orders SET actual_picked_up_at=NULL WHERE id=o;
  SELECT * INTO snapshot FROM public.orders WHERE id=o;
  r:=gen_random_uuid();
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
  PERFORM public.create_participant_risk_report(r,o,'cargo_issue',
    'Kiện hàng quá lớn, yêu cầu CSKH hủy nhận đơn.',
    ARRAY['r2://media/orders/'||o||'/risk-evidence/'||r||'/photo.jpg'],NULL,NULL,NULL,ARRAY[]::uuid[]);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',s,'role','authenticated')::text,true);
  PERFORM public.accept_risk_report(r);
  released:=public.hold_risk_order_before_pickup(r);
  IF released.state<>'released' OR released.driver_id IS DISTINCT FROM d
    OR released.driver_released_at IS NULL
  THEN RAISE EXCEPTION 'CSKH did not release the previous driver'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.orders WHERE id=o AND status='pending'
    AND driver_id IS NULL AND risk_hold_report_id IS NULL
    AND customer_id=snapshot.customer_id
    AND payment_status IS NOT DISTINCT FROM snapshot.payment_status
    AND total_price IS NOT DISTINCT FROM snapshot.total_price
    AND rejected_by ? d::text
    AND estimated_delivery_at IS NULL
    AND assignment_expires_at > clock_timestamp()+interval '14 minutes')
  THEN RAISE EXCEPTION 'Requeue lost customer/payment/search state'; END IF;
  IF EXISTS (SELECT 1 FROM public.driver_wallet_transactions WHERE order_id=o)
  THEN RAISE EXCEPTION 'Pre-pickup release changed the driver wallet'; END IF;
  -- OSRM dispatch runs asynchronously, so a new offer is not required here.
  SELECT count(*) INTO audit_count FROM public.risk_report_events WHERE risk_report_id=r;
  PERFORM public.hold_risk_order_before_pickup(r,'Thử lại thao tác đã hoàn tất.');
  IF audit_count<>(SELECT count(*) FROM public.risk_report_events WHERE risk_report_id=r)
  THEN RAISE EXCEPTION 'Repeated cancellation duplicated its audit'; END IF;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
  BEGIN
    PERFORM public.confirm_driver_pickup(o);
    RAISE EXCEPTION 'Released driver could still confirm pickup';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'DRIVER_NOT_ASSIGNED' THEN RAISE; END IF;
  END;
END;
$$;
SELECT 'incident custody regression passed; fixtures rolled back' AS result;
ROLLBACK;
