-- Require the explicit arrival swipe recorded by confirm_driver_delivery_arrival.
-- GPS geofence alone must not allow starting a recipient hold.
CREATE OR REPLACE FUNCTION public.set_driver_recipient_hold(p_order_id uuid, p_minutes integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE actor uuid:=auth.uid(); o public.orders%ROWTYPE; d public.drivers%ROWTYPE;
 t timestamptz:=clock_timestamp(); h jsonb; finish_at timestamptz;
BEGIN
 IF actor IS NULL OR NOT EXISTS(SELECT 1 FROM public.users WHERE id=actor AND role='driver')
 THEN RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED' USING ERRCODE='42501'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor::text,0));
 SELECT * INTO o FROM public.orders WHERE id=p_order_id FOR UPDATE;
 IF NOT FOUND OR o.driver_id IS DISTINCT FROM actor THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED' USING ERRCODE='42501'; END IF;
 IF o.status<>'delivering' THEN RAISE EXCEPTION 'HOLD_INVALID_STATUS'; END IF;
 IF EXISTS(SELECT 1 FROM public.risk_report_interventions WHERE order_id=o.id
   AND state IN ('awaiting_triage','return_required','handoff_required')) THEN RAISE EXCEPTION 'HOLD_SUPPORT_ACTION_PENDING'; END IF;
 h:=o.delivery_hold;
 IF p_minutes IS NOT NULL THEN
   IF p_minutes<1 OR p_minutes>60 THEN RAISE EXCEPTION 'HOLD_DURATION_INVALID'; END IF;
   IF private.is_recipient_hold(h) THEN RETURN jsonb_build_object('order',to_jsonb(o),'server_now',t); END IF;
   IF h IS NOT NULL THEN RAISE EXCEPTION 'HOLD_ALREADY_USED'; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.order_status_logs
     WHERE order_id=o.id AND logged_by=actor AND title='Tài xế đã đến điểm giao') THEN
     RAISE EXCEPTION 'DELIVERY_ARRIVAL_REQUIRED' USING ERRCODE='23514';
   END IF;
   IF EXISTS(SELECT 1 FROM public.orders WHERE driver_id=actor AND id<>o.id
     AND status IN ('assigned','picking_up','delivering','return_approved','returning')) THEN RAISE EXCEPTION 'HOLD_OTHER_ORDER_ACTIVE'; END IF;
   SELECT * INTO d FROM public.drivers WHERE user_id=actor;
   IF d.location_updated_at IS NULL OR d.location_updated_at<t-interval '60 seconds'
     OR d.location_updated_at>t+interval '5 seconds' OR d.current_lat IS NULL OR d.current_lng IS NULL
   THEN RAISE EXCEPTION 'DELIVERY_LOCATION_STALE'; END IF;
   IF NOT public.ST_DWithin(public.ST_SetSRID(public.ST_MakePoint(d.current_lng,d.current_lat),4326)::public.geography,
     public.ST_SetSRID(public.ST_MakePoint(o.delivery_lng,o.delivery_lat),4326)::public.geography,100)
   THEN RAISE EXCEPTION 'DELIVERY_OUTSIDE_GEOFENCE'; END IF;
   h:=jsonb_build_object('state','holding','started_at',t,'until',t+make_interval(mins=>p_minutes),
     'original_deadline',o.estimated_delivery_at,'fee_mode','participant_agreement');
   UPDATE public.orders SET delivery_hold=h,estimated_delivery_at=estimated_delivery_at+make_interval(mins=>p_minutes+5)
    WHERE id=o.id RETURNING * INTO o;
   INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
    VALUES(o.id,o.status,'Khách hẹn giao lại sau',h::text,actor);
   INSERT INTO public.notifications(user_id,title,body,type,is_read,order_id)
    VALUES(o.customer_id,'Khách hẹn giao lại sau',format('Tài xế giữ hàng, hẹn giao lại lúc %s. Phí đợi do tài xế và người nhận thỏa thuận.',
      to_char((h->>'until')::timestamptz AT TIME ZONE 'Asia/Ho_Chi_Minh','HH24:MI')),'system',false,o.id);
 ELSE
   IF NOT private.is_recipient_hold(h) THEN RETURN jsonb_build_object('order',to_jsonb(o),'server_now',t); END IF;
   IF EXISTS(SELECT 1 FROM public.orders WHERE driver_id=actor AND id<>o.id
    AND status IN ('assigned','picking_up','delivering','return_approved','returning')
    AND NOT private.is_recipient_hold(delivery_hold)) THEN RAISE EXCEPTION 'HOLD_OTHER_ORDER_ACTIVE'; END IF;
   finish_at:=least(t,(h->>'until')::timestamptz+interval '5 minutes');
   UPDATE public.orders SET delivery_hold=h||jsonb_build_object('state','resumed','ended_at',t),
    estimated_delivery_at=(h->>'original_deadline')::timestamptz+greatest(interval '0',finish_at-(h->>'started_at')::timestamptz)
    WHERE id=o.id RETURNING * INTO o;
   INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
    VALUES(o.id,o.status,'Tiếp tục giao đơn đang giữ',o.delivery_hold::text,actor);
 END IF;
 RETURN jsonb_build_object('order',to_jsonb(o),'server_now',clock_timestamp());
END; $function$
;

