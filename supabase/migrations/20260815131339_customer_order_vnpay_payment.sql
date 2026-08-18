-- Tách người trả phí giao hàng khỏi khoản thu hộ COD.
-- Đơn người gửi trả phí chỉ được tạo sau khi VNPAY IPN xác nhận thành công.

ALTER TABLE public.orders
  ADD COLUMN delivery_fee_payer text NOT NULL DEFAULT 'recipient',
  ADD COLUMN payment_status text NOT NULL DEFAULT 'not_required',
  ADD COLUMN cod_collection_amount bigint NOT NULL DEFAULT 0,
  ADD COLUMN paid_at timestamptz;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_delivery_fee_payer_check
    CHECK (delivery_fee_payer IN ('sender', 'recipient')),
  ADD CONSTRAINT orders_payment_status_check
    CHECK (payment_status IN (
      'not_required', 'pending', 'paid', 'failed', 'expired',
      'refund_required', 'refunded'
    )),
  ADD CONSTRAINT orders_cod_collection_amount_check
    CHECK (cod_collection_amount >= 0);

UPDATE public.orders
SET
  delivery_fee_payer = CASE
    WHEN payment_mode = 'prepaid' THEN 'sender'
    ELSE 'recipient'
  END,
  payment_status = CASE
    WHEN payment_mode = 'prepaid' THEN 'paid'
    ELSE 'not_required'
  END,
  cod_collection_amount = greatest(driver_advance_amount, 0),
  paid_at = CASE
    WHEN payment_mode = 'prepaid' THEN created_at
    ELSE NULL
  END;

CREATE TABLE public.order_payment_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  order_id uuid UNIQUE REFERENCES public.orders(id) ON DELETE RESTRICT,
  provider text NOT NULL DEFAULT 'vnpay' CHECK (provider = 'vnpay'),
  provider_txn_ref text NOT NULL UNIQUE,
  provider_transaction_no text,
  provider_response_code text,
  amount bigint NOT NULL CHECK (amount BETWEEN 5000 AND 10000000),
  currency text NOT NULL DEFAULT 'VND' CHECK (currency = 'VND'),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN (
    'pending', 'paid', 'failed', 'expired', 'refund_required', 'refunded'
  )),
  order_payload jsonb NOT NULL,
  expires_at timestamptz NOT NULL,
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX order_payment_sessions_customer_created_idx
  ON public.order_payment_sessions (customer_id, created_at DESC);
CREATE INDEX order_payment_sessions_pending_expiry_idx
  ON public.order_payment_sessions (expires_at)
  WHERE status = 'pending';

ALTER TABLE public.order_payment_sessions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.order_payment_sessions FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE ON public.order_payment_sessions
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.order_payment_sessions TO authenticated;

CREATE POLICY order_payment_sessions_select_own
  ON public.order_payment_sessions
  FOR SELECT
  TO authenticated
  USING (customer_id = (SELECT auth.uid()));

CREATE OR REPLACE FUNCTION private.create_customer_order_from_payload(
  p_customer_id uuid,
  p_order_payload jsonb,
  p_payment_status text,
  p_paid_at timestamptz DEFAULT NULL
)
RETURNS public.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_order public.orders%ROWTYPE;
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
  v_estimated_pickup_at timestamptz;
  v_estimated_delivery_at timestamptz;
BEGIN
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
     OR v_goods_value < 0 OR v_goods_value > 100000000
     OR v_cod_amount < 0 OR v_cod_amount > 10000000 THEN
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
    customer_id, status, pickup_address, pickup_lat, pickup_lng,
    delivery_address, delivery_lat, delivery_lng, total_price, note,
    estimated_pickup_at, estimated_delivery_at, recipient_name,
    recipient_phone, delivery_fee, service_type, payment_method, item_name,
    item_category, item_description, item_image_url, payment_mode,
    delivery_fee_payer, payment_status, paid_at, goods_value,
    cod_collection_amount, platform_fee_rate_bps, platform_fee_amount,
    driver_net_earning, driver_advance_amount, receiver_collection_amount
  ) VALUES (
    p_customer_id, 'pending'::public.order_status,
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
    v_payment_mode, v_fee_payer, p_payment_status, p_paid_at,
    v_goods_value, v_cod_amount, 0, 0, v_delivery_fee,
    v_cod_amount, v_receiver_amount
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

REVOKE ALL ON FUNCTION private.create_customer_order_from_payload(
  uuid, jsonb, text, timestamptz
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_customer_order_v2(
  p_order_payload jsonb
)
RETURNS TABLE(order_id uuid, tracking_code text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_customer_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
BEGIN
  IF v_customer_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users app_user
    WHERE app_user.id = v_customer_id
      AND app_user.role = 'customer'::public.user_role
  ) THEN RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED'; END IF;
  IF lower(COALESCE(p_order_payload->>'delivery_fee_payer', 'recipient'))
     <> 'recipient' THEN
    RAISE EXCEPTION 'VNPAY_PAYMENT_REQUIRED';
  END IF;

  SELECT * INTO v_order
  FROM private.create_customer_order_from_payload(
    v_customer_id, p_order_payload, 'not_required', NULL
  );
  RETURN QUERY SELECT v_order.id, v_order.tracking_code;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_customer_order_v2(jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_customer_order_v2(jsonb)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.create_customer_order_payment_session(
  p_order_payload jsonb,
  p_txn_ref text
)
RETURNS TABLE(
  session_id uuid,
  txn_ref text,
  amount bigint,
  status text,
  expires_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_customer_id uuid := auth.uid();
  v_session public.order_payment_sessions%ROWTYPE;
  v_amount bigint;
  v_fee_payer text;
  v_cod_amount bigint;
  v_goods_value bigint;
BEGIN
  IF v_customer_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users app_user
    WHERE app_user.id = v_customer_id
      AND app_user.role = 'customer'::public.user_role
  ) THEN RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED'; END IF;
  IF p_order_payload IS NULL OR jsonb_typeof(p_order_payload) <> 'object' THEN
    RAISE EXCEPTION 'ORDER_PAYLOAD_INVALID';
  END IF;
  IF NULLIF(btrim(p_txn_ref), '') IS NULL THEN
    RAISE EXCEPTION 'PAYMENT_TXN_REF_REQUIRED';
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
     OR v_cod_amount < 0 OR v_cod_amount > 10000000
     OR v_goods_value < 0 OR v_goods_value > 100000000 THEN
    RAISE EXCEPTION 'ORDER_PRICE_INVALID';
  END IF;

  INSERT INTO public.order_payment_sessions (
    customer_id, provider_txn_ref, amount, status,
    order_payload, expires_at
  ) VALUES (
    v_customer_id, btrim(p_txn_ref), v_amount, 'pending',
    p_order_payload || jsonb_build_object('delivery_fee_payer', 'sender'),
    clock_timestamp() + interval '15 minutes'
  ) RETURNING * INTO v_session;

  RETURN QUERY SELECT v_session.id, v_session.provider_txn_ref,
    v_session.amount, v_session.status, v_session.expires_at;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_customer_order_payment_session(jsonb, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_customer_order_payment_session(jsonb, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_customer_order_payment_session(
  p_session_id uuid
)
RETURNS TABLE(
  session_id uuid,
  txn_ref text,
  amount bigint,
  status text,
  order_id uuid,
  tracking_code text,
  expires_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_customer_id uuid := auth.uid();
BEGIN
  IF v_customer_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  RETURN QUERY
  SELECT session.id, session.provider_txn_ref, session.amount,
    CASE WHEN session.status = 'pending'
           AND session.expires_at <= clock_timestamp()
      THEN 'expired' ELSE session.status END,
    session.order_id, delivery.tracking_code,
    session.expires_at
  FROM public.order_payment_sessions session
  LEFT JOIN public.orders delivery ON delivery.id = session.order_id
  WHERE session.id = p_session_id
    AND session.customer_id = v_customer_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_customer_order_payment_session(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customer_order_payment_session(uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.complete_customer_order_payment(
  p_txn_ref text,
  p_vnp_transaction_no text,
  p_success boolean,
  p_response_code text
)
RETURNS TABLE(
  session_id uuid,
  order_id uuid,
  tracking_code text,
  status text,
  activated boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
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
  FROM private.create_customer_order_from_payload(
    v_session.customer_id, v_session.order_payload, 'paid', clock_timestamp()
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

REVOKE ALL ON FUNCTION public.complete_customer_order_payment(
  text, text, boolean, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_customer_order_payment(
  text, text, boolean, text
) TO service_role;

CREATE OR REPLACE FUNCTION public.accept_order(p_order_id uuid)
RETURNS TABLE(order_id uuid, customer_id uuid, tracking_code text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_driver_user_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_is_available boolean;
  v_approval_status public.approval_status;
  v_available_balance bigint;
  v_required_balance bigint;
BEGIN
  IF v_driver_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT driver_profile.is_available, driver_profile.approval_status
  INTO v_is_available, v_approval_status
  FROM public.drivers driver_profile
  WHERE driver_profile.user_id = v_driver_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND'; END IF;
  IF v_approval_status IS DISTINCT FROM 'approved'::public.approval_status
    THEN RAISE EXCEPTION 'DRIVER_NOT_APPROVED'; END IF;
  IF v_is_available IS DISTINCT FROM true
    THEN RAISE EXCEPTION 'DRIVER_OFFLINE'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.orders active_order
    WHERE active_order.driver_id = v_driver_user_id
      AND active_order.status IN (
        'assigned'::public.order_status,
        'picking_up'::public.order_status,
        'delivering'::public.order_status
      )
  ) THEN RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER'; END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
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

  v_required_balance := v_order.driver_advance_amount
    + CASE WHEN v_order.platform_fee_rate_bps > 0
      THEN v_order.platform_fee_amount ELSE 0 END;
  IF v_required_balance > 0 THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_driver_user_id::text, 0)
    );
    SELECT COALESCE(sum(tx.available_delta), 0)::bigint
    INTO v_available_balance
    FROM public.driver_wallet_transactions tx
    WHERE tx.driver_id = v_driver_user_id AND tx.status = 'completed';
    IF v_available_balance < v_required_balance THEN
      RAISE EXCEPTION 'INSUFFICIENT_WALLET_BALANCE';
    END IF;
    INSERT INTO public.driver_wallet_transactions (
      driver_id, order_id, transaction_type, amount,
      available_delta, held_delta, idempotency_key, completed_at
    ) VALUES (
      v_driver_user_id, v_order.id, 'cod_hold', v_required_balance,
      -v_required_balance, v_required_balance,
      'order:' || v_order.id::text || ':cod_hold', clock_timestamp()
    );
  END IF;

  BEGIN
    UPDATE public.orders
    SET driver_id = v_driver_user_id,
      status = 'assigned'::public.order_status,
      offered_driver_id = NULL, offer_expires_at = NULL,
      updated_at = clock_timestamp()
    WHERE id = p_order_id RETURNING * INTO v_order;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER';
  END;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, 'assigned'::public.order_status,
    'Đã có tài xế nhận đơn',
    'Tài xế đã chấp nhận lời mời trong thời gian phản hồi.',
    v_driver_user_id
  );
  RETURN QUERY SELECT v_order.id, v_order.customer_id, v_order.tracking_code;
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_customer_order(
  p_order_id uuid,
  p_customer_id uuid,
  p_status_note text DEFAULT NULL
)
RETURNS TABLE(order_id uuid, driver_id uuid, tracking_code text, new_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_customer_user_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_normalized_note text := NULLIF(btrim(p_status_note), '');
  v_release_amount bigint;
BEGIN
  IF v_customer_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users customer_user
    WHERE customer_user.id = v_customer_user_id
      AND customer_user.role = 'customer'::public.user_role
  ) THEN RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED'; END IF;
  IF p_customer_id IS DISTINCT FROM v_customer_user_id
    THEN RAISE EXCEPTION 'CUSTOMER_ID_MISMATCH'; END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.customer_id IS DISTINCT FROM v_customer_user_id
    THEN RAISE EXCEPTION 'ORDER_NOT_OWNED'; END IF;
  IF v_order.status NOT IN (
    'pending'::public.order_status, 'confirmed'::public.order_status,
    'assigned'::public.order_status, 'picking_up'::public.order_status
  ) THEN RAISE EXCEPTION 'ORDER_NOT_CANCELLABLE'; END IF;
  IF v_order.status = 'picking_up'::public.order_status AND EXISTS (
    SELECT 1 FROM public.order_delivery_proofs proof
    WHERE proof.order_id = p_order_id AND proof.stage = 'pickup'
  ) THEN RAISE EXCEPTION 'ORDER_ALREADY_PICKED_UP'; END IF;

  IF v_order.driver_id IS NOT NULL THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_order.driver_id::text, 0)
    );
    SELECT COALESCE(sum(tx.held_delta), 0)::bigint INTO v_release_amount
    FROM public.driver_wallet_transactions tx
    WHERE tx.driver_id = v_order.driver_id
      AND tx.order_id = v_order.id AND tx.status = 'completed';
    IF v_release_amount > 0 THEN
      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount,
        available_delta, held_delta, idempotency_key, completed_at
      ) VALUES (
        v_order.driver_id, v_order.id, 'cod_release', v_release_amount,
        v_release_amount, -v_release_amount,
        'order:' || v_order.id::text || ':cod_release', clock_timestamp()
      );
    END IF;
  END IF;

  UPDATE public.orders
  SET status = 'cancelled'::public.order_status,
    status_note = v_normalized_note,
    payment_status = CASE
      WHEN delivery_fee_payer = 'sender' AND payment_status = 'paid'
        THEN 'refund_required'
      ELSE payment_status END,
    cancelled_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE id = p_order_id RETURNING * INTO v_order;

  IF v_order.payment_status = 'refund_required' THEN
    UPDATE public.order_payment_sessions session
    SET status = 'refund_required', updated_at = clock_timestamp()
    WHERE session.order_id = v_order.id AND session.status = 'paid';
  END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    v_order.id, 'cancelled'::public.order_status, 'Đơn hàng đã hủy',
    CASE WHEN v_normalized_note IS NULL
      THEN 'Khách hàng đã hủy đơn trước khi tài xế nhận hàng.'
      ELSE 'Khách hàng đã hủy đơn trước khi tài xế nhận hàng. Lý do: '
        || v_normalized_note END,
    v_customer_user_id
  );
  RETURN QUERY SELECT v_order.id, v_order.driver_id,
    v_order.tracking_code, v_order.status::text;
END;
$function$;

CREATE OR REPLACE FUNCTION public.advance_driver_order_status(p_order_id uuid)
RETURNS TABLE(order_id uuid, customer_id uuid, tracking_code text, new_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_driver_user_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_next_status public.order_status;
  v_title text;
  v_description text;
BEGIN
  IF v_driver_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.driver_id IS DISTINCT FROM v_driver_user_id
    THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED'; END IF;
  IF v_order.status = 'picking_up'::public.order_status AND NOT EXISTS (
    SELECT 1 FROM public.order_delivery_proofs proof
    WHERE proof.order_id = p_order_id AND proof.driver_id = v_driver_user_id
      AND proof.stage = 'pickup'
  ) THEN RAISE EXCEPTION 'PICKUP_PROOF_REQUIRED'; END IF;
  IF v_order.status = 'delivering'::public.order_status AND NOT EXISTS (
    SELECT 1 FROM public.order_delivery_proofs proof
    WHERE proof.order_id = p_order_id AND proof.driver_id = v_driver_user_id
      AND proof.stage = 'delivery'
  ) THEN RAISE EXCEPTION 'DELIVERY_PROOF_REQUIRED'; END IF;

  v_next_status := CASE v_order.status
    WHEN 'assigned'::public.order_status THEN 'picking_up'::public.order_status
    WHEN 'picking_up'::public.order_status THEN 'delivering'::public.order_status
    WHEN 'delivering'::public.order_status THEN 'delivered'::public.order_status
    ELSE NULL END;
  IF v_next_status IS NULL THEN RAISE EXCEPTION 'INVALID_STATUS_TRANSITION'; END IF;

  IF v_next_status IN ('delivering'::public.order_status, 'delivered'::public.order_status) THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_driver_user_id::text, 0)
    );
  END IF;

  IF v_next_status = 'delivering'::public.order_status
     AND v_order.driver_advance_amount > 0 THEN
    INSERT INTO public.driver_wallet_transactions (
      driver_id, order_id, transaction_type, amount, held_delta,
      idempotency_key, completed_at
    ) VALUES (
      v_driver_user_id, v_order.id, 'cod_advance_capture',
      v_order.driver_advance_amount, -v_order.driver_advance_amount,
      'order:' || v_order.id::text || ':cod_advance_capture', clock_timestamp()
    );
  END IF;

  IF v_next_status = 'delivered'::public.order_status THEN
    IF v_order.delivery_fee_payer = 'recipient' THEN
      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount,
        idempotency_key, completed_at, metadata
      ) VALUES (
        v_driver_user_id, v_order.id, 'cod_settlement',
        v_order.driver_net_earning,
        'order:' || v_order.id::text || ':cod_settlement', clock_timestamp(),
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
          'order:' || v_order.id::text || ':cod_settlement', clock_timestamp(),
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
        'order:' || v_order.id::text || ':prepaid_earning', clock_timestamp()
      );
    END IF;
  END IF;

  v_title := CASE v_next_status
    WHEN 'picking_up'::public.order_status THEN 'Tài xế đang đến điểm lấy hàng'
    WHEN 'delivering'::public.order_status THEN 'Đơn hàng đang được giao'
    WHEN 'delivered'::public.order_status THEN 'Giao hàng thành công'
    ELSE 'Cập nhật trạng thái đơn hàng' END;
  v_description := CASE v_next_status
    WHEN 'picking_up'::public.order_status
      THEN 'Tài xế đã bắt đầu di chuyển đến điểm lấy hàng.'
    WHEN 'delivering'::public.order_status
      THEN 'Tài xế đã chụp ảnh xác nhận lấy hàng và đang đến người nhận.'
    WHEN 'delivered'::public.order_status
      THEN 'Tài xế đã chụp ảnh xác nhận bàn giao thành công.'
    ELSE NULL END;

  UPDATE public.orders
  SET status = v_next_status, updated_at = clock_timestamp(),
    actual_picked_up_at = CASE
      WHEN v_next_status = 'delivering'::public.order_status
        THEN clock_timestamp() ELSE actual_picked_up_at END,
    actual_delivered_at = CASE
      WHEN v_next_status = 'delivered'::public.order_status
        THEN clock_timestamp() ELSE actual_delivered_at END
  WHERE id = p_order_id AND status = v_order.status;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_STATUS_CHANGED'; END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (p_order_id, v_next_status, v_title, v_description, v_driver_user_id);
  RETURN QUERY SELECT v_order.id, v_order.customer_id,
    v_order.tracking_code, v_next_status::text;
END;
$function$;
