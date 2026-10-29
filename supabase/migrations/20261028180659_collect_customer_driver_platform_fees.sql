-- Actual fee collection. Existing orders/payment sessions keep their policy.
-- Rollout is appended after all functions: only new policies collect fees.
-- No new tables: explicit customer snapshot columns complement the existing driver fees.
ALTER TABLE public.orders
 ADD COLUMN customer_platform_fee_rate_bps integer NOT NULL DEFAULT 0 CHECK(customer_platform_fee_rate_bps BETWEEN 0 AND 10000),
 ADD COLUMN customer_platform_fee_amount bigint NOT NULL DEFAULT 0 CHECK(customer_platform_fee_amount>=0);
ALTER TABLE public.driver_wallet_transactions DROP CONSTRAINT driver_wallet_transactions_transaction_type_check;
ALTER TABLE public.driver_wallet_transactions ADD CONSTRAINT driver_wallet_transactions_transaction_type_check CHECK(transaction_type IN
 ('vnpay_topup','cod_hold','cod_release','cod_advance_capture','platform_fee_capture','customer_platform_fee_capture',
  'prepaid_earning','cod_settlement','return_delivery_earning','return_earning'));
-- A verified late VNPAY receipt can be refunded even when no order was activated.
ALTER TABLE public.customer_wallet_transactions ALTER COLUMN order_id DROP NOT NULL,
 ADD COLUMN payment_session_id uuid REFERENCES public.order_payment_sessions(id) ON DELETE RESTRICT,
 ADD CONSTRAINT customer_wallet_payment_reference CHECK(order_id IS NOT NULL OR payment_session_id IS NOT NULL);
CREATE INDEX customer_wallet_payment_session_idx ON public.customer_wallet_transactions(payment_session_id) WHERE payment_session_id IS NOT NULL;

CREATE FUNCTION private.order_fee_policy(p_customer_id uuid,p_policy jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE kind text;
BEGIN
 IF p_policy->>'platform_fee_version' IS DISTINCT FROM '1' THEN RETURN p_policy; END IF;
 IF p_policy ? 'customer_type' THEN RETURN p_policy; END IF;
 SELECT COALESCE(customer_type,'individual') INTO kind FROM public.users WHERE id=p_customer_id AND role='customer';
 IF kind IS NULL THEN RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED'; END IF;
 RETURN p_policy||jsonb_build_object('customer_type',kind);
END;
$fn$;
CREATE FUNCTION private.customer_platform_fee(p_delivery_fee numeric,p_policy jsonb) RETURNS bigint
LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT CASE WHEN p_policy->>'platform_fee_version'='1' THEN
 round(p_delivery_fee*COALESCE((p_policy->'values'->>CASE WHEN p_policy->>'customer_type'='business'
 THEN 'customer_business_fee_bps' ELSE 'customer_individual_fee_bps' END)::numeric,0)/10000)::bigint ELSE 0 END;
$fn$;
CREATE FUNCTION private.driver_platform_fee(p_delivery_fee numeric,p_policy jsonb) RETURNS bigint
LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT CASE WHEN p_policy->>'platform_fee_version'='1' THEN
 round(p_delivery_fee*COALESCE((p_policy->'values'->>'driver_platform_fee_bps')::numeric,0)/10000)::bigint ELSE 0 END;
$fn$;
CREATE FUNCTION private.validate_platform_fee_quote(p_payload jsonb,p_policy jsonb) RETURNS void
LANGUAGE plpgsql SET search_path='' AS $fn$
DECLARE amount bigint:=private.customer_platform_fee((p_payload->>'delivery_fee')::numeric,p_policy);
BEGIN
 IF p_policy->>'platform_fee_version' IS DISTINCT FROM '1' THEN RETURN; END IF;
 IF NOT p_payload ? 'quoted_customer_fee' AND amount=0 THEN RETURN; END IF;
 IF jsonb_typeof(p_payload->'quoted_customer_fee') IS DISTINCT FROM 'number'
   OR (p_payload->>'quoted_customer_fee')::numeric IS DISTINCT FROM amount::numeric THEN
   RAISE EXCEPTION 'SETTINGS_QUOTE_FEE_MISMATCH' USING ERRCODE='22023'; END IF;
END;
$fn$;
REVOKE ALL ON FUNCTION private.order_fee_policy(uuid,jsonb),private.customer_platform_fee(numeric,jsonb),
 private.driver_platform_fee(numeric,jsonb),private.validate_platform_fee_quote(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION private.create_customer_order_with_policy(p_customer_id uuid, p_order_payload jsonb, p_payment_status text, p_paid_at timestamp with time zone, p_policy jsonb)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_order public.orders%ROWTYPE;
  v_policy jsonb := private.order_fee_policy(p_customer_id,COALESCE(p_policy,private.current_business_settings()));
  v_traffic_demo_key text := NULLIF(p_order_payload->>'traffic_demo_key', '');
  v_item_weight_kg numeric;
  v_pickup_address text := NULLIF(btrim(p_order_payload->>'pickup_address'), '');
  v_delivery_address text := NULLIF(btrim(p_order_payload->>'delivery_address'), '');
  v_item_name text := NULLIF(btrim(p_order_payload->>'item_name'), '');
  v_service_type text;
  v_fee_payer text;
  v_payment_method text;
  v_payment_mode text;
  v_delivery_fee bigint;
  v_goods_value bigint;
  v_cod_amount bigint;
  v_receiver_amount bigint;
  v_paid_goods_deposit boolean;
  v_estimated_pickup_at timestamptz;
  v_estimated_delivery_at timestamptz;
BEGIN
  IF v_traffic_demo_key IS NOT NULL AND v_traffic_demo_key NOT IN ('peak', 'off_peak') THEN
    RAISE EXCEPTION 'TRAFFIC_DEMO_INVALID';
  END IF;
  IF p_customer_id IS NULL THEN RAISE EXCEPTION 'CUSTOMER_ID_REQUIRED'; END IF;
  IF p_order_payload IS NULL OR jsonb_typeof(p_order_payload) <> 'object' THEN
    RAISE EXCEPTION 'ORDER_PAYLOAD_INVALID';
  END IF;
  IF v_pickup_address IS NULL OR v_delivery_address IS NULL THEN
    RAISE EXCEPTION 'ORDER_ADDRESS_REQUIRED';
  END IF;
  IF p_payment_status NOT IN ('not_required', 'paid') THEN
    RAISE EXCEPTION 'ORDER_PAYMENT_STATUS_INVALID';
  END IF;

  PERFORM private.validate_business_order_quote(p_order_payload,v_policy);
  PERFORM private.validate_platform_fee_quote(p_order_payload,v_policy);
  BEGIN
    v_item_weight_kg := NULLIF(btrim(p_order_payload->>'item_weight_kg'), '')::numeric;
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RAISE EXCEPTION 'ITEM_WEIGHT_INVALID' USING ERRCODE = '23514';
  END;
  IF v_item_weight_kg IS NOT NULL AND NOT (
    v_item_weight_kg > 0 AND v_item_weight_kg < 'Infinity'::numeric
    AND v_item_weight_kg = trunc(v_item_weight_kg, 3)
  ) THEN
    RAISE EXCEPTION 'ITEM_WEIGHT_INVALID' USING ERRCODE = '23514';
  END IF;

  BEGIN
    IF (p_order_payload->>'pickup_lat')::double precision IS NULL
       OR (p_order_payload->>'pickup_lng')::double precision IS NULL
       OR (p_order_payload->>'delivery_lat')::double precision IS NULL
       OR (p_order_payload->>'delivery_lng')::double precision IS NULL THEN
      RAISE EXCEPTION 'ORDER_COORDINATES_REQUIRED';
    END IF;
    v_delivery_fee := round((p_order_payload->>'delivery_fee')::numeric)::bigint;
    v_goods_value := round(COALESCE(
      NULLIF(p_order_payload->>'goods_value', '')::numeric, 0
    ))::bigint;
    v_cod_amount := round(COALESCE(
      NULLIF(p_order_payload->>'cod_collection_amount', '')::numeric, 0
    ))::bigint;
    v_estimated_pickup_at := NULLIF(
      p_order_payload->>'estimated_pickup_at', ''
    )::timestamptz;
    v_estimated_delivery_at := NULLIF(
      p_order_payload->>'estimated_delivery_at', ''
    )::timestamptz;
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RAISE EXCEPTION 'ORDER_PAYLOAD_INVALID';
  END;

  IF v_delivery_fee IS NULL
     OR v_delivery_fee < 0 OR v_delivery_fee > 10000000
     OR v_goods_value < 0 OR v_goods_value > private.business_number(v_policy,'max_goods_value')
     OR v_cod_amount < 0 OR v_cod_amount > private.business_number(v_policy,'max_cod') THEN
    RAISE EXCEPTION 'ORDER_PRICE_INVALID';
  END IF;

  v_fee_payer := lower(COALESCE(
    NULLIF(btrim(p_order_payload->>'delivery_fee_payer'), ''), 'recipient'
  ));
  IF v_fee_payer NOT IN ('sender', 'recipient') THEN
    RAISE EXCEPTION 'DELIVERY_FEE_PAYER_INVALID';
  END IF;
  IF v_fee_payer = 'sender' AND p_payment_status <> 'paid' THEN
    RAISE EXCEPTION 'ORDER_PAYMENT_REQUIRED';
  END IF;
  IF v_fee_payer = 'recipient' AND p_payment_status <> 'not_required' THEN
    RAISE EXCEPTION 'ORDER_PAYMENT_NOT_REQUIRED';
  END IF;

  v_paid_goods_deposit := v_fee_payer = 'sender' AND v_cod_amount = 0
    AND p_order_payload->>'paid_goods_deposit_version' = '1';
  IF v_paid_goods_deposit AND (v_goods_value <= 0 OR v_goods_value > private.business_number(v_policy,'max_paid_goods_value')) THEN
    RAISE EXCEPTION 'PAID_GOODS_VALUE_REQUIRED';
  END IF;

  v_service_type := CASE
    WHEN p_order_payload->>'service_type' = 'bulky' THEN 'fragile'
    WHEN p_order_payload->>'service_type' IN (
      'standard', 'express', 'fragile', 'document'
    ) THEN p_order_payload->>'service_type'
    ELSE 'standard'
  END;
  v_payment_method := CASE WHEN v_fee_payer = 'sender' THEN 'vnpay' ELSE 'cash' END;
  v_payment_mode := CASE WHEN v_fee_payer = 'sender' THEN 'prepaid' ELSE 'cod' END;
  v_receiver_amount := v_cod_amount + CASE
    WHEN v_fee_payer = 'recipient' THEN v_delivery_fee ELSE 0 END;

  INSERT INTO public.orders (
    business_policy, traffic_demo_key, customer_id, status, pickup_address, pickup_lat, pickup_lng,
    delivery_address, delivery_lat, delivery_lng, total_price, note,
    estimated_pickup_at, estimated_delivery_at, recipient_name,
    recipient_phone, delivery_fee, service_type, payment_method, item_name,
    item_category, item_description, item_image_url, item_weight_kg, payment_mode,
    delivery_fee_payer, payment_status, paid_at, goods_value,
    cod_collection_amount, platform_fee_rate_bps, platform_fee_amount,
    driver_net_earning, driver_advance_amount, receiver_collection_amount
  ) VALUES (
    v_policy, v_traffic_demo_key, p_customer_id, 'pending'::public.order_status,
    v_pickup_address,
    (p_order_payload->>'pickup_lat')::double precision,
    (p_order_payload->>'pickup_lng')::double precision,
    v_delivery_address,
    (p_order_payload->>'delivery_lat')::double precision,
    (p_order_payload->>'delivery_lng')::double precision,
    v_delivery_fee + v_cod_amount,
    NULLIF(btrim(p_order_payload->>'note'), ''),
    v_estimated_pickup_at, v_estimated_delivery_at,
    NULLIF(btrim(p_order_payload->>'recipient_name'), ''),
    NULLIF(btrim(p_order_payload->>'recipient_phone'), ''),
    v_delivery_fee, v_service_type, v_payment_method, v_item_name,
    NULLIF(btrim(p_order_payload->>'item_category'), ''),
    NULLIF(btrim(p_order_payload->>'item_description'), ''),
    NULLIF(btrim(p_order_payload->>'item_image_url'), ''),
    v_item_weight_kg, v_payment_mode, v_fee_payer, p_payment_status, p_paid_at,
    v_goods_value, v_cod_amount, 0, 0, v_delivery_fee,
    CASE WHEN v_paid_goods_deposit THEN v_goods_value ELSE v_cod_amount END,
    v_receiver_amount
  ) RETURNING * INTO v_order;

  IF v_item_name IS NOT NULL THEN
    INSERT INTO public.order_items (order_id, name, quantity, price)
    VALUES (v_order.id, v_item_name, 1, v_goods_value);
  END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    v_order.id, 'pending'::public.order_status, 'Đã tạo đơn',
    CASE WHEN v_fee_payer = 'sender'
      THEN 'Phí giao hàng đã được thanh toán qua VNPAY. Đơn đang chờ tài xế nhận.'
      ELSE 'Đơn hàng đã được ghi nhận và đang chờ tài xế nhận.' END,
    p_customer_id
  );

  RETURN v_order;
END;
$function$;


CREATE OR REPLACE FUNCTION private.create_customer_order_with_wallet(p_order_payload jsonb, p_request_id uuid)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_customer_id uuid := auth.uid();
  v_policy jsonb := private.order_fee_policy(auth.uid(),private.current_business_settings());
  v_order public.orders%ROWTYPE;
  v_existing public.customer_wallet_transactions%ROWTYPE;
  v_payload jsonb;
  v_key text;
  v_amount bigint;
  v_balance bigint;
BEGIN
  IF v_customer_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_customer_id AND role = 'customer') THEN
    RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED';
  END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'WALLET_REQUEST_ID_REQUIRED'; END IF;
  IF p_order_payload IS NULL OR jsonb_typeof(p_order_payload) <> 'object' THEN
    RAISE EXCEPTION 'ORDER_PAYLOAD_INVALID';
  END IF;
  IF p_order_payload->>'delivery_fee_payer' IS DISTINCT FROM 'sender'
    OR COALESCE((p_order_payload->>'cod_collection_amount')::numeric, 0) <> 0 THEN
    RAISE EXCEPTION 'WALLET_PAYMENT_NOT_REQUIRED';
  END IF;
  v_payload := (p_order_payload - ARRAY['customer_id', 'payment_method', 'payment_status',
      'paid_at', 'paid_goods_deposit_version']) || jsonb_build_object(
    'delivery_fee_payer', 'sender', 'cod_collection_amount', 0, 'paid_goods_deposit_version', 1);
  v_key := 'customer:' || v_customer_id::text || ':delivery-payment:' || p_request_id::text;

  -- All customer debits use this namespace. A lost response reuses the same key.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('customer-wallet:' || v_customer_id::text, 0));
  SELECT * INTO v_existing FROM public.customer_wallet_transactions WHERE idempotency_key = v_key;
  IF FOUND THEN
    IF v_existing.metadata->'order_payload' IS DISTINCT FROM v_payload THEN
      RAISE EXCEPTION 'WALLET_REQUEST_PAYLOAD_MISMATCH';
    END IF;
    -- Do not lock this row while holding the wallet lock: cancellation locks order first.
    SELECT * INTO STRICT v_order FROM public.orders WHERE id = v_existing.order_id;
    RETURN v_order;
  END IF;
  v_amount := round((v_payload->>'delivery_fee')::numeric)::bigint;
  IF v_amount IS NULL OR v_amount < 5000 OR v_amount > 10000000 THEN
    RAISE EXCEPTION 'ORDER_PRICE_INVALID';
  END IF;
  v_amount := v_amount + private.customer_platform_fee(v_amount,v_policy);
  SELECT COALESCE(sum(available_delta), 0)::bigint INTO v_balance
  FROM public.customer_wallet_transactions WHERE customer_id = v_customer_id AND status = 'completed';
  IF v_balance < v_amount THEN RAISE EXCEPTION 'CUSTOMER_WALLET_INSUFFICIENT_BALANCE'; END IF;

  -- The trusted helper retains goods deposit, ETA, cargo and dispatch contracts.
  SELECT * INTO v_order FROM private.create_customer_order_with_policy(
    v_customer_id, v_payload, 'paid', clock_timestamp(),v_policy);
  INSERT INTO public.customer_wallet_transactions(customer_id, order_id, transaction_type,
    amount, available_delta, idempotency_key, metadata)
  VALUES(v_customer_id, v_order.id, 'delivery_fee_payment', v_amount, -v_amount, v_key,
    jsonb_build_object('order_payload', v_payload, 'tracking_code', v_order.tracking_code,
      'payment_state', 'reserved'));
  UPDATE public.orders SET payment_method = 'wallet' WHERE id = v_order.id RETURNING * INTO v_order;
  UPDATE public.order_status_logs SET description =
    'Phí giao hàng đã được trừ từ Ví Khách Hàng. Đơn đang chờ tài xế nhận.'
  WHERE order_id = v_order.id AND status = 'pending' AND title = 'Đã tạo đơn';
  RETURN v_order;
END;
$function$;


CREATE OR REPLACE FUNCTION public.create_customer_order_payment_session(p_customer_id uuid, p_order_payload jsonb, p_txn_ref text)
 RETURNS TABLE(session_id uuid, txn_ref text, amount bigint, status text, expires_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_session public.order_payment_sessions%ROWTYPE;
  v_policy jsonb := private.order_fee_policy(p_customer_id,private.current_business_settings());
  v_item_weight_kg numeric;
  v_amount bigint;
  v_fee_payer text;
  v_cod_amount bigint;
  v_goods_value bigint;
BEGIN
  IF NULLIF(p_order_payload->>'traffic_demo_key', '') IS NOT NULL
     AND p_order_payload->>'traffic_demo_key' NOT IN ('peak', 'off_peak') THEN
    RAISE EXCEPTION 'TRAFFIC_DEMO_INVALID';
  END IF;
  IF p_customer_id IS NULL THEN RAISE EXCEPTION 'CUSTOMER_ID_REQUIRED'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users app_user
    WHERE app_user.id = p_customer_id
      AND app_user.role = 'customer'::public.user_role
  ) THEN RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED'; END IF;
  IF p_order_payload IS NULL OR jsonb_typeof(p_order_payload) <> 'object' THEN
    RAISE EXCEPTION 'ORDER_PAYLOAD_INVALID';
  END IF;
  IF NULLIF(btrim(p_txn_ref), '') IS NULL THEN
    RAISE EXCEPTION 'PAYMENT_TXN_REF_REQUIRED';
  END IF;

  PERFORM private.validate_business_order_quote(p_order_payload,v_policy);
  PERFORM private.validate_platform_fee_quote(p_order_payload,v_policy);
  BEGIN
    v_item_weight_kg := NULLIF(btrim(p_order_payload->>'item_weight_kg'), '')::numeric;
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RAISE EXCEPTION 'ITEM_WEIGHT_INVALID' USING ERRCODE = '23514';
  END;
  IF v_item_weight_kg IS NOT NULL AND NOT (
    v_item_weight_kg > 0 AND v_item_weight_kg < 'Infinity'::numeric
    AND v_item_weight_kg = trunc(v_item_weight_kg, 3)
  ) THEN
    RAISE EXCEPTION 'ITEM_WEIGHT_INVALID' USING ERRCODE = '23514';
  END IF;

  BEGIN
    v_amount := round((p_order_payload->>'delivery_fee')::numeric)::bigint;
    v_cod_amount := round(COALESCE(
      NULLIF(p_order_payload->>'cod_collection_amount', '')::numeric, 0
    ))::bigint;
    v_goods_value := round(COALESCE(
      NULLIF(p_order_payload->>'goods_value', '')::numeric, 0
    ))::bigint;
    PERFORM (p_order_payload->>'pickup_lat')::double precision;
    PERFORM (p_order_payload->>'pickup_lng')::double precision;
    PERFORM (p_order_payload->>'delivery_lat')::double precision;
    PERFORM (p_order_payload->>'delivery_lng')::double precision;
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RAISE EXCEPTION 'ORDER_PAYLOAD_INVALID';
  END;

  v_fee_payer := lower(COALESCE(
    NULLIF(btrim(p_order_payload->>'delivery_fee_payer'), ''), 'recipient'
  ));
  IF v_fee_payer <> 'sender' THEN RAISE EXCEPTION 'VNPAY_PAYMENT_NOT_REQUIRED'; END IF;
  IF NULLIF(btrim(p_order_payload->>'pickup_address'), '') IS NULL
     OR NULLIF(btrim(p_order_payload->>'delivery_address'), '') IS NULL THEN
    RAISE EXCEPTION 'ORDER_ADDRESS_REQUIRED';
  END IF;
  IF NULLIF(btrim(p_order_payload->>'pickup_lat'), '') IS NULL
     OR NULLIF(btrim(p_order_payload->>'pickup_lng'), '') IS NULL
     OR NULLIF(btrim(p_order_payload->>'delivery_lat'), '') IS NULL
     OR NULLIF(btrim(p_order_payload->>'delivery_lng'), '') IS NULL THEN
    RAISE EXCEPTION 'ORDER_COORDINATES_REQUIRED';
  END IF;
  IF v_amount IS NULL
     OR v_amount < 5000 OR v_amount > 10000000
     OR v_cod_amount < 0 OR v_cod_amount > private.business_number(v_policy,'max_cod')
     OR v_goods_value < 0 OR v_goods_value > private.business_number(v_policy,'max_goods_value') THEN
    RAISE EXCEPTION 'ORDER_PRICE_INVALID';
  END IF;

  -- Validate before taking a VNPAY payment, then store the server-owned policy
  -- marker in the existing session payload so older pending sessions still work.
  IF v_cod_amount = 0 AND (v_goods_value <= 0 OR v_goods_value > private.business_number(v_policy,'max_paid_goods_value')) THEN
    RAISE EXCEPTION 'PAID_GOODS_VALUE_REQUIRED';
  END IF;

  v_amount := v_amount + private.customer_platform_fee(v_amount,v_policy);
  INSERT INTO public.order_payment_sessions (
    customer_id, provider_txn_ref, amount, status,
    order_payload, expires_at
  ) VALUES (
    p_customer_id, btrim(p_txn_ref), v_amount, 'pending',
    (p_order_payload - 'paid_goods_deposit_version') || jsonb_build_object(
      '_business_policy',v_policy,
      'delivery_fee_payer', 'sender',
      'paid_goods_deposit_version', CASE WHEN v_cod_amount = 0 THEN 1 ELSE 0 END
    ),
    clock_timestamp() + interval '15 minutes'
  ) RETURNING * INTO v_session;

  RETURN QUERY SELECT v_session.id, v_session.provider_txn_ref,
    v_session.amount, v_session.status, v_session.expires_at;
END;
$function$;


CREATE OR REPLACE FUNCTION public.update_business_settings(p_values jsonb, p_expected_revision bigint, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE old_value jsonb; new_value jsonb; next_revision bigint; actor uuid:=auth.uid();
BEGIN
 IF actor IS NULL OR NOT EXISTS(SELECT 1 FROM public.users WHERE id=actor AND role='admin') THEN
   RAISE EXCEPTION 'ADMIN_ROLE_REQUIRED' USING ERRCODE='42501'; END IF;
 IF char_length(btrim(COALESCE(p_reason,''))) NOT BETWEEN 5 AND 500 THEN
   RAISE EXCEPTION 'SETTINGS_REASON_REQUIRED' USING ERRCODE='22023'; END IF;
 PERFORM private.validate_business_settings(p_values);
 SELECT value INTO STRICT old_value FROM public.system_settings WHERE key='business_settings' FOR UPDATE;
 IF p_expected_revision IS NULL OR p_expected_revision<>(old_value->>'revision')::bigint THEN
   RAISE EXCEPTION 'SETTINGS_CONFLICT' USING ERRCODE='40001'; END IF;
 IF old_value->'values'=p_values THEN RETURN old_value; END IF;
 next_revision:=(old_value->>'revision')::bigint+1;
 new_value:=jsonb_build_object('revision',next_revision,'values',p_values,'platform_fee_version',1);
 INSERT INTO public.system_settings(key,value,updated_by)
 VALUES('business_settings_revision:'||next_revision::text,
   new_value||jsonb_build_object('previous_values',old_value->'values','reason',btrim(p_reason)),actor);
 UPDATE public.system_settings SET value=new_value,updated_by=actor,updated_at=clock_timestamp()
 WHERE key='business_settings';
 RETURN new_value;
END;
$function$;

CREATE OR REPLACE FUNCTION public.complete_customer_order_payment(p_txn_ref text, p_vnp_transaction_no text, p_success boolean, p_response_code text)
 RETURNS TABLE(session_id uuid, order_id uuid, tracking_code text, status text, activated boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_session public.order_payment_sessions%ROWTYPE;
  v_order public.orders%ROWTYPE;
BEGIN
  SELECT * INTO v_session
  FROM public.order_payment_sessions session
  WHERE session.provider = 'vnpay'
    AND session.provider_txn_ref = btrim(p_txn_ref)
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PAYMENT_SESSION_NOT_FOUND'; END IF;

  -- A signed successful callback after expiry/failure is still real money.
  -- Credit the existing customer wallet without activating an expired order.
  IF p_success IS TRUE AND v_session.status IN ('pending','expired','failed')
     AND v_session.order_payload->'_business_policy'->>'platform_fee_version'='1'
     AND (v_session.expires_at<=clock_timestamp() OR v_session.status<>'pending') THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('customer-wallet:'||v_session.customer_id::text,0));
    INSERT INTO public.customer_wallet_transactions(customer_id,payment_session_id,
      transaction_type,amount,available_delta,idempotency_key,metadata)
    VALUES(v_session.customer_id,v_session.id,'delivery_fee_refund',v_session.amount,v_session.amount,
      'payment-session:'||v_session.id::text||':late-refund',
      jsonb_build_object('reason','late_vnpay_payment','provider_txn_ref',v_session.provider_txn_ref))
    ON CONFLICT(idempotency_key) DO NOTHING;
    UPDATE public.order_payment_sessions SET status='refunded',
      provider_transaction_no=NULLIF(btrim(p_vnp_transaction_no),''),
      provider_response_code=NULLIF(btrim(p_response_code),''),
      paid_at=clock_timestamp(),updated_at=clock_timestamp()
    WHERE id=v_session.id;
    RETURN QUERY SELECT v_session.id,NULL::uuid,NULL::text,'refunded'::text,false;
    RETURN;
  END IF;

  IF v_session.status = 'paid' THEN
    SELECT * INTO v_order FROM public.orders WHERE id = v_session.order_id;
    RETURN QUERY SELECT v_session.id, v_session.order_id,
      v_order.tracking_code, v_session.status, false;
    RETURN;
  END IF;
  IF v_session.status <> 'pending' THEN
    RETURN QUERY SELECT v_session.id, v_session.order_id,
      NULL::text, v_session.status, false;
    RETURN;
  END IF;

  IF p_success IS DISTINCT FROM true THEN
    UPDATE public.order_payment_sessions session
    SET status = 'failed',
      provider_transaction_no = NULLIF(btrim(p_vnp_transaction_no), ''),
      provider_response_code = NULLIF(btrim(p_response_code), ''),
      updated_at = clock_timestamp()
    WHERE session.id = v_session.id
    RETURNING * INTO v_session;
    RETURN QUERY SELECT v_session.id, NULL::uuid, NULL::text,
      v_session.status, false;
    RETURN;
  END IF;

  IF v_session.expires_at <= clock_timestamp() THEN
    UPDATE public.order_payment_sessions session
    SET status = 'refund_required',
      provider_transaction_no = NULLIF(btrim(p_vnp_transaction_no), ''),
      provider_response_code = NULLIF(btrim(p_response_code), ''),
      paid_at = clock_timestamp(), updated_at = clock_timestamp()
    WHERE session.id = v_session.id
    RETURNING * INTO v_session;
    RETURN QUERY SELECT v_session.id, NULL::uuid, NULL::text,
      v_session.status, false;
    RETURN;
  END IF;

  SELECT * INTO v_order
  FROM private.create_customer_order_with_policy(
    v_session.customer_id, v_session.order_payload, 'paid', clock_timestamp(),
    COALESCE(v_session.order_payload->'_business_policy',private.legacy_business_settings())
  );

  UPDATE public.order_payment_sessions session
  SET status = 'paid', order_id = v_order.id,
    provider_transaction_no = NULLIF(btrim(p_vnp_transaction_no), ''),
    provider_response_code = NULLIF(btrim(p_response_code), ''),
    paid_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE session.id = v_session.id
  RETURNING * INTO v_session;

  RETURN QUERY SELECT v_session.id, v_order.id, v_order.tracking_code,
    v_session.status, true;
END;
$function$;


CREATE FUNCTION private.guard_platform_fee_snapshot() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $fn$
DECLARE policy jsonb; customer_fee bigint; driver_fee bigint;
BEGIN
 IF TG_OP='INSERT' THEN
   IF NEW.business_policy->>'platform_fee_version' IS DISTINCT FROM '1' THEN RETURN NEW; END IF;
   IF current_user NOT IN ('postgres','service_role','supabase_admin') THEN
     RAISE EXCEPTION 'ORDER_FINANCE_COMMAND_REQUIRED' USING ERRCODE='42501'; END IF;
   policy:=private.order_fee_policy(NEW.customer_id,NEW.business_policy);
   customer_fee:=private.customer_platform_fee(NEW.delivery_fee,policy);
   driver_fee:=private.driver_platform_fee(NEW.delivery_fee,policy);
   NEW.business_policy:=policy;
   NEW.customer_platform_fee_rate_bps:=(policy->'values'->>CASE WHEN policy->>'customer_type'='business'
     THEN 'customer_business_fee_bps' ELSE 'customer_individual_fee_bps' END)::integer;
   NEW.customer_platform_fee_amount:=customer_fee;
   NEW.platform_fee_rate_bps:=(policy->'values'->>'driver_platform_fee_bps')::integer;
   NEW.platform_fee_amount:=driver_fee;
   NEW.driver_net_earning:=round(NEW.delivery_fee)::bigint-driver_fee;
   NEW.total_price:=NEW.delivery_fee+NEW.cod_collection_amount+customer_fee;
   NEW.receiver_collection_amount:=NEW.cod_collection_amount+CASE WHEN NEW.delivery_fee_payer='recipient'
     THEN round(NEW.delivery_fee)::bigint+customer_fee ELSE 0 END;
 ELSE
   IF OLD.business_policy->>'platform_fee_version' IS DISTINCT FROM '1' THEN RETURN NEW; END IF;
   IF ROW(NEW.customer_id,NEW.delivery_fee,NEW.total_price,NEW.cod_collection_amount,NEW.goods_value,
      NEW.driver_advance_amount,NEW.receiver_collection_amount,NEW.driver_net_earning,NEW.delivery_fee_payer,
      NEW.platform_fee_rate_bps,NEW.platform_fee_amount,NEW.customer_platform_fee_rate_bps,NEW.customer_platform_fee_amount)
     IS DISTINCT FROM ROW(OLD.customer_id,OLD.delivery_fee,OLD.total_price,OLD.cod_collection_amount,OLD.goods_value,
      OLD.driver_advance_amount,OLD.receiver_collection_amount,OLD.driver_net_earning,OLD.delivery_fee_payer,
      OLD.platform_fee_rate_bps,OLD.platform_fee_amount,OLD.customer_platform_fee_rate_bps,OLD.customer_platform_fee_amount)
   THEN RAISE EXCEPTION 'ORDER_FINANCE_SNAPSHOT_IMMUTABLE' USING ERRCODE='42501'; END IF;
   IF current_user NOT IN ('postgres','service_role','supabase_admin') AND
      ROW(NEW.status,NEW.driver_id,NEW.actual_picked_up_at,NEW.actual_delivered_at,NEW.payment_method,NEW.payment_status)
      IS DISTINCT FROM ROW(OLD.status,OLD.driver_id,OLD.actual_picked_up_at,OLD.actual_delivered_at,OLD.payment_method,OLD.payment_status)
   THEN RAISE EXCEPTION 'ORDER_FINANCE_COMMAND_REQUIRED' USING ERRCODE='42501'; END IF;
 END IF;
 RETURN NEW;
END;
$fn$;
-- Runs after set_order_business_policy and all normal snapshot preparation.
CREATE TRIGGER zz_orders_platform_fee_snapshot BEFORE INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION private.guard_platform_fee_snapshot();

CREATE FUNCTION private.manage_vnpay_fee_payment() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $fn$
DECLARE amount bigint:=round(OLD.delivery_fee)::bigint+OLD.customer_platform_fee_amount; balance bigint;
BEGIN
 IF OLD.business_policy->>'platform_fee_version' IS DISTINCT FROM '1' OR OLD.payment_method<>'vnpay' THEN RETURN NEW; END IF;
 IF NEW.actual_picked_up_at IS NULL AND OLD.payment_status='paid' AND (
   NEW.status='cancelled' OR (NEW.driver_id IS NULL AND NEW.status IN ('pending','confirmed')
     AND NEW.assignment_timed_out_at IS NOT NULL)) THEN
   PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('customer-wallet:'||OLD.customer_id::text,0));
   INSERT INTO public.customer_wallet_transactions(customer_id,order_id,transaction_type,amount,available_delta,idempotency_key,metadata)
   VALUES(OLD.customer_id,OLD.id,'delivery_fee_refund',amount,amount,'order:'||OLD.id::text||':vnpay-refund',
     jsonb_build_object('reason','pre_pickup_refund','payment_method','vnpay','customer_platform_fee',OLD.customer_platform_fee_amount))
   ON CONFLICT(idempotency_key) DO NOTHING;
   UPDATE public.order_payment_sessions SET status='refunded',updated_at=clock_timestamp()
   WHERE order_id=OLD.id AND status='paid';
   NEW.payment_status:='refunded';
 ELSIF OLD.assignment_timed_out_at IS NOT NULL AND NEW.assignment_timed_out_at IS NULL
   AND NEW.status IN ('pending','confirmed') AND OLD.payment_status='refunded' THEN
   PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('customer-wallet:'||OLD.customer_id::text,0));
   SELECT COALESCE(sum(available_delta),0)::bigint INTO balance FROM public.customer_wallet_transactions
   WHERE customer_id=OLD.customer_id AND status='completed';
   IF balance<amount THEN RAISE EXCEPTION 'CUSTOMER_WALLET_INSUFFICIENT_BALANCE'; END IF;
   INSERT INTO public.customer_wallet_transactions(customer_id,order_id,transaction_type,amount,available_delta,idempotency_key,metadata)
   VALUES(OLD.customer_id,OLD.id,'delivery_fee_payment',amount,-amount,'order:'||OLD.id::text||':vnpay-retry-wallet',
     jsonb_build_object('payment_state','reserved','reason','assignment_retry','source','refunded_vnpay'));
   NEW.payment_method:='wallet'; NEW.payment_status:='paid'; NEW.paid_at:=clock_timestamp();
 END IF;
 RETURN NEW;
END;
$fn$;
CREATE TRIGGER orders_vnpay_fee_payment BEFORE UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION private.manage_vnpay_fee_payment();

CREATE FUNCTION private.settle_platform_fees() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $fn$
BEGIN
 IF NEW.business_policy->>'platform_fee_version' IS DISTINCT FROM '1'
   OR NEW.status NOT IN ('delivered','returned') OR NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
 IF NEW.driver_id IS NULL THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED'; END IF;
 -- Prepaid/returned earnings are already net. Cash was collected gross and fees
 -- must therefore be paid from the driver's wallet. Debt never blocks handoff.
 IF NEW.status='delivered' AND NEW.delivery_fee_payer='recipient' THEN
   PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(NEW.driver_id::text,0));
   IF NEW.platform_fee_amount>0 THEN
     INSERT INTO public.driver_wallet_transactions(driver_id,order_id,transaction_type,amount,available_delta,idempotency_key,completed_at,metadata)
     VALUES(NEW.driver_id,NEW.id,'platform_fee_capture',NEW.platform_fee_amount,-NEW.platform_fee_amount,
       'order:'||NEW.id::text||':driver-platform-fee',clock_timestamp(),
       jsonb_build_object('rate_bps',NEW.platform_fee_rate_bps,'purpose','driver_platform_fee'))
     ON CONFLICT(idempotency_key) DO NOTHING;
   END IF;
   IF NEW.customer_platform_fee_amount>0 THEN
     INSERT INTO public.driver_wallet_transactions(driver_id,order_id,transaction_type,amount,available_delta,idempotency_key,completed_at,metadata)
     VALUES(NEW.driver_id,NEW.id,'customer_platform_fee_capture',NEW.customer_platform_fee_amount,-NEW.customer_platform_fee_amount,
       'order:'||NEW.id::text||':customer-platform-fee',clock_timestamp(),
       jsonb_build_object('rate_bps',NEW.customer_platform_fee_rate_bps,'purpose','collected_customer_fee'))
     ON CONFLICT(idempotency_key) DO NOTHING;
   END IF;
 END IF;
 IF NEW.status='returned' AND NEW.delivery_fee_payer='sender' AND NEW.customer_platform_fee_amount>0 THEN
   PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('customer-wallet:'||NEW.customer_id::text,0));
   INSERT INTO public.customer_wallet_transactions(customer_id,order_id,transaction_type,amount,available_delta,idempotency_key,metadata)
   VALUES(NEW.customer_id,NEW.id,'delivery_fee_refund',NEW.customer_platform_fee_amount,NEW.customer_platform_fee_amount,
     'order:'||NEW.id::text||':customer-platform-fee-refund',
     jsonb_build_object('reason','returned_platform_fee','purpose','customer_platform_fee'))
   ON CONFLICT(idempotency_key) DO NOTHING;
 END IF;
 UPDATE public.driver_wallet_transactions SET metadata=metadata||jsonb_build_object(
   'driver_platform_fee',NEW.platform_fee_amount,'customer_platform_fee',NEW.customer_platform_fee_amount,
   'gross_delivery_fee',NEW.delivery_fee,'net_delivery_earning',NEW.driver_net_earning)
 WHERE order_id=NEW.id AND driver_id=NEW.driver_id AND transaction_type IN ('prepaid_earning','cod_settlement');
 RETURN NEW;
END;
$fn$;
CREATE TRIGGER orders_settle_platform_fees AFTER UPDATE OF status ON public.orders
FOR EACH ROW EXECUTE FUNCTION private.settle_platform_fees();
REVOKE ALL ON FUNCTION private.guard_platform_fee_snapshot(),private.manage_vnpay_fee_payment(),private.settle_platform_fees()
FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION private.list_support_transactions(p_group text DEFAULT 'topups'::text, p_search text DEFAULT ''::text, p_status text DEFAULT 'all'::text, p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_created_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_key text DEFAULT NULL::text, p_limit integer DEFAULT 30)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_rows jsonb;
  v_more boolean;
  v_search text := lower(btrim(COALESCE(p_search, '')));
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.users actor WHERE actor.id = auth.uid()
      AND actor.role IN ('support','admin')) THEN
    RAISE EXCEPTION 'SUPPORT_REQUIRED' USING ERRCODE = '42501';
  END IF;
  IF p_group IS NULL OR p_group NOT IN ('topups','payments','refunds')
    OR p_status IS NULL OR p_status NOT IN
      ('all','pending','completed','failed','expired','refund_required','refunded','reversed')
    OR length(v_search) > 120 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
    OR (p_from IS NOT NULL AND p_to IS NOT NULL AND p_from >= p_to)
    OR ((p_before_created_at IS NULL) <> (p_before_key IS NULL)) THEN
    RAISE EXCEPTION 'TRANSACTION_FILTER_INVALID' USING ERRCODE = '22023';
  END IF;
  WITH ledger AS (
    SELECT 'driver'::text source, t.id, t.driver_id user_id, t.order_id,
      t.transaction_type kind, t.status, t.amount, t.available_delta, t.held_delta,
      t.created_at, t.completed_at, NULL::timestamptz expires_at,
      t.provider_txn_ref, t.provider_transaction_no, t.provider_response_code,
      NULL::uuid risk_report_id, t.metadata->>'purpose' purpose,
      t.metadata->>'reason' reason, NULL::text payment_state
    FROM public.driver_wallet_transactions t
    WHERE (p_group='payments' AND t.transaction_type IN ('platform_fee_capture','customer_platform_fee_capture'))
      OR (p_group='topups' AND t.transaction_type='vnpay_topup')
      OR (p_group='refunds' AND t.transaction_type='cod_release')
    UNION ALL
    SELECT 'customer', t.id, t.customer_id, t.order_id, t.transaction_type,
      t.status, t.amount, t.available_delta, 0::bigint,
      t.created_at, t.completed_at, NULL::timestamptz,
      NULL::text, NULL::text, NULL::text, t.risk_report_id,
      NULL::text, t.metadata->>'reason', t.metadata->>'payment_state'
    FROM public.customer_wallet_transactions t
    WHERE (p_group='payments' AND t.transaction_type='delivery_fee_payment')
      OR (p_group='refunds' AND t.transaction_type='delivery_fee_refund')
    UNION ALL
    SELECT 'vnpay', t.id, t.customer_id, t.order_id, 'order_payment',
      CASE WHEN t.status='paid' THEN 'completed' ELSE t.status END,
      t.amount, NULL::bigint, NULL::bigint, t.created_at, t.paid_at, t.expires_at,
      t.provider_txn_ref, t.provider_transaction_no, t.provider_response_code,
      NULL::uuid, NULL::text, NULL::text, NULL::text
    FROM public.order_payment_sessions t
    WHERE p_group='payments' OR (p_group='refunds' AND t.status IN ('refund_required','refunded'))
  ), matched AS (
    SELECT t.*, t.source || ':' || t.id::text record_key,
      owner.full_name user_name, owner.phone user_phone, owner.role::text user_role,
      delivery_order.tracking_code
    FROM ledger t
    JOIN public.users owner ON owner.id=t.user_id
    LEFT JOIN public.orders delivery_order ON delivery_order.id=t.order_id
    WHERE (p_status='all' OR t.status=p_status)
      AND (p_from IS NULL OR t.created_at>=p_from)
      AND (p_to IS NULL OR t.created_at<p_to)
      AND (v_search='' OR strpos(lower(concat_ws(' ', t.id::text,
        t.provider_txn_ref, t.provider_transaction_no, owner.full_name,
        owner.phone, t.user_id::text, delivery_order.tracking_code)),v_search)>0)
      AND (p_before_created_at IS NULL OR
        (t.created_at,t.source || ':' || t.id::text)<(p_before_created_at,p_before_key))
    ORDER BY t.created_at DESC, record_key DESC LIMIT p_limit+1
  ), page AS (
    SELECT * FROM matched ORDER BY created_at DESC, record_key DESC LIMIT p_limit
  )
  SELECT COALESCE((SELECT jsonb_agg(to_jsonb(page) ORDER BY created_at DESC,record_key DESC)
      FROM page),'[]'::jsonb), (SELECT count(*)>p_limit FROM matched)
  INTO v_rows,v_more;
  RETURN jsonb_build_object('rows',v_rows,'has_more',v_more,'server_now',now());
END;
$function$;


CREATE OR REPLACE FUNCTION public.advance_driver_order_status(p_order_id uuid)
 RETURNS TABLE(order_id uuid, customer_id uuid, tracking_code text, new_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
  v_order public.orders%ROWTYPE;
  v_next_status public.order_status;
  v_title text;
  v_description text;
  v_available_balance bigint;
  v_legacy_held_balance bigint;
BEGIN
  IF v_driver_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.driver_id IS DISTINCT FROM v_driver_user_id
    THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED'; END IF;
  -- Successful delivery retries must not settle the wallet a second time.
  IF v_order.status = 'delivered'::public.order_status
    AND (private.is_paid_goods_deposit_order(v_order) OR v_order.business_policy->>'platform_fee_version'='1') THEN
    RETURN QUERY SELECT v_order.id, v_order.customer_id, v_order.tracking_code,
      v_order.status::text;
    RETURN;
  END IF;
  IF v_order.status = 'picking_up'::public.order_status AND NOT EXISTS (
    SELECT 1 FROM public.order_delivery_proofs AS proof
    WHERE proof.order_id = p_order_id
      AND proof.driver_id = v_driver_user_id
      AND proof.stage = 'pickup'
  ) THEN RAISE EXCEPTION 'PICKUP_PROOF_REQUIRED'; END IF;
  IF v_order.status = 'delivering'::public.order_status AND NOT EXISTS (
    SELECT 1 FROM public.order_delivery_proofs AS proof
    WHERE proof.order_id = p_order_id
      AND proof.driver_id = v_driver_user_id
      AND proof.stage = 'delivery'
  ) THEN RAISE EXCEPTION 'DELIVERY_PROOF_REQUIRED'; END IF;

  v_next_status := CASE v_order.status
    WHEN 'assigned'::public.order_status THEN 'picking_up'::public.order_status
    WHEN 'picking_up'::public.order_status THEN 'delivering'::public.order_status
    WHEN 'delivering'::public.order_status THEN 'delivered'::public.order_status
    ELSE NULL
  END;
  IF v_next_status IS NULL THEN RAISE EXCEPTION 'INVALID_STATUS_TRANSITION'; END IF;

  IF v_next_status IN (
    'delivering'::public.order_status,
    'delivered'::public.order_status
  ) THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_driver_user_id::text, 0)
    );
  END IF;

  IF v_next_status = 'delivering'::public.order_status
    AND private.is_paid_goods_deposit_order(v_order) THEN
    -- This is a retry-safe verification of the hold, never a COD capture.
    PERFORM private.hold_paid_goods_deposit(v_order, v_driver_user_id);
  ELSIF v_next_status = 'delivering'::public.order_status
     AND v_order.driver_advance_amount > 0 THEN
    SELECT COALESCE(sum(tx.held_delta), 0)::bigint
    INTO v_legacy_held_balance
    FROM public.driver_wallet_transactions AS tx
    WHERE tx.driver_id = v_driver_user_id
      AND tx.order_id = v_order.id
      AND tx.status = 'completed';

    IF v_legacy_held_balance >= v_order.driver_advance_amount THEN
      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount, held_delta,
        idempotency_key, completed_at, metadata
      ) VALUES (
        v_driver_user_id, v_order.id, 'cod_advance_capture',
        v_order.driver_advance_amount, -v_order.driver_advance_amount,
        'order:' || v_order.id::text || ':cod_advance_capture',
        clock_timestamp(), jsonb_build_object('source', 'legacy_hold')
      );
    ELSE
      SELECT COALESCE(sum(tx.available_delta), 0)::bigint
      INTO v_available_balance
      FROM public.driver_wallet_transactions AS tx
      WHERE tx.driver_id = v_driver_user_id
        AND tx.status = 'completed';
      IF v_available_balance < v_order.driver_advance_amount THEN
        RAISE EXCEPTION 'INSUFFICIENT_WALLET_BALANCE_AT_PICKUP';
      END IF;

      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount, available_delta,
        idempotency_key, completed_at, metadata
      ) VALUES (
        v_driver_user_id, v_order.id, 'cod_advance_capture',
        v_order.driver_advance_amount, -v_order.driver_advance_amount,
        'order:' || v_order.id::text || ':cod_advance_capture',
        clock_timestamp(), jsonb_build_object('source', 'pickup_debit')
      );
    END IF;
  END IF;

  IF v_next_status = 'delivered'::public.order_status THEN
    PERFORM private.release_paid_goods_deposit(
      v_order, v_driver_user_id, 'delivery', NULL, true
    );
    IF v_order.delivery_fee_payer = 'recipient' THEN
      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount,
        idempotency_key, completed_at, metadata
      ) VALUES (
        v_driver_user_id, v_order.id, 'cod_settlement',
        v_order.driver_net_earning,
        'order:' || v_order.id::text || ':cod_settlement',
        clock_timestamp(),
        jsonb_build_object(
          'cash_collected', v_order.receiver_collection_amount,
          'cod_collection_amount', v_order.cod_collection_amount,
          'delivery_fee', round(v_order.delivery_fee)::bigint
        )
      );
    ELSE
      IF v_order.cod_collection_amount > 0 THEN
        INSERT INTO public.driver_wallet_transactions (
          driver_id, order_id, transaction_type, amount,
          idempotency_key, completed_at, metadata
        ) VALUES (
          v_driver_user_id, v_order.id, 'cod_settlement', 0,
          'order:' || v_order.id::text || ':cod_settlement',
          clock_timestamp(),
          jsonb_build_object(
            'cash_collected', v_order.cod_collection_amount,
            'cod_collection_amount', v_order.cod_collection_amount,
            'delivery_fee_paid_by', 'sender'
          )
        );
      END IF;
      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount, available_delta,
        idempotency_key, completed_at
      ) VALUES (
        v_driver_user_id, v_order.id, 'prepaid_earning',
        v_order.driver_net_earning, v_order.driver_net_earning,
        'order:' || v_order.id::text || ':prepaid_earning',
        clock_timestamp()
      );
    END IF;

    PERFORM private.credit_customer_cod(
      v_order.customer_id,
      v_order.id,
      v_order.cod_collection_amount,
      'delivery_credit',
      'order:' || v_order.id::text || ':customer_delivery_credit',
      NULL,
      jsonb_build_object(
        'tracking_code', v_order.tracking_code,
        'driver_id', v_driver_user_id
      )
    );
  END IF;

  v_title := CASE v_next_status
    WHEN 'picking_up'::public.order_status THEN 'Tài xế đang đến điểm lấy hàng'
    WHEN 'delivering'::public.order_status THEN 'Đơn hàng đang được giao'
    WHEN 'delivered'::public.order_status THEN 'Giao hàng thành công'
    ELSE 'Cập nhật trạng thái đơn hàng'
  END;
  v_description := CASE v_next_status
    WHEN 'picking_up'::public.order_status
      THEN 'Tài xế đã bắt đầu di chuyển đến điểm lấy hàng.'
    WHEN 'delivering'::public.order_status
      THEN 'Tài xế đã xác nhận nhận kiện, tiền hàng đã được trừ và đơn đang được giao.'
    WHEN 'delivered'::public.order_status
      THEN CASE WHEN private.is_paid_goods_deposit_order(v_order)
        THEN 'Giao hàng thành công. Tiền làm tin đã hoàn vào ví tài xế; cước giao được ghi nhận riêng.'
        ELSE 'Tài xế đã xác nhận bàn giao thành công; tiền hàng đã được quyết toán cho người tạo đơn.' END
    ELSE NULL
  END;

  UPDATE public.orders
  SET
    status = v_next_status,
    updated_at = clock_timestamp(),
    actual_picked_up_at = CASE
      WHEN v_next_status = 'delivering'::public.order_status
        THEN clock_timestamp()
      ELSE actual_picked_up_at
    END,
    actual_delivered_at = CASE
      WHEN v_next_status = 'delivered'::public.order_status
        THEN clock_timestamp()
      ELSE actual_delivered_at
    END
  WHERE id = p_order_id
    AND status = v_order.status;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_STATUS_CHANGED'; END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, v_next_status, v_title, v_description, v_driver_user_id
  );
  RETURN QUERY SELECT v_order.id, v_order.customer_id,
    v_order.tracking_code, v_next_status::text;
END;
$function$;

CREATE OR REPLACE FUNCTION public.accept_order(p_order_id uuid)
 RETURNS TABLE(order_id uuid, customer_id uuid, tracking_code text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
  v_order public.orders%ROWTYPE;
  v_is_available boolean;
  v_approval_status public.approval_status;
  v_available_balance bigint;
  v_required_balance bigint;
BEGIN
  IF v_driver_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('driver-assignment:' || v_driver_user_id::text,0));
  IF EXISTS (SELECT 1 FROM public.drivers d WHERE d.user_id = v_driver_user_id
    AND d.acceptance_locked_until > clock_timestamp()) THEN
    RAISE EXCEPTION 'DRIVER_ACCEPTANCE_LOCKED';
  END IF;
  SELECT driver_profile.is_available, driver_profile.approval_status
  INTO v_is_available, v_approval_status
  FROM public.drivers AS driver_profile
  WHERE driver_profile.user_id = v_driver_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND'; END IF;
  IF v_approval_status IS DISTINCT FROM 'approved'::public.approval_status
    THEN RAISE EXCEPTION 'DRIVER_NOT_APPROVED'; END IF;
  IF v_is_available IS DISTINCT FROM true
    THEN RAISE EXCEPTION 'DRIVER_OFFLINE'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.orders AS active_order
    WHERE active_order.driver_id = v_driver_user_id
      AND active_order.status IN (
        'assigned'::public.order_status,
        'picking_up'::public.order_status,
        'delivering'::public.order_status,
        'return_approved'::public.order_status,
        'returning'::public.order_status
      )
  ) THEN RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER'; END IF;

  IF v_order.payment_status NOT IN ('not_required', 'paid') THEN
    RAISE EXCEPTION 'ORDER_PAYMENT_INCOMPLETE';
  END IF;
  IF v_order.driver_id IS NOT NULL OR v_order.status NOT IN (
    'pending'::public.order_status, 'confirmed'::public.order_status
  ) THEN RAISE EXCEPTION 'ORDER_NOT_AVAILABLE'; END IF;
  IF v_order.assignment_timed_out_at IS NOT NULL
     OR v_order.assignment_expires_at <= clock_timestamp()
    THEN RAISE EXCEPTION 'ASSIGNMENT_EXPIRED'; END IF;
  IF v_order.offered_driver_id IS DISTINCT FROM v_driver_user_id
    THEN RAISE EXCEPTION 'ORDER_NOT_OFFERED_TO_DRIVER'; END IF;
  IF v_order.offer_expires_at IS NULL
     OR v_order.offer_expires_at <= clock_timestamp()
    THEN RAISE EXCEPTION 'OFFER_EXPIRED'; END IF;

  v_required_balance := v_order.driver_advance_amount;
  -- A negative fee balance also blocks zero-COD orders.
  IF v_required_balance >= 0 THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_driver_user_id::text, 0)
    );
    SELECT COALESCE(sum(tx.available_delta), 0)::bigint
    INTO v_available_balance
    FROM public.driver_wallet_transactions AS tx
    WHERE tx.driver_id = v_driver_user_id
      AND tx.status = 'completed';
    IF v_available_balance < v_required_balance THEN
      RAISE EXCEPTION 'INSUFFICIENT_WALLET_BALANCE';
    END IF;
  END IF;

  BEGIN
    UPDATE public.orders
    SET
      driver_id = v_driver_user_id,
      status = 'assigned'::public.order_status,
      offered_driver_id = NULL,
      offer_expires_at = NULL,
      updated_at = clock_timestamp()
    WHERE id = p_order_id
    RETURNING * INTO v_order;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER';
  END;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, 'assigned'::public.order_status,
    'Đã có tài xế nhận đơn',
    'Tài xế đã chấp nhận lời mời. Tiền hàng chỉ được trừ khi xác nhận nhận kiện.',
    v_driver_user_id
  );
  RETURN QUERY SELECT v_order.id, v_order.customer_id, v_order.tracking_code;
END;
$function$;

DO $rollout$
DECLARE old_value jsonb; next_value jsonb; values_new jsonb; rev bigint;
BEGIN
 SELECT value INTO STRICT old_value FROM public.system_settings WHERE key='business_settings' FOR UPDATE;
 values_new:=old_value->'values';
 -- Preview zeros were placeholders; retain any nonzero rates already chosen by Admin.
 values_new:=values_new||jsonb_build_object(
   'customer_individual_fee_bps',CASE WHEN (values_new->>'customer_individual_fee_bps')::integer=0 THEN 500 ELSE (values_new->>'customer_individual_fee_bps')::integer END,
   'customer_business_fee_bps',CASE WHEN (values_new->>'customer_business_fee_bps')::integer=0 THEN 300 ELSE (values_new->>'customer_business_fee_bps')::integer END,
   'driver_platform_fee_bps',CASE WHEN (values_new->>'driver_platform_fee_bps')::integer=0 THEN 1000 ELSE (values_new->>'driver_platform_fee_bps')::integer END);
 PERFORM private.validate_business_settings(values_new);
 rev:=(old_value->>'revision')::bigint+1;
 next_value:=jsonb_build_object('revision',rev,'values',values_new,'platform_fee_version',1);
 INSERT INTO public.system_settings(key,value,updated_by) VALUES('business_settings_revision:'||rev::text,
   next_value||jsonb_build_object('previous_values',old_value->'values','reason',
     'Bật thu phí sàn thực tế trên đơn mới: khách cá nhân 5%, doanh nghiệp 3%, tài xế 10% nếu chưa cấu hình; giữ nguyên đơn và phiên thanh toán cũ.'),NULL);
 UPDATE public.system_settings SET value=next_value,updated_by=NULL,updated_at=clock_timestamp() WHERE key='business_settings';
END;
$rollout$;
