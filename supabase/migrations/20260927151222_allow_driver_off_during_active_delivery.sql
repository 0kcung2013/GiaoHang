-- Availability controls new orders independently from the active delivery.
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
  IF p_is_available THEN
    RAISE EXCEPTION 'DRIVER_ONLINE_REQUIRES_PIN_AND_LOCATION';
  END IF;

  UPDATE public.drivers AS driver
  SET
    is_available = false,
    updated_at = clock_timestamp()
  WHERE driver.user_id = v_driver_user_id
  RETURNING driver.is_available INTO v_updated;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPROVED_DRIVER_REQUIRED';
  END IF;
  RETURN v_updated;
END;
$$;

REVOKE ALL ON FUNCTION public.set_driver_availability(boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_driver_availability(boolean)
  TO authenticated;

COMMENT ON FUNCTION public.set_driver_availability(boolean) IS
  'Stops new order intake for the signed-in driver, including during an active delivery. Going Online requires the PIN-protected location command.';
