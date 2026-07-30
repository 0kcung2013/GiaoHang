-- Keep customer order creation and cancellation atomic.
-- Each RPC is one PostgreSQL statement, so an exception rolls back every
-- order, item, and status-log write performed by that command.

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
  p_item_price numeric DEFAULT NULL
)
RETURNS TABLE(
  order_id uuid,
  tracking_code text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_customer_user_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_item_name text := NULLIF(btrim(p_item_name), '');
  v_service_type text;
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

  IF p_pickup_lat IS NULL
     OR p_pickup_lng IS NULL
     OR p_delivery_lat IS NULL
     OR p_delivery_lng IS NULL THEN
    RAISE EXCEPTION 'ORDER_COORDINATES_REQUIRED';
  END IF;

  IF COALESCE(p_delivery_fee, 0) < 0
     OR COALESCE(p_total_price, 0) < 0
     OR COALESCE(p_item_price, 0) < 0 THEN
    RAISE EXCEPTION 'ORDER_PRICE_INVALID';
  END IF;

  IF v_item_name IS NOT NULL AND COALESCE(p_item_quantity, 0) <= 0 THEN
    RAISE EXCEPTION 'ORDER_ITEM_QUANTITY_INVALID';
  END IF;

  v_service_type := CASE
    WHEN p_service_type = 'bulky' THEN 'fragile'
    WHEN p_service_type IN ('standard', 'express', 'fragile', 'document')
      THEN p_service_type
    ELSE 'standard'
  END;

  INSERT INTO public.orders (
    customer_id,
    status,
    pickup_address,
    pickup_lat,
    pickup_lng,
    delivery_address,
    delivery_lat,
    delivery_lng,
    total_price,
    note,
    estimated_pickup_at,
    estimated_delivery_at,
    recipient_name,
    recipient_phone,
    delivery_fee,
    service_type,
    payment_method,
    item_name,
    item_category,
    item_description,
    item_image_url
  )
  VALUES (
    v_customer_user_id,
    'pending'::public.order_status,
    btrim(p_pickup_address),
    p_pickup_lat,
    p_pickup_lng,
    btrim(p_delivery_address),
    p_delivery_lat,
    p_delivery_lng,
    p_total_price,
    NULLIF(btrim(p_note), ''),
    p_estimated_pickup_at,
    p_estimated_delivery_at,
    NULLIF(btrim(p_recipient_name), ''),
    NULLIF(btrim(p_recipient_phone), ''),
    COALESCE(p_delivery_fee, 0),
    v_service_type,
    COALESCE(NULLIF(btrim(p_payment_method), ''), 'cash'),
    v_item_name,
    NULLIF(btrim(p_item_category), ''),
    NULLIF(btrim(p_item_description), ''),
    NULLIF(btrim(p_item_image_url), '')
  )
  RETURNING * INTO v_order;

  IF v_item_name IS NOT NULL THEN
    INSERT INTO public.order_items (
      order_id,
      name,
      quantity,
      price
    )
    VALUES (
      v_order.id,
      v_item_name,
      p_item_quantity,
      COALESCE(p_item_price, p_delivery_fee, 0)
    );
  END IF;

  INSERT INTO public.order_status_logs (
    order_id,
    status,
    title,
    description,
    logged_by
  )
  VALUES (
    v_order.id,
    'pending'::public.order_status,
    'Đã tạo đơn',
    'Đơn hàng đã được ghi nhận và đang chờ tài xế nhận.',
    v_customer_user_id
  );

  RETURN QUERY
  SELECT v_order.id, v_order.tracking_code;
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_customer_order(
  p_order_id uuid,
  p_customer_id uuid,
  p_status_note text DEFAULT NULL
)
RETURNS TABLE(
  order_id uuid,
  driver_id uuid,
  tracking_code text,
  new_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_customer_user_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_normalized_note text := NULLIF(btrim(p_status_note), '');
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

  IF p_customer_id IS DISTINCT FROM v_customer_user_id THEN
    RAISE EXCEPTION 'CUSTOMER_ID_MISMATCH';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ORDER_NOT_FOUND';
  END IF;

  IF v_order.customer_id IS DISTINCT FROM v_customer_user_id THEN
    RAISE EXCEPTION 'ORDER_NOT_OWNED';
  END IF;

  IF v_order.status NOT IN (
    'pending'::public.order_status,
    'confirmed'::public.order_status,
    'assigned'::public.order_status,
    'picking_up'::public.order_status
  ) THEN
    RAISE EXCEPTION 'ORDER_NOT_CANCELLABLE';
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
    order_id,
    status,
    title,
    description,
    logged_by
  )
  VALUES (
    v_order.id,
    'cancelled'::public.order_status,
    'Đơn hàng đã hủy',
    CASE
      WHEN v_normalized_note IS NULL
        THEN 'Khách hàng đã hủy đơn.'
      ELSE 'Khách hàng đã hủy đơn. Lý do: ' || v_normalized_note
    END,
    v_customer_user_id
  );

  RETURN QUERY
  SELECT
    v_order.id,
    v_order.driver_id,
    v_order.tracking_code,
    v_order.status::text;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_customer_order(
  text,
  double precision,
  double precision,
  text,
  double precision,
  double precision,
  numeric,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  numeric,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  numeric
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_customer_order(
  text,
  double precision,
  double precision,
  text,
  double precision,
  double precision,
  numeric,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  numeric,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  numeric
) TO authenticated;

REVOKE ALL ON FUNCTION public.cancel_customer_order(uuid, uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_customer_order(uuid, uuid, text)
  TO authenticated;
