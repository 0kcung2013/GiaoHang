-- Require a driver-owned six digit PIN before the driver can go Online.
-- The verifier stays on the existing drivers row and is never granted to a
-- Data API role or returned by a profile RPC.

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS online_pin_hash text,
  ADD COLUMN IF NOT EXISTS online_pin_failed_attempts smallint NOT NULL
    DEFAULT 0,
  ADD COLUMN IF NOT EXISTS online_pin_locked_until timestamptz,
  ADD COLUMN IF NOT EXISTS online_pin_updated_at timestamptz;

ALTER TABLE public.drivers
  DROP CONSTRAINT IF EXISTS drivers_online_pin_failed_attempts_check;

ALTER TABLE public.drivers
  ADD CONSTRAINT drivers_online_pin_failed_attempts_check
  CHECK (
    online_pin_failed_attempts >= 0
    AND online_pin_failed_attempts <= 5
  );

COMMENT ON COLUMN public.drivers.online_pin_hash IS
  'Bcrypt verifier for the six digit PIN required to go Online. Never expose through profile APIs.';
COMMENT ON COLUMN public.drivers.online_pin_failed_attempts IS
  'Consecutive invalid Online PIN attempts since the last success or lockout.';
COMMENT ON COLUMN public.drivers.online_pin_locked_until IS
  'Online PIN verification is blocked until this timestamp.';

CREATE OR REPLACE FUNCTION public.get_driver_online_pin_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
  v_pin_hash text;
  v_locked_until timestamptz;
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT
    driver.online_pin_hash,
    driver.online_pin_locked_until
  INTO
    v_pin_hash,
    v_locked_until
  FROM public.drivers AS driver
  WHERE driver.user_id = v_driver_user_id
    AND driver.approval_status = 'approved'::public.approval_status;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPROVED_DRIVER_REQUIRED';
  END IF;

  RETURN jsonb_build_object(
    'is_configured', v_pin_hash IS NOT NULL,
    'locked_until', CASE
      WHEN v_locked_until > clock_timestamp() THEN v_locked_until
      ELSE NULL
    END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_driver_online_pin_status()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_driver_online_pin_status()
  TO authenticated;

CREATE OR REPLACE FUNCTION public.configure_driver_online_pin(p_pin text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF p_pin IS NULL OR p_pin !~ '^[0-9]{6}$' THEN
    RAISE EXCEPTION 'ONLINE_PIN_MUST_BE_SIX_DIGITS';
  END IF;

  UPDATE public.drivers AS driver
  SET
    online_pin_hash = extensions.crypt(
      p_pin,
      extensions.gen_salt('bf', 12)
    ),
    online_pin_failed_attempts = 0,
    online_pin_locked_until = NULL,
    online_pin_updated_at = clock_timestamp(),
    updated_at = clock_timestamp()
  WHERE driver.user_id = v_driver_user_id
    AND driver.approval_status = 'approved'::public.approval_status
    AND driver.online_pin_hash IS NULL;

  IF NOT FOUND THEN
    IF EXISTS (
      SELECT 1
      FROM public.drivers AS driver
      WHERE driver.user_id = v_driver_user_id
        AND driver.online_pin_hash IS NOT NULL
    ) THEN
      RAISE EXCEPTION 'ONLINE_PIN_ALREADY_CONFIGURED';
    END IF;
    RAISE EXCEPTION 'APPROVED_DRIVER_REQUIRED';
  END IF;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.configure_driver_online_pin(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.configure_driver_online_pin(text)
  TO authenticated;

-- Remove the legacy two-argument command so an older or modified client
-- cannot bypass PIN verification.
REVOKE ALL ON FUNCTION public.set_driver_online_with_location(
  double precision,
  double precision
) FROM PUBLIC, anon, authenticated;
DROP FUNCTION public.set_driver_online_with_location(
  double precision,
  double precision
);

CREATE FUNCTION public.set_driver_online_with_location(
  p_lat double precision,
  p_lng double precision,
  p_pin text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
  v_now timestamptz := clock_timestamp();
  v_pin_hash text;
  v_failed_attempts smallint;
  v_locked_until timestamptz;
  v_pin_matches boolean := false;
  v_offered_order_id uuid;
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF p_lat IS NULL OR p_lat < -90 OR p_lat > 90 THEN
    RAISE EXCEPTION 'INVALID_DRIVER_LATITUDE';
  END IF;
  IF p_lng IS NULL OR p_lng < -180 OR p_lng > 180 THEN
    RAISE EXCEPTION 'INVALID_DRIVER_LONGITUDE';
  END IF;

  SELECT
    driver.online_pin_hash,
    driver.online_pin_failed_attempts,
    driver.online_pin_locked_until
  INTO
    v_pin_hash,
    v_failed_attempts,
    v_locked_until
  FROM public.drivers AS driver
  WHERE driver.user_id = v_driver_user_id
    AND driver.approval_status = 'approved'::public.approval_status
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'APPROVED_DRIVER_REQUIRED';
  END IF;

  IF v_pin_hash IS NULL THEN
    RETURN jsonb_build_object('status', 'pin_not_configured');
  END IF;

  IF v_locked_until IS NOT NULL AND v_locked_until > v_now THEN
    RETURN jsonb_build_object(
      'status', 'locked',
      'locked_until', v_locked_until
    );
  END IF;

  IF p_pin IS NOT NULL AND p_pin ~ '^[0-9]{6}$' THEN
    v_pin_matches := extensions.crypt(p_pin, v_pin_hash) = v_pin_hash;
  END IF;

  IF NOT v_pin_matches THEN
    v_failed_attempts := LEAST(v_failed_attempts + 1, 5);

    IF v_failed_attempts >= 5 THEN
      v_locked_until := v_now + interval '5 minutes';
      UPDATE public.drivers AS driver
      SET
        online_pin_failed_attempts = 0,
        online_pin_locked_until = v_locked_until,
        updated_at = v_now
      WHERE driver.user_id = v_driver_user_id;

      RETURN jsonb_build_object(
        'status', 'locked',
        'locked_until', v_locked_until
      );
    END IF;

    UPDATE public.drivers AS driver
    SET
      online_pin_failed_attempts = v_failed_attempts,
      online_pin_locked_until = NULL,
      updated_at = v_now
    WHERE driver.user_id = v_driver_user_id;

    RETURN jsonb_build_object(
      'status', 'invalid_pin',
      'remaining_attempts', 5 - v_failed_attempts
    );
  END IF;

  UPDATE public.drivers AS driver
  SET
    current_lat = p_lat,
    current_lng = p_lng,
    location_updated_at = v_now,
    is_available = true,
    online_pin_failed_attempts = 0,
    online_pin_locked_until = NULL,
    updated_at = v_now
  WHERE driver.user_id = v_driver_user_id;

  IF NOT EXISTS (
    SELECT 1
    FROM public.orders AS active_return
    WHERE active_return.driver_id = v_driver_user_id
      AND active_return.status IN (
        'return_approved'::public.order_status,
        'returning'::public.order_status
      )
  ) THEN
    v_offered_order_id :=
      private.dispatch_waiting_orders_for_driver(v_driver_user_id);
  END IF;

  RETURN jsonb_build_object(
    'status', 'online',
    'offered_order_id', v_offered_order_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.set_driver_online_with_location(
  double precision,
  double precision,
  text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_driver_online_with_location(
  double precision,
  double precision,
  text
) TO authenticated;

COMMENT ON FUNCTION public.set_driver_online_with_location(
  double precision,
  double precision,
  text
) IS
  'Verifies the signed-in driver Online PIN, publishes fresh coordinates, enables availability, and wakes one eligible order.';

-- Keep this command as the authoritative OFF path, but reject the legacy ON
-- path now that Online requires a PIN and fresh coordinates.
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

  IF EXISTS (
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
  'Takes the signed-in driver Offline. Going Online requires the PIN-protected location command.';
