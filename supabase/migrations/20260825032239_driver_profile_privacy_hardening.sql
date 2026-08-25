-- Restrict driver profile reads to operational fields and move privileged
-- account/KYC reads behind role-checked RPCs.

REVOKE SELECT ON TABLE public.drivers FROM anon, authenticated;
REVOKE INSERT, DELETE ON TABLE public.drivers FROM anon, authenticated;
REVOKE UPDATE ON TABLE public.drivers FROM anon;
REVOKE UPDATE ON TABLE public.drivers FROM authenticated;

GRANT SELECT (
  id,
  user_id,
  vehicle_type,
  license_plate,
  is_available,
  current_lat,
  current_lng,
  updated_at,
  total_deliveries,
  approval_status,
  vehicle_brand_model,
  vehicle_color,
  verified_at,
  submitted_at,
  location_updated_at
) ON TABLE public.drivers TO authenticated;

GRANT UPDATE (
  current_lat,
  current_lng,
  location_updated_at,
  updated_at
) ON TABLE public.drivers TO authenticated;

DROP POLICY IF EXISTS drivers_select_all ON public.drivers;
DROP POLICY IF EXISTS drivers_select_own_operational ON public.drivers;
CREATE POLICY drivers_select_own_operational
ON public.drivers
FOR SELECT
TO authenticated
USING (
  user_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.users AS actor
    WHERE actor.id = (SELECT auth.uid())
      AND actor.role = 'driver'::public.user_role
  )
);

CREATE OR REPLACE FUNCTION public.get_my_driver_account_profile()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_role public.user_role;
  v_result jsonb;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;

  SELECT actor.role
  INTO v_role
  FROM public.users AS actor
  WHERE actor.id = v_actor_id;

  IF v_role IS DISTINCT FROM 'driver'::public.user_role THEN
    RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED';
  END IF;

  SELECT jsonb_build_object(
    'id', driver.id,
    'driver_id', driver.id,
    'user_id', driver.user_id,
    'full_name', app_user.full_name,
    'email', app_user.email,
    'phone', app_user.phone,
    'avatar_url', app_user.avatar_url,
    'created_at', app_user.created_at,
    'member_since', app_user.created_at,
    'vehicle_type', driver.vehicle_type,
    'license_plate', driver.license_plate,
    'vehicle_brand_model', driver.vehicle_brand_model,
    'vehicle_color', driver.vehicle_color,
    'is_available', driver.is_available,
    'current_lat', driver.current_lat,
    'current_lng', driver.current_lng,
    'updated_at', driver.updated_at,
    'location_updated_at', driver.location_updated_at,
    'total_deliveries', driver.total_deliveries,
    'approval_status', driver.approval_status::text,
    'verified_at', driver.verified_at,
    'submitted_at', driver.submitted_at,
    'rejection_reason', driver.rejection_reason,
    'id_card_number', driver.id_card_number,
    'id_card_front_url', driver.id_card_front_url,
    'id_card_back_url', driver.id_card_back_url,
    'driver_license_number', driver.driver_license_number,
    'driver_license_url', driver.driver_license_url,
    'vehicle_photo_url', driver.vehicle_photo_url
  )
  INTO v_result
  FROM public.drivers AS driver
  JOIN public.users AS app_user ON app_user.id = driver.user_id
  WHERE driver.user_id = v_actor_id;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_driver_account_profile()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_driver_account_profile()
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_support_return_driver_origin(
  p_risk_report_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_role text;
  v_result jsonb;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;

  SELECT actor.role::text
  INTO v_role
  FROM public.users AS actor
  WHERE actor.id = v_actor_id;

  IF v_role IS NULL OR NOT (v_role IN ('support', 'admin')) THEN
    RAISE EXCEPTION 'SUPPORT_OR_ADMIN_ROLE_REQUIRED';
  END IF;

  SELECT jsonb_build_object(
    'current_lat', driver.current_lat,
    'current_lng', driver.current_lng
  )
  INTO v_result
  FROM public.risk_reports AS report
  JOIN public.orders AS delivery_order ON delivery_order.id = report.order_id
  JOIN public.drivers AS driver ON driver.user_id = delivery_order.driver_id
  WHERE report.id = p_risk_report_id;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_support_return_driver_origin(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_support_return_driver_origin(uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_public_driver_for_order(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_role text;
  v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;

  SELECT actor.role::text
  INTO v_role
  FROM public.users AS actor
  WHERE actor.id = v_uid;

  SELECT jsonb_build_object(
    'driver_id', driver.id,
    'user_id', driver.user_id,
    'full_name', driver_user.full_name,
    'avatar_url', driver_user.avatar_url,
    'phone', driver_user.phone,
    'vehicle_type', driver.vehicle_type,
    'vehicle_brand_model', driver.vehicle_brand_model,
    'vehicle_color', driver.vehicle_color,
    'license_plate', driver.license_plate,
    'rating', CASE WHEN v_role = 'driver' THEN NULL ELSE driver.rating END,
    'total_deliveries', driver.total_deliveries,
    'is_verified', (
      driver.approval_status = 'approved'::public.approval_status
    ),
    'approval_status', driver.approval_status::text,
    'member_since', driver_user.created_at,
    'is_available', driver.is_available,
    'current_lat', driver.current_lat,
    'current_lng', driver.current_lng
  )
  INTO v_result
  FROM public.orders AS delivery_order
  JOIN public.drivers AS driver ON driver.user_id = delivery_order.driver_id
  JOIN public.users AS driver_user ON driver_user.id = driver.user_id
  WHERE delivery_order.id = p_order_id
    AND delivery_order.driver_id IS NOT NULL
    AND (
      delivery_order.customer_id = v_uid
      OR delivery_order.driver_id = v_uid
      OR v_role = 'admin'
    );

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_public_driver_for_order(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_public_driver_for_order(uuid)
  TO authenticated;

REVOKE ALL ON FUNCTION public.admin_list_drivers(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_drivers(text)
  TO authenticated;

-- A driver can only read reviews they authored about a customer. Customer
-- reviews of that driver remain visible to the customer author and Admin.
DROP POLICY IF EXISTS reviews_select_driver_own ON public.reviews;
DROP POLICY IF EXISTS reviews_driver_authored_select ON public.reviews;
DROP POLICY IF EXISTS reviews_customer_authored_select ON public.reviews;
DROP POLICY IF EXISTS reviews_admin_select ON public.reviews;

CREATE POLICY reviews_driver_authored_select
ON public.reviews
FOR SELECT
TO authenticated
USING (
  reviews.reviewer_id = (SELECT auth.uid())
  AND reviews.direction = 'driver_to_customer'
  AND EXISTS (
    SELECT 1
    FROM public.users AS actor
    WHERE actor.id = (SELECT auth.uid())
      AND actor.role = 'driver'::public.user_role
  )
);

CREATE POLICY reviews_customer_authored_select
ON public.reviews
FOR SELECT
TO authenticated
USING (
  reviews.reviewer_id = (SELECT auth.uid())
  AND reviews.direction = 'customer_to_driver'
  AND EXISTS (
    SELECT 1
    FROM public.users AS actor
    WHERE actor.id = (SELECT auth.uid())
      AND actor.role = 'customer'::public.user_role
  )
);

CREATE POLICY reviews_admin_select
ON public.reviews
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.users AS actor
    WHERE actor.id = (SELECT auth.uid())
      AND actor.role = 'admin'::public.user_role
  )
);

-- Existing broad grants could otherwise let a driver update their users row.
-- Customers retain self-service fields; the trigger blocks driver callers and
-- never exposes role/created_at as updatable columns.
REVOKE UPDATE ON TABLE public.users FROM anon;
REVOKE UPDATE ON TABLE public.users FROM authenticated;
GRANT UPDATE (full_name, email, phone, avatar_url)
  ON TABLE public.users TO authenticated;

CREATE OR REPLACE FUNCTION public.reject_driver_direct_profile_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_actor_role public.user_role;
BEGIN
  IF v_actor_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT actor.role
  INTO v_actor_role
  FROM public.users AS actor
  WHERE actor.id = v_actor_id;

  IF OLD.role = 'driver'::public.user_role
    AND v_actor_id = OLD.id
    AND v_actor_role = 'driver'::public.user_role THEN
    RAISE EXCEPTION 'DRIVER_PROFILE_CHANGES_REQUIRE_ADMIN_APPROVAL';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.reject_driver_direct_profile_update()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS driver_profile_changes_require_admin_approval
  ON public.users;
CREATE TRIGGER driver_profile_changes_require_admin_approval
BEFORE UPDATE OF full_name, email, phone, avatar_url
ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.reject_driver_direct_profile_update();
