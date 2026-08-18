-- Minimal finance architecture: reuse orders/order_items and add only a
-- wallet ledger plus a generic settings table.

ALTER TABLE public.orders
  ADD COLUMN payment_mode text NOT NULL DEFAULT 'cod',
  ADD COLUMN goods_value bigint NOT NULL DEFAULT 0,
  ADD COLUMN platform_fee_rate_bps integer NOT NULL DEFAULT 1500,
  ADD COLUMN platform_fee_amount bigint NOT NULL DEFAULT 0,
  ADD COLUMN driver_net_earning bigint NOT NULL DEFAULT 0,
  ADD COLUMN driver_advance_amount bigint NOT NULL DEFAULT 0,
  ADD COLUMN receiver_collection_amount bigint NOT NULL DEFAULT 0;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_payment_mode_check
    CHECK (payment_mode IN ('prepaid', 'cod')),
  ADD CONSTRAINT orders_goods_value_non_negative_check
    CHECK (goods_value >= 0),
  ADD CONSTRAINT orders_platform_fee_rate_bps_check
    CHECK (platform_fee_rate_bps BETWEEN 0 AND 10000),
  ADD CONSTRAINT orders_platform_fee_amount_non_negative_check
    CHECK (platform_fee_amount >= 0),
  ADD CONSTRAINT orders_driver_net_earning_non_negative_check
    CHECK (driver_net_earning >= 0),
  ADD CONSTRAINT orders_driver_advance_amount_non_negative_check
    CHECK (driver_advance_amount >= 0),
  ADD CONSTRAINT orders_receiver_collection_amount_non_negative_check
    CHECK (receiver_collection_amount >= 0);

-- The legacy app wrote delivery_fee into order_items.price. That value cannot
-- be reconstructed as goods value, so historical goods start at zero.
UPDATE public.order_items SET price = 0;

UPDATE public.orders
SET
  total_price = round(delivery_fee),
  goods_value = 0,
  payment_mode = 'cod',
  platform_fee_rate_bps = 1500,
  platform_fee_amount = round(delivery_fee * 1500 / 10000.0)::bigint,
  driver_net_earning = greatest(
    0,
    round(delivery_fee)::bigint
      - round(delivery_fee * 1500 / 10000.0)::bigint
  ),
  driver_advance_amount = 0,
  receiver_collection_amount = round(delivery_fee)::bigint;

CREATE TABLE public.driver_wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  order_id uuid REFERENCES public.orders(id) ON DELETE RESTRICT,
  transaction_type text NOT NULL CHECK (
    transaction_type IN (
      'vnpay_topup',
      'cod_hold',
      'cod_release',
      'cod_advance_capture',
      'platform_fee_capture',
      'prepaid_earning',
      'cod_settlement'
    )
  ),
  status text NOT NULL DEFAULT 'completed' CHECK (
    status IN ('pending', 'completed', 'failed', 'expired')
  ),
  amount bigint NOT NULL CHECK (amount >= 0),
  available_delta bigint NOT NULL DEFAULT 0,
  held_delta bigint NOT NULL DEFAULT 0,
  provider text,
  provider_txn_ref text UNIQUE,
  provider_transaction_no text,
  provider_response_code text,
  idempotency_key text NOT NULL UNIQUE,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  completed_at timestamptz,
  CONSTRAINT driver_wallet_topup_provider_check CHECK (
    transaction_type <> 'vnpay_topup'
    OR (provider = 'vnpay' AND provider_txn_ref IS NOT NULL)
  )
);

CREATE INDEX driver_wallet_transactions_driver_created_idx
  ON public.driver_wallet_transactions (driver_id, created_at DESC);
CREATE INDEX driver_wallet_transactions_order_idx
  ON public.driver_wallet_transactions (order_id)
  WHERE order_id IS NOT NULL;

CREATE TABLE public.system_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  updated_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

INSERT INTO public.system_settings (key, value)
VALUES ('platform_fee_rate_bps', to_jsonb(1500))
ON CONFLICT (key) DO NOTHING;

ALTER TABLE public.driver_wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.driver_wallet_transactions FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE ON public.driver_wallet_transactions
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.driver_wallet_transactions TO authenticated;

REVOKE ALL ON public.system_settings FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE ON public.system_settings
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.system_settings TO authenticated;

CREATE POLICY driver_wallet_transactions_select_related
  ON public.driver_wallet_transactions
  FOR SELECT
  TO authenticated
  USING (
    driver_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.users viewer
      WHERE viewer.id = (SELECT auth.uid())
        AND viewer.role IN (
          'support'::public.user_role,
          'admin'::public.user_role
        )
    )
  );

CREATE POLICY system_settings_select_authenticated
  ON public.system_settings
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

CREATE OR REPLACE FUNCTION public.get_platform_fee_rate()
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT COALESCE(
    (
      SELECT (setting.value #>> '{}')::integer
      FROM public.system_settings setting
      WHERE setting.key = 'platform_fee_rate_bps'
    ),
    1500
  );
$function$;

CREATE OR REPLACE FUNCTION public.update_platform_fee_rate(
  p_rate_bps integer
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_admin_user_id uuid := auth.uid();
BEGIN
  IF v_admin_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.users app_user
    WHERE app_user.id = v_admin_user_id
      AND app_user.role = 'admin'::public.user_role
  ) THEN
    RAISE EXCEPTION 'ADMIN_ROLE_REQUIRED';
  END IF;
  IF p_rate_bps IS NULL OR p_rate_bps < 0 OR p_rate_bps > 5000 THEN
    RAISE EXCEPTION 'PLATFORM_FEE_RATE_INVALID';
  END IF;

  INSERT INTO public.system_settings (key, value, updated_by, updated_at)
  VALUES (
    'platform_fee_rate_bps',
    to_jsonb(p_rate_bps),
    v_admin_user_id,
    clock_timestamp()
  )
  ON CONFLICT (key) DO UPDATE
  SET
    value = EXCLUDED.value,
    updated_by = EXCLUDED.updated_by,
    updated_at = EXCLUDED.updated_at;

  RETURN p_rate_bps;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_driver_wallet_summary()
RETURNS TABLE(
  available_balance bigint,
  held_balance bigint,
  today_income bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_driver_user_id uuid := auth.uid();
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.drivers driver
    WHERE driver.user_id = v_driver_user_id
  ) THEN
    RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE((
      SELECT sum(tx.available_delta)
      FROM public.driver_wallet_transactions tx
      WHERE tx.driver_id = v_driver_user_id
        AND tx.status = 'completed'
    ), 0)::bigint,
    COALESCE((
      SELECT sum(tx.held_delta)
      FROM public.driver_wallet_transactions tx
      WHERE tx.driver_id = v_driver_user_id
        AND tx.status = 'completed'
    ), 0)::bigint,
    COALESCE((
      SELECT sum(delivery.driver_net_earning)
      FROM public.orders delivery
      WHERE delivery.driver_id = v_driver_user_id
        AND delivery.status = 'delivered'::public.order_status
        AND delivery.actual_delivered_at >= date_trunc('day', now())
        AND delivery.actual_delivered_at < date_trunc('day', now()) + interval '1 day'
    ), 0)::bigint;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_driver_wallet_transactions(
  p_limit integer DEFAULT 30
)
RETURNS SETOF public.driver_wallet_transactions
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_driver_user_id uuid := auth.uid();
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
    RAISE EXCEPTION 'WALLET_TRANSACTION_LIMIT_INVALID';
  END IF;

  RETURN QUERY
  SELECT tx.*
  FROM public.driver_wallet_transactions tx
  WHERE tx.driver_id = v_driver_user_id
  ORDER BY tx.created_at DESC
  LIMIT p_limit;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_driver_wallet_topup(
  p_amount bigint,
  p_txn_ref text
)
RETURNS TABLE(
  topup_id uuid,
  txn_ref text,
  amount bigint,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_driver_user_id uuid := auth.uid();
  v_topup public.driver_wallet_transactions%ROWTYPE;
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.drivers driver
    WHERE driver.user_id = v_driver_user_id
      AND driver.approval_status = 'approved'::public.approval_status
  ) THEN
    RAISE EXCEPTION 'APPROVED_DRIVER_REQUIRED';
  END IF;
  IF p_amount IS NULL OR p_amount < 5000 OR p_amount > 10000000 THEN
    RAISE EXCEPTION 'TOPUP_AMOUNT_INVALID';
  END IF;
  IF NULLIF(btrim(p_txn_ref), '') IS NULL THEN
    RAISE EXCEPTION 'TOPUP_TXN_REF_REQUIRED';
  END IF;

  INSERT INTO public.driver_wallet_transactions (
    driver_id,
    transaction_type,
    status,
    amount,
    provider,
    provider_txn_ref,
    idempotency_key
  )
  VALUES (
    v_driver_user_id,
    'vnpay_topup',
    'pending',
    p_amount,
    'vnpay',
    btrim(p_txn_ref),
    'vnpay:' || btrim(p_txn_ref)
  )
  RETURNING * INTO v_topup;

  RETURN QUERY
  SELECT v_topup.id, v_topup.provider_txn_ref, v_topup.amount, v_topup.status;
END;
$function$;

CREATE OR REPLACE FUNCTION public.complete_driver_wallet_topup(
  p_txn_ref text,
  p_vnp_transaction_no text,
  p_success boolean,
  p_response_code text
)
RETURNS TABLE(
  topup_id uuid,
  driver_id uuid,
  status text,
  credited boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_topup public.driver_wallet_transactions%ROWTYPE;
BEGIN
  SELECT *
  INTO v_topup
  FROM public.driver_wallet_transactions tx
  WHERE tx.provider = 'vnpay'
    AND tx.provider_txn_ref = btrim(p_txn_ref)
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'TOPUP_NOT_FOUND';
  END IF;

  IF v_topup.status <> 'pending' THEN
    RETURN QUERY
    SELECT v_topup.id, v_topup.driver_id, v_topup.status, false;
    RETURN;
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_topup.driver_id::text, 0)
  );

  UPDATE public.driver_wallet_transactions tx
  SET
    status = CASE WHEN p_success THEN 'completed' ELSE 'failed' END,
    available_delta = CASE WHEN p_success THEN tx.amount ELSE 0 END,
    provider_transaction_no = NULLIF(btrim(p_vnp_transaction_no), ''),
    provider_response_code = NULLIF(btrim(p_response_code), ''),
    completed_at = clock_timestamp()
  WHERE tx.id = v_topup.id
  RETURNING * INTO v_topup;

  RETURN QUERY
  SELECT v_topup.id, v_topup.driver_id, v_topup.status, p_success;
END;
$function$;

-- Replace the old overload so PostgREST never sees two ambiguous RPCs.
DROP FUNCTION public.create_customer_order(
  text, double precision, double precision, text, double precision,
  double precision, numeric, text, timestamptz, timestamptz, text, text,
  numeric, text, text, text, text, text, text, integer, numeric
);

CREATE FUNCTION public.create_customer_order(
  p_pickup_address text,
  p_pickup_lat double precision,
  p_pickup_lng double precision,
  p_delivery_address text,
  p_delivery_lat double precision,
  p_delivery_lng double precision,
  p_total_price numeric DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_estimated_pickup_at timestamptz DEFAULT NULL,
  p_estimated_delivery_at timestamptz DEFAULT NULL,
  p_recipient_name text DEFAULT NULL,
  p_recipient_phone text DEFAULT NULL,
  p_delivery_fee numeric DEFAULT 0,
  p_service_type text DEFAULT 'standard',
  p_payment_method text DEFAULT 'cash',
  p_item_name text DEFAULT NULL,
  p_item_category text DEFAULT NULL,
  p_item_description text DEFAULT NULL,
  p_item_image_url text DEFAULT NULL,
  p_item_quantity integer DEFAULT 1,
  p_item_price numeric DEFAULT NULL,
  p_payment_mode text DEFAULT 'cod'
)
RETURNS TABLE(order_id uuid, tracking_code text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_customer_user_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_item_name text := NULLIF(btrim(p_item_name), '');
  v_service_type text;
  v_payment_mode text;
  v_delivery_fee bigint;
  v_unit_price bigint;
  v_goods_value bigint;
  v_fee_rate_bps integer;
  v_platform_fee bigint;
BEGIN
  IF v_customer_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users customer_user
    WHERE customer_user.id = v_customer_user_id
      AND customer_user.role = 'customer'::public.user_role
  ) THEN
    RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED';
  END IF;
  IF NULLIF(btrim(p_pickup_address), '') IS NULL
     OR NULLIF(btrim(p_delivery_address), '') IS NULL THEN
    RAISE EXCEPTION 'ORDER_ADDRESS_REQUIRED';
  END IF;
  IF p_pickup_lat IS NULL OR p_pickup_lng IS NULL
     OR p_delivery_lat IS NULL OR p_delivery_lng IS NULL THEN
    RAISE EXCEPTION 'ORDER_COORDINATES_REQUIRED';
  END IF;
  IF COALESCE(p_delivery_fee, 0) < 0
     OR COALESCE(p_item_price, 0) < 0
     OR COALESCE(p_item_quantity, 0) <= 0
     OR COALESCE(p_delivery_fee, 0) <> trunc(COALESCE(p_delivery_fee, 0))
     OR COALESCE(p_item_price, 0) <> trunc(COALESCE(p_item_price, 0)) THEN
    RAISE EXCEPTION 'ORDER_PRICE_INVALID';
  END IF;

  v_payment_mode := lower(COALESCE(NULLIF(btrim(p_payment_mode), ''), 'cod'));
  IF v_payment_mode NOT IN ('prepaid', 'cod') THEN
    RAISE EXCEPTION 'ORDER_PAYMENT_MODE_INVALID';
  END IF;

  v_service_type := CASE
    WHEN p_service_type = 'bulky' THEN 'fragile'
    WHEN p_service_type IN ('standard', 'express', 'fragile', 'document')
      THEN p_service_type
    ELSE 'standard'
  END;
  v_delivery_fee := round(COALESCE(p_delivery_fee, 0))::bigint;
  v_unit_price := round(COALESCE(p_item_price, 0))::bigint;
  v_goods_value := v_unit_price * COALESCE(p_item_quantity, 1);
  v_fee_rate_bps := public.get_platform_fee_rate();
  v_platform_fee := round(v_delivery_fee * v_fee_rate_bps / 10000.0)::bigint;

  INSERT INTO public.orders (
    customer_id, status, pickup_address, pickup_lat, pickup_lng,
    delivery_address, delivery_lat, delivery_lng, total_price, note,
    estimated_pickup_at, estimated_delivery_at, recipient_name,
    recipient_phone, delivery_fee, service_type, payment_method, item_name,
    item_category, item_description, item_image_url, payment_mode,
    goods_value, platform_fee_rate_bps, platform_fee_amount,
    driver_net_earning, driver_advance_amount, receiver_collection_amount
  ) VALUES (
    v_customer_user_id, 'pending'::public.order_status,
    btrim(p_pickup_address), p_pickup_lat, p_pickup_lng,
    btrim(p_delivery_address), p_delivery_lat, p_delivery_lng,
    v_goods_value + v_delivery_fee, NULLIF(btrim(p_note), ''),
    p_estimated_pickup_at, p_estimated_delivery_at,
    NULLIF(btrim(p_recipient_name), ''),
    NULLIF(btrim(p_recipient_phone), ''), v_delivery_fee, v_service_type,
    COALESCE(NULLIF(btrim(p_payment_method), ''), 'cash'), v_item_name,
    NULLIF(btrim(p_item_category), ''),
    NULLIF(btrim(p_item_description), ''),
    NULLIF(btrim(p_item_image_url), ''), v_payment_mode, v_goods_value,
    v_fee_rate_bps, v_platform_fee, v_delivery_fee - v_platform_fee,
    CASE WHEN v_payment_mode = 'cod' THEN v_goods_value ELSE 0 END,
    CASE WHEN v_payment_mode = 'cod'
      THEN v_goods_value + v_delivery_fee ELSE 0 END
  ) RETURNING * INTO v_order;

  IF v_item_name IS NOT NULL THEN
    INSERT INTO public.order_items (order_id, name, quantity, price)
    VALUES (v_order.id, v_item_name, p_item_quantity, v_unit_price);
  END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    v_order.id, 'pending'::public.order_status, 'Đã tạo đơn',
    'Đơn hàng đã được ghi nhận và đang chờ tài xế nhận.',
    v_customer_user_id
  );

  RETURN QUERY SELECT v_order.id, v_order.tracking_code;
END;
$function$;

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
  SELECT driver.is_available, driver.approval_status
  INTO v_is_available, v_approval_status
  FROM public.drivers driver WHERE driver.user_id = v_driver_user_id;
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

  SELECT * INTO v_order FROM public.orders
  WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.driver_id IS NOT NULL OR v_order.status NOT IN (
    'pending'::public.order_status, 'confirmed'::public.order_status
  ) THEN RAISE EXCEPTION 'ORDER_NOT_AVAILABLE'; END IF;
  IF v_order.assignment_timed_out_at IS NOT NULL
     OR v_order.assignment_expires_at <= clock_timestamp()
    THEN RAISE EXCEPTION 'ASSIGNMENT_EXPIRED'; END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_driver_user_id::text, 0)
  );
  IF v_order.payment_mode = 'cod' THEN
    v_required_balance := v_order.driver_advance_amount
      + v_order.platform_fee_amount;
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
    UPDATE public.orders SET driver_id = v_driver_user_id,
      status = 'assigned'::public.order_status, updated_at = clock_timestamp()
    WHERE id = p_order_id RETURNING * INTO v_order;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER';
  END;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, 'assigned'::public.order_status,
    'Đã có tài xế nhận đơn',
    'Tài xế đã nhận đơn trong thời gian chờ.', v_driver_user_id
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

  IF v_order.driver_id IS NOT NULL AND v_order.payment_mode = 'cod' THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_order.driver_id::text, 0)
    );
    v_release_amount := v_order.driver_advance_amount
      + v_order.platform_fee_amount;
    INSERT INTO public.driver_wallet_transactions (
      driver_id, order_id, transaction_type, amount,
      available_delta, held_delta, idempotency_key, completed_at
    ) VALUES (
      v_order.driver_id, v_order.id, 'cod_release', v_release_amount,
      v_release_amount, -v_release_amount,
      'order:' || v_order.id::text || ':cod_release', clock_timestamp()
    );
  END IF;

  UPDATE public.orders SET status = 'cancelled'::public.order_status,
    status_note = v_normalized_note, cancelled_at = clock_timestamp(),
    updated_at = clock_timestamp()
  WHERE id = p_order_id RETURNING * INTO v_order;

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

  IF v_order.payment_mode = 'cod'
     AND v_next_status IN (
       'delivering'::public.order_status, 'delivered'::public.order_status
     ) THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_driver_user_id::text, 0)
    );
  END IF;

  IF v_order.payment_mode = 'cod'
     AND v_next_status = 'delivering'::public.order_status THEN
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
    IF v_order.payment_mode = 'cod' THEN
      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount, held_delta,
        idempotency_key, completed_at
      ) VALUES (
        v_driver_user_id, v_order.id, 'platform_fee_capture',
        v_order.platform_fee_amount, -v_order.platform_fee_amount,
        'order:' || v_order.id::text || ':platform_fee_capture',
        clock_timestamp()
      );
      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount,
        idempotency_key, completed_at, metadata
      ) VALUES (
        v_driver_user_id, v_order.id, 'cod_settlement',
        v_order.driver_net_earning,
        'order:' || v_order.id::text || ':cod_settlement', clock_timestamp(),
        jsonb_build_object(
          'cash_collected', v_order.receiver_collection_amount,
          'goods_value', v_order.goods_value,
          'delivery_fee', round(v_order.delivery_fee)::bigint
        )
      );
    ELSE
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

  UPDATE public.orders SET status = v_next_status,
    updated_at = clock_timestamp(),
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

REVOKE ALL ON FUNCTION public.get_platform_fee_rate() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_platform_fee_rate() TO authenticated;
REVOKE ALL ON FUNCTION public.update_platform_fee_rate(integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_platform_fee_rate(integer)
  TO authenticated;
REVOKE ALL ON FUNCTION public.get_driver_wallet_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_driver_wallet_summary() TO authenticated;
REVOKE ALL ON FUNCTION public.get_driver_wallet_transactions(integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_driver_wallet_transactions(integer)
  TO authenticated;
REVOKE ALL ON FUNCTION public.create_driver_wallet_topup(bigint, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_driver_wallet_topup(bigint, text)
  TO authenticated;
REVOKE ALL ON FUNCTION public.complete_driver_wallet_topup(
  text, text, boolean, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_driver_wallet_topup(
  text, text, boolean, text
) TO service_role;

REVOKE ALL ON FUNCTION public.create_customer_order(
  text, double precision, double precision, text, double precision,
  double precision, numeric, text, timestamptz, timestamptz, text, text,
  numeric, text, text, text, text, text, text, integer, numeric, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_customer_order(
  text, double precision, double precision, text, double precision,
  double precision, numeric, text, timestamptz, timestamptz, text, text,
  numeric, text, text, text, text, text, text, integer, numeric, text
) TO authenticated;
REVOKE ALL ON FUNCTION public.accept_order(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_order(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.cancel_customer_order(uuid, uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_customer_order(uuid, uuid, text)
  TO authenticated;
REVOKE ALL ON FUNCTION public.advance_driver_order_status(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.advance_driver_order_status(uuid)
  TO authenticated;
