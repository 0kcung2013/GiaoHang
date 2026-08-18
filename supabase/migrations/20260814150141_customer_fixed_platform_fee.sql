-- Charge a fixed 1,000 VND platform fee to the customer.
-- Reuse the existing orders, wallet ledger and system_settings tables.

INSERT INTO public.system_settings (key, value, updated_at)
VALUES ('platform_fee_amount', to_jsonb(1000), clock_timestamp())
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value, updated_at = EXCLUDED.updated_at;

UPDATE public.system_settings
SET value = to_jsonb(0), updated_at = clock_timestamp()
WHERE key = 'platform_fee_rate_bps';

CREATE OR REPLACE FUNCTION public.get_platform_fee_amount()
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT COALESCE(
    (
      SELECT (setting.value #>> '{}')::bigint
      FROM public.system_settings setting
      WHERE setting.key = 'platform_fee_amount'
    ),
    1000
  );
$function$;

REVOKE ALL ON FUNCTION public.get_platform_fee_amount()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_platform_fee_amount()
  TO authenticated;

-- The percentage policy is retired and must not be changed by clients.
REVOKE ALL ON FUNCTION public.update_platform_fee_rate(integer)
  FROM PUBLIC, anon, authenticated;

-- Update only orders that have not been claimed. Assigned and historical
-- orders retain their original accounting so existing holds settle correctly.
UPDATE public.orders
SET
  total_price = goods_value + round(delivery_fee)::bigint + 1000,
  platform_fee_rate_bps = 0,
  platform_fee_amount = 1000,
  driver_net_earning = round(delivery_fee)::bigint,
  driver_advance_amount = CASE
    WHEN payment_mode = 'cod' THEN goods_value
    ELSE 0
  END,
  receiver_collection_amount = CASE
    WHEN payment_mode = 'cod'
      THEN goods_value + round(delivery_fee)::bigint + 1000
    ELSE 0
  END,
  updated_at = clock_timestamp()
WHERE driver_id IS NULL
  AND status IN (
    'pending'::public.order_status,
    'confirmed'::public.order_status
  );

CREATE OR REPLACE FUNCTION public.create_customer_order(
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
  v_platform_fee bigint;
BEGIN
  IF v_customer_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.users customer_user
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
  v_platform_fee := public.get_platform_fee_amount();

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
    v_goods_value + v_delivery_fee + v_platform_fee,
    NULLIF(btrim(p_note), ''),
    p_estimated_pickup_at, p_estimated_delivery_at,
    NULLIF(btrim(p_recipient_name), ''),
    NULLIF(btrim(p_recipient_phone), ''), v_delivery_fee, v_service_type,
    COALESCE(NULLIF(btrim(p_payment_method), ''), 'cash'), v_item_name,
    NULLIF(btrim(p_item_category), ''),
    NULLIF(btrim(p_item_description), ''),
    NULLIF(btrim(p_item_image_url), ''), v_payment_mode, v_goods_value,
    0, v_platform_fee, v_delivery_fee,
    CASE WHEN v_payment_mode = 'cod' THEN v_goods_value ELSE 0 END,
    CASE WHEN v_payment_mode = 'cod'
      THEN v_goods_value + v_delivery_fee + v_platform_fee ELSE 0 END
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
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

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

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.driver_id IS NOT NULL OR v_order.status NOT IN (
    'pending'::public.order_status, 'confirmed'::public.order_status
  ) THEN RAISE EXCEPTION 'ORDER_NOT_AVAILABLE'; END IF;
  IF v_order.assignment_timed_out_at IS NOT NULL
     OR v_order.assignment_expires_at <= clock_timestamp()
    THEN RAISE EXCEPTION 'ASSIGNMENT_EXPIRED'; END IF;
  IF v_order.offered_driver_id IS DISTINCT FROM v_driver_user_id THEN
    RAISE EXCEPTION 'ORDER_NOT_OFFERED_TO_DRIVER';
  END IF;
  IF v_order.offer_expires_at IS NULL
     OR v_order.offer_expires_at <= clock_timestamp() THEN
    RAISE EXCEPTION 'OFFER_EXPIRED';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_driver_user_id::text, 0)
  );
  IF v_order.payment_mode = 'cod' THEN
    v_required_balance := v_order.driver_advance_amount
      + CASE WHEN v_order.platform_fee_rate_bps > 0
        THEN v_order.platform_fee_amount ELSE 0 END;
    SELECT COALESCE(sum(tx.available_delta), 0)::bigint
    INTO v_available_balance
    FROM public.driver_wallet_transactions tx
    WHERE tx.driver_id = v_driver_user_id
      AND tx.status = 'completed';
    IF v_available_balance < v_required_balance THEN
      RAISE EXCEPTION 'INSUFFICIENT_WALLET_BALANCE';
    END IF;
    IF v_required_balance > 0 THEN
      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount,
        available_delta, held_delta, idempotency_key, completed_at
      ) VALUES (
        v_driver_user_id, v_order.id, 'cod_hold', v_required_balance,
        -v_required_balance, v_required_balance,
        'order:' || v_order.id::text || ':cod_hold', clock_timestamp()
      );
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

  IF v_order.driver_id IS NOT NULL AND v_order.payment_mode = 'cod' THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_order.driver_id::text, 0)
    );
    SELECT COALESCE(sum(tx.held_delta), 0)::bigint
    INTO v_release_amount
    FROM public.driver_wallet_transactions tx
    WHERE tx.driver_id = v_order.driver_id
      AND tx.order_id = v_order.id
      AND tx.status = 'completed';
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
  SET
    status = 'cancelled'::public.order_status,
    status_note = v_normalized_note,
    cancelled_at = clock_timestamp(),
    updated_at = clock_timestamp()
  WHERE id = p_order_id
  RETURNING * INTO v_order;

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
      -- Only legacy percentage-fee orders debit the Driver wallet. New fixed
      -- fees are paid by the Customer and never become a Driver transaction.
      IF v_order.platform_fee_rate_bps > 0
         AND v_order.platform_fee_amount > 0 THEN
        INSERT INTO public.driver_wallet_transactions (
          driver_id, order_id, transaction_type, amount, held_delta,
          idempotency_key, completed_at
        ) VALUES (
          v_driver_user_id, v_order.id, 'platform_fee_capture',
          v_order.platform_fee_amount, -v_order.platform_fee_amount,
          'order:' || v_order.id::text || ':platform_fee_capture',
          clock_timestamp()
        );
      END IF;
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
          'delivery_fee', round(v_order.delivery_fee)::bigint,
          'customer_platform_fee', CASE
            WHEN v_order.platform_fee_rate_bps = 0
              THEN v_order.platform_fee_amount
            ELSE 0
          END
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

  UPDATE public.orders
  SET
    status = v_next_status,
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
