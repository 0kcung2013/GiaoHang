-- Public metadata contains no PIN/hash. A Vault-only HMAC key derives the PIN;
-- exposing SELECT * / Realtime orders therefore does not expose the code.
ALTER TABLE public.orders ADD COLUMN pickup_handoff jsonb NOT NULL DEFAULT '{}'::jsonb;
COMMENT ON COLUMN public.orders.pickup_handoff IS
  'Server-owned pickup challenge metadata and custody receipt; never stores the PIN.';

DO $migration$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'pickup_handoff_hmac_key') THEN
    PERFORM vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'),
      'pickup_handoff_hmac_key', 'Server-only key for order pickup confirmation codes');
  END IF;
END;
$migration$;

CREATE FUNCTION private.pickup_handoff_code(p_order_id uuid, p_customer_id uuid,
  p_driver_id uuid, p_nonce text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_key text;
  v_digest bytea;
BEGIN
  SELECT decrypted_secret INTO STRICT v_key FROM vault.decrypted_secrets
    WHERE name = 'pickup_handoff_hmac_key';
  v_digest := extensions.hmac(p_order_id::text || ':' || p_customer_id::text || ':' ||
    p_driver_id::text || ':' || p_nonce, v_key, 'sha256');
  RETURN lpad(((get_byte(v_digest,0)::bigint * 16777216 +
    get_byte(v_digest,1)::bigint * 65536 + get_byte(v_digest,2)::bigint * 256 +
    get_byte(v_digest,3)::bigint) % 10000)::text, 4, '0');
END;
$function$;
REVOKE ALL ON FUNCTION private.pickup_handoff_code(uuid,uuid,uuid,text)
  FROM PUBLIC, anon, authenticated;

-- Invoker security deliberately distinguishes direct client writes from the
-- narrowly authorized SECURITY DEFINER commands below.
CREATE FUNCTION private.guard_pickup_handoff()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $function$
DECLARE
  v_authorized_handoff boolean := false;
BEGIN
  IF current_user IN ('anon','authenticated') THEN
    IF (TG_OP = 'INSERT' AND NEW.pickup_handoff <> '{}'::jsonb)
      OR (TG_OP = 'UPDATE' AND NEW.pickup_handoff IS DISTINCT FROM OLD.pickup_handoff) THEN
      RAISE EXCEPTION 'PICKUP_HANDOFF_SERVER_OWNED' USING ERRCODE = '42501';
    END IF;
    IF (TG_OP = 'INSERT' AND (NEW.actual_picked_up_at IS NOT NULL OR
          NEW.status NOT IN ('pending','confirmed')))
      OR (TG_OP = 'UPDATE' AND NEW.actual_picked_up_at IS DISTINCT FROM OLD.actual_picked_up_at) THEN
      RAISE EXCEPTION 'PICKUP_CODE_REQUIRED' USING ERRCODE = '42501';
    END IF;
    IF TG_OP = 'UPDATE' AND NEW.customer_id IS DISTINCT FROM OLD.customer_id THEN
      RAISE EXCEPTION 'ORDER_CUSTOMER_IMMUTABLE' USING ERRCODE = '42501';
    END IF;
  END IF;
  IF TG_OP = 'INSERT' THEN RETURN NEW; END IF;

  IF OLD.actual_picked_up_at IS NOT NULL THEN
    -- Only the existing staff-authorized physical handoff can release custody.
    SELECT EXISTS (SELECT 1 FROM public.risk_report_interventions intervention
      JOIN public.users actor ON actor.id = auth.uid()
      WHERE intervention.order_id = OLD.id AND intervention.driver_id = OLD.driver_id
        AND intervention.state = 'handoff_required' AND actor.role IN ('support','admin')
        AND NEW.status = 'risk_hold' AND NEW.driver_id IS NULL)
      INTO v_authorized_handoff;
    IF NOT v_authorized_handoff AND (
      NEW.driver_id IS DISTINCT FROM OLD.driver_id OR NEW.actual_picked_up_at IS NULL
      OR NEW.status IN ('pending','confirmed','assigned','cancelled')
      OR (NEW.status = 'picking_up' AND OLD.status <> 'picking_up')) THEN
      RAISE EXCEPTION 'ORDER_ALREADY_PICKED_UP' USING ERRCODE = '23514';
    END IF;
  END IF;

  IF NEW.driver_id IS DISTINCT FROM OLD.driver_id THEN
    NEW.pickup_handoff := '{}'::jsonb;
  END IF;
  IF OLD.actual_picked_up_at IS NULL AND (
    NEW.actual_picked_up_at IS NOT NULL OR
    (OLD.status IN ('pending','confirmed','assigned','picking_up')
      AND NEW.status IN ('delivering','delivered','return_approved','returning','returned'))
  ) THEN
    IF NEW.pickup_handoff->>'confirmed_at' IS NULL
      OR NEW.pickup_handoff->>'driver_id' IS DISTINCT FROM NEW.driver_id::text
      OR NEW.pickup_handoff->>'customer_id' IS DISTINCT FROM NEW.customer_id::text THEN
      RAISE EXCEPTION 'PICKUP_CODE_REQUIRED' USING ERRCODE = '23514';
    END IF;
  END IF;
  -- A terminal/cancelled assignment must not retain a usable challenge.
  IF NEW.status IN ('cancelled','pending','confirmed') AND NEW.actual_picked_up_at IS NULL THEN
    NEW.pickup_handoff := '{}'::jsonb;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.guard_pickup_handoff() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER orders_01_guard_pickup_handoff BEFORE INSERT OR UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION private.guard_pickup_handoff();

CREATE FUNCTION public.get_customer_pickup_code(p_order_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_meta jsonb;
  v_now timestamptz := clock_timestamp();
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
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
REVOKE ALL ON FUNCTION public.get_customer_pickup_code(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customer_pickup_code(uuid) TO authenticated;

-- Retain the old RPC solely for recovery of an already committed handoff.
-- Old clients cannot create custody with a photo alone.
CREATE OR REPLACE FUNCTION public.confirm_driver_pickup(p_order_id uuid)
RETURNS timestamptz LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_order public.orders%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_actor AND role = 'driver') THEN
    RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED';
  END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.driver_id IS DISTINCT FROM v_actor THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED'; END IF;
  IF v_order.status NOT IN ('picking_up','delivering') THEN RAISE EXCEPTION 'ORDER_NOT_PICKING_UP'; END IF;
  IF v_order.actual_picked_up_at IS NULL THEN RAISE EXCEPTION 'PICKUP_CODE_REQUIRED'; END IF;
  RETURN v_order.actual_picked_up_at;
END;
$function$;

CREATE FUNCTION public.confirm_driver_pickup_code(p_order_id uuid, p_code text)
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
REVOKE ALL ON FUNCTION public.confirm_driver_pickup_code(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_driver_pickup_code(uuid,text) TO authenticated;
