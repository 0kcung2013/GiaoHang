-- Keep newly approved drivers offline until they explicitly opt in, and make
-- the active-delivery availability rule authoritative at the database layer.

CREATE OR REPLACE FUNCTION public.approve_driver(p_driver_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role text;
BEGIN
  SELECT user_account.role::text
  INTO v_role
  FROM public.users AS user_account
  WHERE user_account.id = (SELECT auth.uid());

  IF v_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED';
  END IF;

  UPDATE public.drivers AS driver
  SET
    approval_status = 'approved'::public.approval_status,
    is_available = false,
    verified_at = clock_timestamp(),
    rejection_reason = NULL,
    updated_at = clock_timestamp()
  WHERE driver.id = p_driver_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.approve_driver(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approve_driver(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_driver_availability(
  p_is_available boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
  v_updated boolean;
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF p_is_available IS NULL THEN
    RAISE EXCEPTION 'DRIVER_AVAILABILITY_REQUIRED';
  END IF;

  IF p_is_available = false AND EXISTS (
    SELECT 1
    FROM public.orders AS active_order
    WHERE active_order.driver_id = v_driver_user_id
      AND active_order.status IN (
        'assigned'::public.order_status,
        'picking_up'::public.order_status,
        'delivering'::public.order_status,
        'return_approved'::public.order_status,
        'returning'::public.order_status
      )
  ) THEN
    RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER';
  END IF;

  UPDATE public.drivers AS driver
  SET
    is_available = p_is_available,
    updated_at = clock_timestamp()
  WHERE driver.user_id = v_driver_user_id
    AND (
      p_is_available = false
      OR driver.approval_status = 'approved'::public.approval_status
    )
  RETURNING driver.is_available INTO v_updated;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPROVED_DRIVER_REQUIRED';
  END IF;
  RETURN v_updated;
END;
$$;

REVOKE ALL ON FUNCTION public.set_driver_availability(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_driver_availability(boolean) TO authenticated;

COMMENT ON FUNCTION public.approve_driver(uuid) IS
  'Approves a driver while keeping availability off until explicit opt-in.';
COMMENT ON FUNCTION public.set_driver_availability(boolean) IS
  'Sets availability for the signed-in driver and blocks offline during active delivery or return work.';
