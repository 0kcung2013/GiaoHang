-- Close the race where the same driver claims two different orders at once.

CREATE UNIQUE INDEX IF NOT EXISTS orders_one_active_per_driver_idx
  ON public.orders (driver_id)
  WHERE driver_id IS NOT NULL
    AND status IN (
      'assigned'::public.order_status,
      'picking_up'::public.order_status,
      'delivering'::public.order_status
    );

CREATE OR REPLACE FUNCTION public.accept_order(
  p_order_id uuid
)
RETURNS TABLE(
  order_id uuid,
  customer_id uuid,
  tracking_code text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_driver_user_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_is_available boolean;
  v_approval_status public.approval_status;
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT d.is_available, d.approval_status
  INTO v_is_available, v_approval_status
  FROM public.drivers d
  WHERE d.user_id = v_driver_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND';
  END IF;

  IF v_approval_status IS DISTINCT FROM 'approved'::public.approval_status THEN
    RAISE EXCEPTION 'DRIVER_NOT_APPROVED';
  END IF;

  IF v_is_available IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'DRIVER_OFFLINE';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.orders active_order
    WHERE active_order.driver_id = v_driver_user_id
      AND active_order.status IN (
        'assigned'::public.order_status,
        'picking_up'::public.order_status,
        'delivering'::public.order_status
      )
  ) THEN
    RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ORDER_NOT_FOUND';
  END IF;

  IF v_order.driver_id IS NOT NULL
     OR v_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     ) THEN
    RAISE EXCEPTION 'ORDER_NOT_AVAILABLE';
  END IF;

  IF v_order.assignment_timed_out_at IS NOT NULL
     OR v_order.assignment_expires_at <= clock_timestamp() THEN
    RAISE EXCEPTION 'ASSIGNMENT_EXPIRED';
  END IF;

  BEGIN
    UPDATE public.orders
    SET
      driver_id = v_driver_user_id,
      status = 'assigned'::public.order_status,
      updated_at = now()
    WHERE id = p_order_id
    RETURNING * INTO v_order;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER';
  END;

  INSERT INTO public.order_status_logs (
    order_id,
    status,
    title,
    description,
    logged_by
  )
  VALUES (
    p_order_id,
    'assigned'::public.order_status,
    'Đã có tài xế nhận đơn',
    'Tài xế đã nhận đơn trong thời gian chờ.',
    v_driver_user_id
  );

  RETURN QUERY
  SELECT v_order.id, v_order.customer_id, v_order.tracking_code;
END;
$function$;

REVOKE ALL ON FUNCTION public.accept_order(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_order(uuid) TO authenticated;
