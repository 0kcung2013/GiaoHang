-- Professional cancellation boundary:
-- A customer can cancel while the driver is travelling to pickup, but never
-- after a pickup handoff proof exists. The driver app advances to `delivering`
-- immediately after that proof, closing the race window at the database layer.
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

  -- `picking_up` is still cancellable only before the handoff is recorded.
  -- This check and the order-row lock make cancellation lose safely to a
  -- completed pickup proof, even if both requests arrive at the same time.
  IF v_order.status = 'picking_up'::public.order_status
     AND EXISTS (
       SELECT 1
       FROM public.order_delivery_proofs proof
       WHERE proof.order_id = p_order_id
         AND proof.stage = 'pickup'
     ) THEN
    RAISE EXCEPTION 'ORDER_ALREADY_PICKED_UP';
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
        THEN 'Khách hàng đã hủy đơn trước khi tài xế nhận hàng.'
      ELSE 'Khách hàng đã hủy đơn trước khi tài xế nhận hàng. Lý do: ' || v_normalized_note
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

REVOKE ALL ON FUNCTION public.cancel_customer_order(uuid, uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_customer_order(uuid, uuid, text)
  TO authenticated;
