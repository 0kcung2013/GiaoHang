-- Paid goods deposits reuse the existing wallet ledger and financial snapshots.
-- Only new VNPAY sessions are opted in; existing orders/sessions are not charged.
CREATE OR REPLACE FUNCTION private.is_paid_goods_deposit_order(p_order public.orders)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path = ''
AS $function$
  SELECT COALESCE(
    (p_order).delivery_fee_payer = 'sender'
    AND (p_order).payment_status = 'paid'
    AND (p_order).cod_collection_amount = 0
    AND (p_order).goods_value > 0
    AND (p_order).driver_advance_amount = (p_order).goods_value,
    false
  );
$function$;

CREATE OR REPLACE FUNCTION private.hold_paid_goods_deposit(
  p_order public.orders, p_driver_id uuid
)
RETURNS void LANGUAGE plpgsql SET search_path = ''
AS $function$
DECLARE
  v_existing public.driver_wallet_transactions%ROWTYPE;
  v_balance bigint;
  v_key text := 'order:' || p_order.id::text || ':driver:' || p_driver_id::text
    || ':paid_goods_deposit_hold';
BEGIN
  IF NOT private.is_paid_goods_deposit_order(p_order) THEN RETURN; END IF;
  IF p_driver_id IS NULL OR p_order.driver_id IS DISTINCT FROM p_driver_id THEN
    RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_driver_id::text, 0)
  );
  SELECT * INTO v_existing FROM public.driver_wallet_transactions
    WHERE idempotency_key = v_key;
  IF FOUND THEN
    IF v_existing.status <> 'completed'
      OR v_existing.transaction_type <> 'cod_hold'
      OR v_existing.amount <> p_order.driver_advance_amount
      OR v_existing.available_delta <> -p_order.driver_advance_amount
      OR v_existing.held_delta <> p_order.driver_advance_amount
      OR v_existing.metadata->>'purpose' IS DISTINCT FROM 'paid_goods_deposit'
      OR v_existing.order_id IS DISTINCT FROM p_order.id
      OR v_existing.driver_id IS DISTINCT FROM p_driver_id THEN
      RAISE EXCEPTION 'GOODS_DEPOSIT_LEDGER_MISMATCH';
    END IF;
    IF EXISTS (SELECT 1 FROM public.driver_wallet_transactions tx
        WHERE tx.order_id = p_order.id AND tx.driver_id = p_driver_id
          AND tx.status = 'completed' AND tx.transaction_type = 'cod_release'
          AND tx.metadata->>'purpose' = 'paid_goods_deposit') THEN
      RAISE EXCEPTION 'GOODS_DEPOSIT_ALREADY_RELEASED';
    END IF;
    RETURN;
  END IF;
  SELECT COALESCE(sum(tx.available_delta), 0)::bigint INTO v_balance
    FROM public.driver_wallet_transactions tx
    WHERE tx.driver_id = p_driver_id AND tx.status = 'completed';
  IF v_balance < p_order.driver_advance_amount THEN
    RAISE EXCEPTION 'INSUFFICIENT_WALLET_BALANCE_AT_PICKUP';
  END IF;
  INSERT INTO public.driver_wallet_transactions(
    driver_id, order_id, transaction_type, amount, available_delta, held_delta,
    idempotency_key, completed_at, metadata
  ) VALUES (
    p_driver_id, p_order.id, 'cod_hold', p_order.driver_advance_amount,
    -p_order.driver_advance_amount, p_order.driver_advance_amount,
    v_key, clock_timestamp(),
    jsonb_build_object('purpose', 'paid_goods_deposit', 'reason', 'pickup')
  );
END;
$function$;

CREATE OR REPLACE FUNCTION private.release_paid_goods_deposit(
  p_order public.orders, p_driver_id uuid, p_reason text,
  p_reference_id uuid DEFAULT NULL, p_require_hold boolean DEFAULT false
)
RETURNS bigint LANGUAGE plpgsql SET search_path = ''
AS $function$
DECLARE
  v_held bigint;
  v_released bigint;
  v_held_balance bigint;
  v_invalid boolean;
BEGIN
  IF NOT private.is_paid_goods_deposit_order(p_order) THEN RETURN 0; END IF;
  IF p_driver_id IS NULL OR p_order.driver_id IS DISTINCT FROM p_driver_id THEN
    RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_driver_id::text, 0)
  );
  SELECT
    COALESCE(sum(tx.amount) FILTER (WHERE tx.transaction_type = 'cod_hold'), 0),
    COALESCE(sum(tx.amount) FILTER (WHERE tx.transaction_type = 'cod_release'), 0),
    COALESCE(sum(tx.held_delta), 0),
    COALESCE(bool_or(NOT (
      (tx.transaction_type = 'cod_hold' AND tx.amount > 0
        AND tx.available_delta = -tx.amount AND tx.held_delta = tx.amount)
      OR (tx.transaction_type = 'cod_release' AND tx.amount > 0
        AND tx.available_delta = tx.amount AND tx.held_delta = -tx.amount)
    )), false)
  INTO v_held, v_released, v_held_balance, v_invalid
  FROM public.driver_wallet_transactions tx
  WHERE tx.order_id = p_order.id AND tx.driver_id = p_driver_id
    AND tx.status = 'completed' AND tx.metadata->>'purpose' = 'paid_goods_deposit';
  IF v_held = 0 AND v_released = 0 AND NOT v_invalid THEN
    IF p_require_hold THEN RAISE EXCEPTION 'GOODS_DEPOSIT_HOLD_REQUIRED'; END IF;
    RETURN 0;
  END IF;
  IF v_invalid OR v_held <> p_order.driver_advance_amount
    OR v_released NOT IN (0, v_held) OR v_held_balance <> v_held - v_released THEN
    RAISE EXCEPTION 'GOODS_DEPOSIT_LEDGER_MISMATCH';
  END IF;
  IF v_released = v_held THEN RETURN 0; END IF;
  INSERT INTO public.driver_wallet_transactions(
    driver_id, order_id, transaction_type, amount, available_delta, held_delta,
    idempotency_key, completed_at, metadata
  ) VALUES (
    p_driver_id, p_order.id, 'cod_release', v_held, v_held, -v_held,
    'order:' || p_order.id::text || ':driver:' || p_driver_id::text
      || ':paid_goods_deposit_release',
    clock_timestamp(), jsonb_build_object(
      'purpose', 'paid_goods_deposit', 'reason', p_reason,
      'reference_id', p_reference_id
    )
  );
  RETURN v_held;
END;
$function$;

REVOKE ALL ON FUNCTION private.is_paid_goods_deposit_order(public.orders)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.hold_paid_goods_deposit(public.orders, uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.release_paid_goods_deposit(public.orders, uuid, text, uuid, boolean)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_customer_order_payment_session(p_customer_id uuid, p_order_payload jsonb, p_txn_ref text)
 RETURNS TABLE(session_id uuid, txn_ref text, amount bigint, status text, expires_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_session public.order_payment_sessions%ROWTYPE;
  v_amount bigint;
  v_fee_payer text;
  v_cod_amount bigint;
  v_goods_value bigint;
BEGIN
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

  -- Validate before taking a VNPAY payment, then store the server-owned policy
  -- marker in the existing session payload so older pending sessions still work.
  IF v_cod_amount = 0 AND (v_goods_value <= 0 OR v_goods_value > 2000000) THEN
    RAISE EXCEPTION 'PAID_GOODS_VALUE_REQUIRED';
  END IF;

  INSERT INTO public.order_payment_sessions (
    customer_id, provider_txn_ref, amount, status,
    order_payload, expires_at
  ) VALUES (
    p_customer_id, btrim(p_txn_ref), v_amount, 'pending',
    (p_order_payload - 'paid_goods_deposit_version') || jsonb_build_object(
      'delivery_fee_payer', 'sender',
      'paid_goods_deposit_version', CASE WHEN v_cod_amount = 0 THEN 1 ELSE 0 END
    ),
    clock_timestamp() + interval '15 minutes'
  ) RETURNING * INTO v_session;

  RETURN QUERY SELECT v_session.id, v_session.provider_txn_ref,
    v_session.amount, v_session.status, v_session.expires_at;
END;
$function$;

CREATE OR REPLACE FUNCTION private.create_customer_order_from_payload(p_customer_id uuid, p_order_payload jsonb, p_payment_status text, p_paid_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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
  v_paid_goods_deposit boolean;
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

  v_paid_goods_deposit := v_fee_payer = 'sender' AND v_cod_amount = 0
    AND p_order_payload->>'paid_goods_deposit_version' = '1';
  IF v_paid_goods_deposit AND (v_goods_value <= 0 OR v_goods_value > 2000000) THEN
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

CREATE OR REPLACE FUNCTION public.confirm_driver_pickup(p_order_id uuid)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_driver_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_confirmed_at timestamptz;
BEGIN
  IF v_driver_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users actor
    WHERE actor.id = v_driver_id AND actor.role = 'driver'::public.user_role
  ) THEN RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED'; END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.driver_id IS DISTINCT FROM v_driver_id
    THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED'; END IF;
  IF v_order.status <> 'picking_up'::public.order_status
    THEN RAISE EXCEPTION 'ORDER_NOT_PICKING_UP'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.risk_report_interventions intervention
    WHERE intervention.order_id = v_order.id
      AND intervention.driver_id = v_driver_id
      AND intervention.state IN ('return_required', 'handoff_required')
  ) THEN RAISE EXCEPTION 'CUSTODY_ACTION_REQUIRED'; END IF;

  -- Reserve principal and confirm custody atomically; failed proof validation
  -- also rolls this hold back through the existing handoff trigger.
  PERFORM private.hold_paid_goods_deposit(v_order, v_driver_id);

  IF v_order.actual_picked_up_at IS NOT NULL THEN
    RETURN v_order.actual_picked_up_at;
  END IF;

  UPDATE public.orders
  SET actual_picked_up_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE id = p_order_id
  RETURNING actual_picked_up_at INTO v_confirmed_at;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, 'picking_up'::public.order_status, 'Tài xế đã nhận hàng',
    'Tài xế đã xác nhận nhận kiện và đang chờ bắt đầu giao.', v_driver_id
  );
  RETURN v_confirmed_at;
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
    AND private.is_paid_goods_deposit_order(v_order) THEN
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

CREATE OR REPLACE FUNCTION public.confirm_order_return(p_order_id uuid, p_receiver_name text, p_note text DEFAULT NULL::text)
 RETURNS order_returns
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  return_order public.orders%ROWTYPE;
  order_return public.order_returns%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  return_proof public.order_delivery_proofs%ROWTYPE;
  distance_m double precision;
  delivery_earning bigint;
  advance_refunded boolean := false;
  normalized_receiver text := trim(COALESCE(p_receiver_name, ''));
  normalized_note text := NULLIF(trim(p_note), '');
BEGIN
  IF actor_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF char_length(normalized_receiver) NOT BETWEEN 2 AND 80 THEN
    RAISE EXCEPTION 'RETURN_RECEIVER_REQUIRED' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO return_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;

  SELECT * INTO order_return
  FROM public.order_returns
  WHERE order_id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RETURN_NOT_FOUND'; END IF;

  IF return_order.driver_id IS DISTINCT FROM actor_id
    OR order_return.driver_id IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED' USING ERRCODE = '42501';
  END IF;
  IF return_order.status = 'returned'::public.order_status
    AND order_return.status = 'returned' THEN
    RETURN order_return;
  END IF;
  IF return_order.status <> 'returning'::public.order_status
    OR order_return.status <> 'returning' THEN
    RAISE EXCEPTION 'INVALID_RETURN_COMPLETE_STATE'
      USING ERRCODE = '23514';
  END IF;

  SELECT * INTO return_proof
  FROM public.order_delivery_proofs AS proof
  WHERE proof.order_id = p_order_id
    AND proof.driver_id = actor_id
    AND proof.stage = 'return'
  FOR UPDATE;
  IF NOT FOUND OR return_proof.captured_lat IS NULL
    OR return_proof.captured_lng IS NULL THEN
    RAISE EXCEPTION 'RETURN_PROOF_REQUIRED' USING ERRCODE = '23514';
  END IF;

  distance_m := 6371000 * acos(least(1.0, greatest(-1.0,
    cos(radians(order_return.destination_lat))
      * cos(radians(return_proof.captured_lat))
      * cos(radians(return_proof.captured_lng)
        - radians(order_return.destination_lng))
    + sin(radians(order_return.destination_lat))
      * sin(radians(return_proof.captured_lat))
  )));
  IF distance_m > 150 THEN
    RAISE EXCEPTION 'RETURN_OUTSIDE_GEOFENCE' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO intervention
  FROM public.risk_report_interventions
  WHERE risk_report_id = order_return.risk_report_id
  FOR UPDATE;
  IF intervention.state <> 'return_required' THEN
    RAISE EXCEPTION 'RETURN_INTERVENTION_MISMATCH' USING ERRCODE = '23514';
  END IF;

  delivery_earning := round(greatest(COALESCE(
    return_order.driver_net_earning,
    return_order.delivery_fee,
    0
  ), 0))::bigint;

  UPDATE public.orders SET
    status = 'returned'::public.order_status,
    risk_hold_report_id = NULL,
    status_note = COALESCE(normalized_note, 'Đã hoàn hàng về điểm trả.'),
    updated_at = clock_timestamp()
  WHERE id = p_order_id;

  UPDATE public.order_returns SET
    status = 'returned',
    fee_status = 'settled',
    receiver_name = normalized_receiver,
    proof_storage_path = return_proof.storage_path,
    arrived_at = COALESCE(arrived_at, return_proof.captured_at),
    returned_at = COALESCE(returned_at, clock_timestamp()),
    updated_at = clock_timestamp()
  WHERE id = order_return.id
  RETURNING * INTO order_return;

  UPDATE public.risk_report_interventions SET
    state = 'released',
    driver_released_at = clock_timestamp(),
    updated_at = clock_timestamp()
  WHERE risk_report_id = order_return.risk_report_id;

  UPDATE public.risk_reports SET
    status = 'resolved',
    resolution = COALESCE(normalized_note, 'Đã hoàn hàng về điểm trả.'),
    resolved_at = clock_timestamp(),
    updated_by = actor_id,
    updated_at = clock_timestamp()
  WHERE id = order_return.risk_report_id;

  INSERT INTO public.driver_wallet_transactions (
    driver_id, order_id, transaction_type, amount, available_delta,
    idempotency_key, completed_at, metadata
  ) VALUES (
    actor_id,
    p_order_id,
    'return_delivery_earning',
    delivery_earning,
    delivery_earning,
    'order:' || p_order_id::text || ':return_delivery_earning',
    clock_timestamp(),
    jsonb_build_object(
      'return_id', order_return.id,
      'delivery_fee', round(return_order.delivery_fee)::bigint,
      'earning_kind', 'original_delivery_fee_for_returned_order'
    )
  ) ON CONFLICT (idempotency_key) DO NOTHING;

  INSERT INTO public.driver_wallet_transactions (
    driver_id, order_id, transaction_type, amount, available_delta,
    idempotency_key, completed_at, metadata
  ) VALUES (
    actor_id, p_order_id, 'return_earning',
    order_return.driver_return_earning,
    order_return.driver_return_earning,
    'order:' || p_order_id::text || ':return_earning',
    clock_timestamp(),
    jsonb_build_object(
      'return_id', order_return.id,
      'distance_m', order_return.route_distance_m,
      'fee_payer', order_return.fee_payer,
      'return_fee_rate_bps', 5000,
      'delivery_fee', round(return_order.delivery_fee)::bigint
    )
  ) ON CONFLICT (idempotency_key) DO NOTHING;

  advance_refunded := private.release_paid_goods_deposit(
    return_order, actor_id, 'completed_physical_return', order_return.id
  ) > 0;

  IF return_order.cod_collection_amount > 0 AND EXISTS (
    SELECT 1
    FROM public.driver_wallet_transactions AS capture
    WHERE capture.order_id = p_order_id
      AND capture.driver_id = actor_id
      AND capture.transaction_type = 'cod_advance_capture'
      AND capture.status = 'completed'
  ) THEN
    INSERT INTO public.driver_wallet_transactions (
      driver_id, order_id, transaction_type, amount, available_delta,
      idempotency_key, completed_at, metadata
    ) VALUES (
      actor_id,
      p_order_id,
      'cod_release',
      return_order.driver_advance_amount,
      return_order.driver_advance_amount,
      'order:' || p_order_id::text || ':return_cod_release',
      clock_timestamp(),
      jsonb_build_object(
        'return_id', order_return.id,
        'reason', 'completed_physical_return'
      )
    ) ON CONFLICT (idempotency_key) DO NOTHING;
    advance_refunded := true;
  END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, 'returned'::public.order_status,
    'Hoàn hàng đã ghi nhận',
    'Kiện hàng đã được bàn giao cho ' || normalized_receiver
      || '. Cước giao và phí hoàn hàng đã được ghi nhận cho tài xế.',
    actor_id
  );

  INSERT INTO public.risk_report_events (
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (
    order_return.risk_report_id, actor_id, 'return_completed',
    'action_required', 'resolved',
    jsonb_build_object(
      'return_id', order_return.id,
      'receiver_name', normalized_receiver,
      'proof_storage_path', return_proof.storage_path,
      'driver_delivery_earning', delivery_earning,
      'return_fee_amount', order_return.driver_return_earning,
      'driver_total_earning',
        delivery_earning + order_return.driver_return_earning,
      'driver_advance_refunded', advance_refunded
    )
  );

  PERFORM private.enqueue_case_notification(
    return_order.customer_id,
    'Đã hoàn hàng',
    'Kiện hàng đã được bàn giao lại thành công.',
    'order_return_completed',
    return_order.id
  );
  PERFORM private.enqueue_case_notification(
    actor_id,
    'Hoàn hàng đã ghi nhận',
    'Cước giao và phí hoàn hàng đã được cộng vào Ví Tài Xế.',
    'order_return_completed',
    return_order.id
  );
  RETURN order_return;
END;
$function$;

CREATE OR REPLACE FUNCTION public.confirm_risk_custody_resolved(p_report_id uuid, p_note text DEFAULT NULL::text)
 RETURNS risk_report_interventions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  report public.risk_reports%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  custody_order public.orders%ROWTYPE;
  v_deposit_refunded bigint := 0;
BEGIN
  SELECT role INTO actor_role FROM public.users WHERE id = actor_id;
  SELECT * INTO report FROM public.risk_reports
    WHERE id = p_report_id FOR UPDATE;
  SELECT * INTO intervention FROM public.risk_report_interventions
    WHERE risk_report_id = p_report_id FOR UPDATE;
  IF intervention.state = 'return_required' THEN
    RAISE EXCEPTION 'RETURN_WORKFLOW_REQUIRED' USING ERRCODE = '23514';
  END IF;
  IF actor_id IS NULL OR actor_role NOT IN (
      'support'::public.user_role,
      'admin'::public.user_role
    ) THEN
    RAISE EXCEPTION 'STAFF_REQUIRED' USING ERRCODE = '42501';
  END IF;
  IF intervention.state <> 'handoff_required' THEN
    RAISE EXCEPTION 'NO_HANDOFF_PENDING' USING ERRCODE = '23514';
  END IF;
  SELECT * INTO custody_order FROM public.orders
  WHERE id = report.order_id FOR UPDATE;
  IF custody_order.status NOT IN (
      'picking_up'::public.order_status,
      'delivering'::public.order_status
    ) OR custody_order.driver_id IS DISTINCT FROM intervention.driver_id THEN
    RAISE EXCEPTION 'ORDER_CUSTODY_MISMATCH' USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.driver_wallet_transactions AS capture
    WHERE capture.order_id = custody_order.id
      AND capture.driver_id = intervention.driver_id
      AND capture.transaction_type = 'cod_advance_capture'
      AND capture.status = 'completed'
  ) THEN
    PERFORM private.credit_customer_cod(
      custody_order.customer_id,
      custody_order.id,
      custody_order.cod_collection_amount,
      'risk_credit',
      'order:' || custody_order.id::text || ':customer_risk_credit',
      p_report_id,
      jsonb_build_object(
        'intervention', 'handoff_required',
        'driver_id', intervention.driver_id
      )
    );
  END IF;

  v_deposit_refunded := private.release_paid_goods_deposit(
    custody_order, intervention.driver_id, 'confirmed_handoff', p_report_id
  );

  UPDATE public.orders SET
    status = 'risk_hold'::public.order_status,
    driver_id = NULL,
    risk_hold_report_id = p_report_id,
    status_note = COALESCE(NULLIF(trim(p_note), ''), intervention.instruction),
    updated_at = clock_timestamp()
  WHERE id = custody_order.id;
  UPDATE public.risk_report_interventions SET
    state = 'released',
    driver_released_at = clock_timestamp(),
    updated_at = clock_timestamp()
  WHERE risk_report_id = p_report_id
  RETURNING * INTO intervention;
  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    custody_order.id, 'risk_hold'::public.order_status,
    'Đã bàn giao hàng',
    COALESCE(NULLIF(trim(p_note), ''), intervention.instruction), actor_id
  );
  INSERT INTO public.risk_report_events (
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (
    p_report_id, actor_id, 'intervention_changed', report.status,
    report.status,
    jsonb_build_object(
      'state', 'released',
      'driver_advance_refunded', v_deposit_refunded > 0,
      'driver_goods_deposit_refunded', v_deposit_refunded
    )
  );
  RETURN intervention;
END;
$function$;

CREATE OR REPLACE FUNCTION private.enforce_order_payment_activation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.delivery_fee_payer = 'sender' THEN
      IF current_user NOT IN ('postgres', 'service_role', 'supabase_admin') THEN
        RAISE EXCEPTION 'ORDER_PAYMENT_ACTIVATION_FORBIDDEN';
      END IF;
      IF NEW.payment_status <> 'paid' OR NEW.paid_at IS NULL THEN
        RAISE EXCEPTION 'ORDER_PAYMENT_REQUIRED';
      END IF;
    ELSIF NEW.payment_status <> 'not_required' OR NEW.paid_at IS NOT NULL THEN
      RAISE EXCEPTION 'ORDER_PAYMENT_NOT_REQUIRED';
    END IF;
  ELSIF (
    NEW.delivery_fee_payer IS DISTINCT FROM OLD.delivery_fee_payer
    OR NEW.payment_status IS DISTINCT FROM OLD.payment_status
    OR NEW.paid_at IS DISTINCT FROM OLD.paid_at
  ) AND current_user NOT IN ('postgres', 'service_role', 'supabase_admin') THEN
    RAISE EXCEPTION 'ORDER_PAYMENT_FIELDS_SERVER_MANAGED';
  END IF;

  -- A paid-goods snapshot cannot be rewritten or its wallet commands bypassed
  -- through a direct client UPDATE. Existing RPCs execute as their trusted owner.
  IF TG_OP = 'UPDATE'
    AND current_user NOT IN ('postgres', 'service_role', 'supabase_admin')
    AND (
      (OLD.cod_collection_amount = 0 AND OLD.goods_value > 0
        AND OLD.driver_advance_amount = OLD.goods_value)
      OR (NEW.cod_collection_amount = 0 AND NEW.goods_value > 0
        AND NEW.driver_advance_amount = NEW.goods_value)
    ) THEN
    IF ROW(NEW.goods_value, NEW.cod_collection_amount, NEW.driver_advance_amount,
        NEW.receiver_collection_amount, NEW.driver_net_earning, NEW.delivery_fee,
        NEW.total_price, NEW.platform_fee_amount, NEW.platform_fee_rate_bps)
      IS DISTINCT FROM ROW(OLD.goods_value, OLD.cod_collection_amount,
        OLD.driver_advance_amount, OLD.receiver_collection_amount,
        OLD.driver_net_earning, OLD.delivery_fee, OLD.total_price,
        OLD.platform_fee_amount, OLD.platform_fee_rate_bps) THEN
      RAISE EXCEPTION 'ORDER_FINANCE_SERVER_MANAGED';
    END IF;
    IF NEW.status IS DISTINCT FROM OLD.status
      OR NEW.actual_picked_up_at IS DISTINCT FROM OLD.actual_picked_up_at
      OR NEW.actual_delivered_at IS DISTINCT FROM OLD.actual_delivered_at THEN
      RAISE EXCEPTION 'GOODS_DEPOSIT_COMMAND_REQUIRED';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

-- The old trigger watched only payment columns. Include the existing financial
-- and workflow columns so direct client edits cannot bypass the deposit RPCs.
DROP TRIGGER orders_enforce_payment_activation ON public.orders;
CREATE TRIGGER orders_enforce_payment_activation
BEFORE INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION private.enforce_order_payment_activation();
