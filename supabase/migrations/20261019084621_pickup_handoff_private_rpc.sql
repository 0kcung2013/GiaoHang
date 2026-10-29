-- Follow the established private-command / public invoker RPC pattern.
ALTER FUNCTION public.get_customer_pickup_code(uuid) SET SCHEMA private;
ALTER FUNCTION public.confirm_driver_pickup_code(uuid,text) SET SCHEMA private;

CREATE OR REPLACE FUNCTION private.get_customer_pickup_code(p_order_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_meta jsonb;
  v_now timestamptz := clock_timestamp();
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  v_now := clock_timestamp();
  IF NOT FOUND OR v_order.customer_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'ORDER_NOT_OWNED' USING ERRCODE = '42501';
  END IF;
  IF v_order.actual_picked_up_at IS NOT NULL THEN
    RETURN jsonb_build_object('confirmed_at',v_order.actual_picked_up_at,'server_now',v_now);
  END IF;
  IF v_order.driver_id IS NULL OR v_order.status NOT IN ('assigned','picking_up') THEN
    RAISE EXCEPTION 'PICKUP_CODE_UNAVAILABLE';
  END IF;
  v_meta := v_order.pickup_handoff;
  IF v_meta->>'nonce' IS NULL OR (v_meta->>'expires_at')::timestamptz <= v_now
    OR v_meta->>'driver_id' IS DISTINCT FROM v_order.driver_id::text THEN
    v_meta := jsonb_build_object('nonce',gen_random_uuid(),
      'driver_id',v_order.driver_id,'customer_id',v_actor,'issued_at',v_now,
      'expires_at',v_now + interval '15 minutes',
      'failed_attempts',COALESCE((v_meta->>'failed_attempts')::integer,0),
      'locked_until',v_meta->'locked_until');
    UPDATE public.orders SET pickup_handoff = v_meta WHERE id = p_order_id;
  END IF;
  RETURN jsonb_build_object('code', private.pickup_handoff_code(v_order.id,v_actor,
    v_order.driver_id,v_meta->>'nonce'), 'expires_at',v_meta->'expires_at',
    'driver_id',v_order.driver_id,'server_now',v_now);
END;
$function$;

CREATE OR REPLACE FUNCTION private.confirm_driver_pickup_code(p_order_id uuid, p_code text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_meta jsonb;
  v_now timestamptz := clock_timestamp();
  v_attempts integer;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_actor AND role = 'driver') THEN
    RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED';
  END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  v_now := clock_timestamp();
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.driver_id IS DISTINCT FROM v_actor THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED'; END IF;
  IF v_order.actual_picked_up_at IS NOT NULL AND v_order.status = 'delivering' THEN
    RETURN jsonb_build_object('success',true,'confirmed_at',v_order.actual_picked_up_at,
      'new_status','delivering','server_now',v_now);
  END IF;
  IF v_order.status <> 'picking_up' THEN RAISE EXCEPTION 'ORDER_NOT_PICKING_UP'; END IF;
  v_meta := v_order.pickup_handoff;
  IF (v_meta->>'locked_until')::timestamptz > v_now THEN
    RETURN jsonb_build_object('success',false,'error','PICKUP_CODE_LOCKED',
      'locked_until',v_meta->'locked_until','server_now',v_now);
  END IF;
  IF v_meta->>'nonce' IS NULL OR (v_meta->>'expires_at')::timestamptz <= v_now
    OR v_meta->>'driver_id' IS DISTINCT FROM v_actor::text THEN
    RETURN jsonb_build_object('success',false,'error','PICKUP_CODE_EXPIRED','server_now',v_now);
  END IF;
  IF p_code IS NULL OR p_code !~ '^[0-9]{4}$' OR p_code IS DISTINCT FROM
    private.pickup_handoff_code(v_order.id,v_order.customer_id,v_actor,v_meta->>'nonce') THEN
    v_attempts := CASE WHEN v_meta->>'locked_until' IS NOT NULL THEN 0
      ELSE COALESCE((v_meta->>'failed_attempts')::integer,0) END + 1;
    v_meta := v_meta || jsonb_build_object('failed_attempts',v_attempts,
      'locked_until',CASE WHEN v_attempts >= 5 THEN v_now + interval '5 minutes' ELSE NULL END);
    UPDATE public.orders SET pickup_handoff = v_meta WHERE id = p_order_id;
    -- Return a domain error, rather than raising and rolling back the attempt.
    RETURN jsonb_build_object('success',false,'error',CASE WHEN v_attempts >= 5
      THEN 'PICKUP_CODE_LOCKED' ELSE 'PICKUP_CODE_INVALID' END,
      'attempts_remaining',greatest(0,5-v_attempts),
      'locked_until',v_meta->'locked_until','server_now',v_now);
  END IF;
  IF EXISTS (SELECT 1 FROM public.risk_report_interventions WHERE order_id = v_order.id
    AND driver_id = v_actor AND state IN ('return_required','handoff_required')) THEN
    RAISE EXCEPTION 'CUSTODY_ACTION_REQUIRED';
  END IF;
  IF EXISTS (SELECT 1 FROM public.risk_reports report
    JOIN public.risk_report_interventions intervention ON intervention.risk_report_id = report.id
    WHERE report.order_id = v_order.id AND report.category = 'cargo_issue'
      AND report.reporter_role_snapshot = 'driver' AND report.reported_by = v_actor
      AND report.status NOT IN ('resolved','dismissed') AND intervention.driver_id = v_actor
      AND intervention.state = 'awaiting_triage') THEN
    RAISE EXCEPTION 'PICKUP_INCIDENT_PENDING' USING ERRCODE = '23514';
  END IF;
  PERFORM private.hold_paid_goods_deposit(v_order,v_actor);
  UPDATE public.orders SET actual_picked_up_at = v_now,
    pickup_handoff = jsonb_build_object('driver_id',v_actor,'customer_id',v_order.customer_id,
      'confirmed_at',v_now,'method','customer_code'), updated_at = v_now
    WHERE id = p_order_id;
  -- Existing geofence, proof, wallet and incident guards still run. Any failure
  -- rolls back both the custody receipt and the transition/wallet effects.
  PERFORM public.advance_driver_order_status(p_order_id);
  INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
  VALUES (v_order.id,'delivering','Đã xác nhận bàn giao bằng mã',
    'Người tạo đơn đã cung cấp mã bàn giao. Tài xế xác nhận nhận hàng và chịu trách nhiệm giữ, giao hàng.',v_actor);
  RETURN jsonb_build_object('success',true,'confirmed_at',v_now,
    'new_status','delivering','server_now',v_now);
END;
$function$;

CREATE FUNCTION public.get_customer_pickup_code(p_order_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $function$
  SELECT private.get_customer_pickup_code(p_order_id);
$function$;
REVOKE ALL ON FUNCTION public.get_customer_pickup_code(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_customer_pickup_code(uuid) TO authenticated;

CREATE FUNCTION public.confirm_driver_pickup_code(p_order_id uuid,p_code text)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $function$
  SELECT private.confirm_driver_pickup_code(p_order_id,p_code);
$function$;
REVOKE ALL ON FUNCTION public.confirm_driver_pickup_code(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.confirm_driver_pickup_code(uuid,text) TO authenticated;
