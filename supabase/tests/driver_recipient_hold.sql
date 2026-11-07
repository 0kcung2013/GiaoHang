-- Rollback fixtures: no real orders or wallet entries are committed.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT set_config('giaohang.road_dispatch_requested','yes',true);
SELECT set_config('request.jwt.claims','{}',true);
DO $$
DECLARE d uuid; c uuid; old_id uuid:=gen_random_uuid(); new_id uuid:=gen_random_uuid();
 third_id uuid:=gen_random_uuid(); original timestamptz:=clock_timestamp()+interval '20 minutes';
 r jsonb; first_hold jsonb; captured timestamptz; rid uuid; new_deadline timestamptz; resumed_deadline timestamptz;
BEGIN
 SELECT user_id INTO STRICT d FROM public.drivers WHERE NOT EXISTS(
  SELECT 1 FROM public.orders WHERE driver_id=drivers.user_id AND status IN ('assigned','picking_up','delivering','return_approved','returning')) LIMIT 1;
 SELECT id INTO STRICT c FROM public.users WHERE role='customer' LIMIT 1;
 UPDATE public.drivers SET is_available=true,approval_status='approved',acceptance_locked_until=NULL WHERE user_id=d;
 UPDATE public.drivers SET current_lat=10.79,current_lng=106.71,location_updated_at=clock_timestamp() WHERE user_id=d;
 INSERT INTO public.orders(id,customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,delivery_address,delivery_lat,delivery_lng,tracking_code,estimated_delivery_at)
 VALUES(old_id,c,d,'delivering','Hold pickup',10.78,106.7,'Hold delivery',10.79,106.71,'TEST-HOLD-'||old_id,original);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
 BEGIN
   PERFORM public.set_driver_recipient_hold(old_id,30);
   RAISE EXCEPTION 'HOLD_BEFORE_ARRIVAL_ALLOWED';
 EXCEPTION WHEN check_violation THEN
   IF SQLERRM<>'DELIVERY_ARRIVAL_REQUIRED' THEN RAISE; END IF;
 END;
 PERFORM public.confirm_driver_delivery_arrival(old_id);
 r:=public.set_driver_recipient_hold(old_id,30);
 first_hold:=r->'order'->'delivery_hold';
 IF first_hold->>'state'<>'holding' THEN RAISE EXCEPTION 'hold failed'; END IF;
 r:=public.set_driver_recipient_hold(old_id,60);
 IF r->'order'->'delivery_hold' IS DISTINCT FROM first_hold THEN RAISE EXCEPTION 'retry extended hold'; END IF;
 BEGIN PERFORM public.request_recipient_hold_return(old_id); RAISE EXCEPTION 'early return allowed';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'HOLD_RETURN_TOO_EARLY' THEN RAISE; END IF; END;
 PERFORM set_config('request.jwt.claims','{}',true);
 INSERT INTO public.orders(id,customer_id,status,pickup_address,pickup_lat,pickup_lng,delivery_address,delivery_lat,delivery_lng,tracking_code,offered_driver_id,offer_expires_at,assignment_expires_at)
 VALUES(new_id,c,'pending','New pickup',10.8,106.72,'New delivery',10.81,106.73,'TEST-HOLD-'||new_id,d,clock_timestamp()+interval '45 seconds',clock_timestamp()+interval '15 minutes');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
 PERFORM public.accept_order(new_id);
 IF NOT EXISTS(SELECT 1 FROM public.orders WHERE id=new_id AND driver_id=d AND status='assigned') THEN RAISE EXCEPTION 'accept second order failed'; END IF;
 PERFORM set_config('request.jwt.claims','{}',true);
 BEGIN
 INSERT INTO public.orders(id,customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,delivery_address,delivery_lat,delivery_lng,tracking_code)
 VALUES(third_id,c,d,'assigned','Third pickup',10.8,106.72,'Third delivery',10.81,106.73,'TEST-HOLD-'||third_id);
 RAISE EXCEPTION 'third order allowed'; EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
 SELECT estimated_delivery_at INTO new_deadline FROM public.orders WHERE id=new_id;
 r:=public.set_driver_recipient_hold(old_id,NULL);
 resumed_deadline:=(r->'order'->>'estimated_delivery_at')::timestamptz;
 IF r->'order'->'delivery_hold'->>'state'<>'resumed'
   OR clock_timestamp()>=(first_hold->>'until')::timestamptz
   OR abs(extract(epoch FROM (resumed_deadline-original)))>60 THEN
   RAISE EXCEPTION 'EARLY_RESUME_WITH_OTHER_ORDER_FAILED'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.orders WHERE id=new_id AND status='assigned'
   AND estimated_delivery_at IS NOT DISTINCT FROM new_deadline) THEN
   RAISE EXCEPTION 'EARLY_RESUME_CHANGED_OTHER_ORDER'; END IF;
 r:=public.set_driver_recipient_hold(old_id,NULL);
 IF (r->'order'->>'estimated_delivery_at')::timestamptz IS DISTINCT FROM resumed_deadline
   OR (SELECT count(*) FROM public.order_status_logs WHERE order_id=old_id
     AND title='Tiếp tục giao đơn đang giữ')<>1 THEN
   RAISE EXCEPTION 'EARLY_RESUME_RETRY_NOT_IDEMPOTENT'; END IF;
 PERFORM set_config('request.jwt.claims','{}',true);
 BEGIN
 INSERT INTO public.orders(id,customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,delivery_address,delivery_lat,delivery_lng,tracking_code)
 VALUES(third_id,c,d,'assigned','Third pickup',10.8,106.72,'Third delivery',10.81,106.73,'TEST-HOLD-'||third_id);
 RAISE EXCEPTION 'third order after resume allowed'; EXCEPTION WHEN unique_violation THEN NULL; END;
 BEGIN
 INSERT INTO public.orders(id,customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,delivery_address,delivery_lat,delivery_lng,tracking_code,delivery_hold)
 VALUES(third_id,c,d,'delivering','Third pickup',10.8,106.72,'Third delivery',10.81,106.73,
   'TEST-HOLD-'||third_id,first_hold);
 RAISE EXCEPTION 'third parcel with hold history after resume allowed'; EXCEPTION WHEN unique_violation THEN NULL; END;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
 captured:=clock_timestamp();
 r:=public.record_driver_monitoring_position(new_id,10.8,106.72,8,captured);
 IF r->>'accepted'<>'true' OR EXISTS(SELECT 1 FROM public.orders WHERE id IN(old_id,new_id)
   AND ((driver_monitoring->>'last_lat')::double precision<>10.8 OR (driver_monitoring->>'last_lng')::double precision<>106.72))
 THEN RAISE EXCEPTION 'same physical sample not applied to both active parcels after early resume'; END IF;
 r:=public.record_driver_monitoring_position(new_id,21.0,105.0,8,clock_timestamp());
 IF r->>'accepted'<>'false' OR r->>'reason'<>'implausible_jump' THEN RAISE EXCEPTION 'GPS jump accepted'; END IF;
 r:=public.record_driver_monitoring_position(new_id,10.8,106.72,8,captured-interval '3 minutes');
 IF r->>'accepted'<>'false' THEN RAISE EXCEPTION 'stale GPS accepted'; END IF;
 r:=public.record_driver_monitoring_position(new_id,10.8,106.72,80,clock_timestamp());
 IF r->>'accepted'<>'false' THEN RAISE EXCEPTION 'inaccurate GPS accepted'; END IF;
 r:=public.record_driver_monitoring_position(new_id,10.8,106.72,8,captured);
 IF r->>'reason'<>'duplicate_or_out_of_order' THEN RAISE EXCEPTION 'duplicate GPS accepted'; END IF;
 r:=public.record_driver_monitoring_position(old_id,10.80002,106.72002,8,clock_timestamp());
 IF r->>'accepted'<>'true' OR EXISTS(SELECT 1 FROM public.orders WHERE id IN(old_id,new_id)
   AND ((driver_monitoring->>'last_lat')::double precision<>10.80002
     OR (driver_monitoring->>'last_lng')::double precision<>106.72002)) THEN
   RAISE EXCEPTION 'REDLIVERY_GPS_NOT_APPLIED_TO_OTHER_ACTIVE_ORDER'; END IF;
 PERFORM set_config('request.jwt.claims','{}',true);
 DELETE FROM public.orders WHERE id=new_id;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
 r:=public.set_driver_recipient_hold(old_id,NULL);
 IF r->'order'->'delivery_hold'->>'state'<>'resumed' OR
   abs(extract(epoch FROM ((r->'order'->>'estimated_delivery_at')::timestamptz-original)))>60
 THEN RAISE EXCEPTION 'early resume incorrectly extended deadline'; END IF;
 BEGIN PERFORM public.set_driver_recipient_hold(old_id,30); RAISE EXCEPTION 'second hold allowed';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'HOLD_ALREADY_USED' THEN RAISE; END IF; END;
 PERFORM set_config('request.jwt.claims','{}',true);
 -- Emulate elapsed hold time, retaining original deadline for exact audit.
 UPDATE public.orders SET delivery_hold=delivery_hold||jsonb_build_object('state','holding','started_at',clock_timestamp()-interval '40 minutes','until',clock_timestamp()-interval '10 minutes') WHERE id=old_id;
 UPDATE public.drivers SET current_lat=10.8,current_lng=106.72,location_updated_at=clock_timestamp() WHERE user_id=d;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
 BEGIN PERFORM public.request_recipient_hold_return(old_id); RAISE EXCEPTION 'return from wrong location allowed';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'DELIVERY_OUTSIDE_GEOFENCE' THEN RAISE; END IF; END;
 PERFORM set_config('request.jwt.claims','{}',true);
 UPDATE public.drivers SET current_lat=10.79,current_lng=106.71,location_updated_at=clock_timestamp()-interval '2 minutes' WHERE user_id=d;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
 BEGIN PERFORM public.request_recipient_hold_return(old_id); RAISE EXCEPTION 'stale arrival allowed';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'DELIVERY_LOCATION_STALE' THEN RAISE; END IF; END;
 PERFORM set_config('request.jwt.claims','{}',true);
 UPDATE public.drivers SET location_updated_at=clock_timestamp() WHERE user_id=d;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
 rid:=public.request_recipient_hold_return(old_id);
 IF public.request_recipient_hold_return(old_id)<>rid THEN RAISE EXCEPTION 'return retry duplicated case'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.risk_reports WHERE id=rid AND order_id=old_id) THEN RAISE EXCEPTION 'return report missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.risk_report_interventions WHERE risk_report_id=rid AND state='awaiting_triage') THEN RAISE EXCEPTION 'support intervention missing'; END IF;
END; $$;
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK;
