-- =============================================================================
-- Driver account schema lock-in (Phase A + Phase B columns prepared)
-- Phase A (customer-visible soon): vehicle_brand_model, vehicle_color,
--   users.avatar_url (already exists), public profile RPC
-- Phase B (KYC later, columns only): id/license docs, rejection_reason, ...
-- =============================================================================

-- ── Phase A columns ──────────────────────────────────────────────────────────
ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS vehicle_brand_model text,
  ADD COLUMN IF NOT EXISTS vehicle_color text;

COMMENT ON COLUMN public.drivers.vehicle_brand_model IS
  'Phase A: e.g. Honda Wave, Toyota Vios — shown to customer';
COMMENT ON COLUMN public.drivers.vehicle_color IS
  'Phase A: vehicle color for roadside recognition — shown to customer';

-- ── Phase B columns (nullable, unused until KYC wizard) ──────────────────────
ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS id_card_number text,
  ADD COLUMN IF NOT EXISTS id_card_front_url text,
  ADD COLUMN IF NOT EXISTS id_card_back_url text,
  ADD COLUMN IF NOT EXISTS driver_license_number text,
  ADD COLUMN IF NOT EXISTS driver_license_url text,
  ADD COLUMN IF NOT EXISTS vehicle_photo_url text,
  ADD COLUMN IF NOT EXISTS rejection_reason text,
  ADD COLUMN IF NOT EXISTS verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS submitted_at timestamptz;

COMMENT ON COLUMN public.drivers.id_card_number IS 'Phase B KYC: CCCD number (admin only)';
COMMENT ON COLUMN public.drivers.id_card_front_url IS 'Phase B KYC: storage URL';
COMMENT ON COLUMN public.drivers.id_card_back_url IS 'Phase B KYC: storage URL';
COMMENT ON COLUMN public.drivers.driver_license_number IS 'Phase B KYC: GPLX number (admin only)';
COMMENT ON COLUMN public.drivers.driver_license_url IS 'Phase B KYC: storage URL';
COMMENT ON COLUMN public.drivers.vehicle_photo_url IS 'Phase B KYC: vehicle photo storage URL';
COMMENT ON COLUMN public.drivers.rejection_reason IS 'Phase B: admin rejection note';
COMMENT ON COLUMN public.drivers.verified_at IS 'When admin approved / KYC verified';
COMMENT ON COLUMN public.drivers.submitted_at IS 'When driver submitted profile for review';

-- Existing approved drivers count as verified for public badge
UPDATE public.drivers
SET verified_at = COALESCE(verified_at, updated_at)
WHERE approval_status = 'approved'::public.approval_status
  AND verified_at IS NULL;

-- ── create_driver_profile: accept Phase A fields (backward compatible) ───────
DROP FUNCTION IF EXISTS public.create_driver_profile(text, text, text, text, text);

CREATE OR REPLACE FUNCTION public.create_driver_profile(
  p_email text,
  p_full_name text,
  p_phone text,
  p_vehicle_type text,
  p_license_plate text,
  p_vehicle_brand_model text DEFAULT NULL,
  p_vehicle_color text DEFAULT NULL,
  p_avatar_url text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.users (id, email, full_name, phone, role, avatar_url, created_at)
  VALUES (
    v_user_id,
    p_email,
    p_full_name,
    p_phone,
    'driver'::public.user_role,
    NULLIF(trim(p_avatar_url), ''),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    role = EXCLUDED.role,
    avatar_url = COALESCE(EXCLUDED.avatar_url, public.users.avatar_url);

  INSERT INTO public.drivers (
    user_id,
    vehicle_type,
    license_plate,
    vehicle_brand_model,
    vehicle_color,
    is_available,
    approval_status,
    submitted_at,
    updated_at
  )
  VALUES (
    v_user_id,
    p_vehicle_type,
    p_license_plate,
    NULLIF(trim(p_vehicle_brand_model), ''),
    NULLIF(trim(p_vehicle_color), ''),
    false,
    'pending'::public.approval_status,
    now(),
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    vehicle_type = EXCLUDED.vehicle_type,
    license_plate = EXCLUDED.license_plate,
    vehicle_brand_model = COALESCE(EXCLUDED.vehicle_brand_model, public.drivers.vehicle_brand_model),
    vehicle_color = COALESCE(EXCLUDED.vehicle_color, public.drivers.vehicle_color),
    submitted_at = COALESCE(public.drivers.submitted_at, now()),
    updated_at = EXCLUDED.updated_at;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_driver_profile(
  text, text, text, text, text, text, text, text
) TO authenticated;

-- ── admin_list_drivers: include Phase A fields + avatar ──────────────────────
DROP FUNCTION IF EXISTS public.admin_list_drivers(text);

CREATE OR REPLACE FUNCTION public.admin_list_drivers(p_status text)
RETURNS TABLE(
  driver_id uuid,
  user_id uuid,
  vehicle_type text,
  license_plate text,
  vehicle_brand_model text,
  vehicle_color text,
  is_available boolean,
  current_lat double precision,
  current_lng double precision,
  updated_at timestamptz,
  rating numeric,
  total_deliveries integer,
  approval_status text,
  full_name text,
  email text,
  phone text,
  avatar_url text,
  verified_at timestamptz,
  rejection_reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF (SELECT role::text FROM public.users WHERE id = auth.uid()) != 'admin' THEN
    RAISE EXCEPTION 'Only admin can list drivers';
  END IF;

  RETURN QUERY
  SELECT
    d.id AS driver_id,
    d.user_id,
    d.vehicle_type,
    d.license_plate,
    d.vehicle_brand_model,
    d.vehicle_color,
    d.is_available,
    d.current_lat,
    d.current_lng,
    d.updated_at,
    d.rating,
    d.total_deliveries,
    d.approval_status::text,
    u.full_name,
    u.email,
    u.phone,
    u.avatar_url,
    d.verified_at,
    d.rejection_reason
  FROM public.drivers d
  JOIN public.users u ON u.id = d.user_id
  WHERE d.approval_status::text = p_status
  ORDER BY d.updated_at DESC;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_list_drivers(text) TO authenticated;

-- ── approve / reject: set verified_at / rejection_reason ──────────────────────
CREATE OR REPLACE FUNCTION public.approve_driver(p_driver_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_role text;
BEGIN
  SELECT role::text INTO v_role FROM public.users WHERE id = auth.uid();
  IF v_role != 'admin' THEN
    RAISE EXCEPTION 'Only admin can approve drivers';
  END IF;

  UPDATE public.drivers
  SET
    approval_status = 'approved'::public.approval_status,
    is_available = true,
    verified_at = now(),
    rejection_reason = NULL,
    updated_at = now()
  WHERE id = p_driver_id;
END;
$function$;

DROP FUNCTION IF EXISTS public.reject_driver(uuid);

CREATE OR REPLACE FUNCTION public.reject_driver(
  p_driver_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_role text;
BEGIN
  SELECT role::text INTO v_role FROM public.users WHERE id = auth.uid();
  IF v_role != 'admin' THEN
    RAISE EXCEPTION 'Only admin can reject drivers';
  END IF;

  UPDATE public.drivers
  SET
    approval_status = 'rejected'::public.approval_status,
    is_available = false,
    verified_at = NULL,
    rejection_reason = NULLIF(trim(p_reason), ''),
    updated_at = now()
  WHERE id = p_driver_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.approve_driver(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_driver(uuid, text) TO authenticated;

-- ── Public driver profile for an order (customer / assigned driver / admin) ──
CREATE OR REPLACE FUNCTION public.get_public_driver_for_order(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_role text;
  v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT role::text INTO v_role FROM public.users WHERE id = v_uid;

  SELECT jsonb_build_object(
    'driver_id', d.id,
    'user_id', d.user_id,
    'full_name', u.full_name,
    'avatar_url', u.avatar_url,
    'phone', u.phone,
    'vehicle_type', d.vehicle_type,
    'vehicle_brand_model', d.vehicle_brand_model,
    'vehicle_color', d.vehicle_color,
    'license_plate', d.license_plate,
    'rating', d.rating,
    'total_deliveries', d.total_deliveries,
    'is_verified', (d.approval_status = 'approved'::public.approval_status),
    'approval_status', d.approval_status::text,
    'member_since', u.created_at,
    'is_available', d.is_available,
    'current_lat', d.current_lat,
    'current_lng', d.current_lng
  )
  INTO v_result
  FROM public.orders o
  JOIN public.drivers d ON d.user_id = o.driver_id
  JOIN public.users u ON u.id = d.user_id
  WHERE o.id = p_order_id
    AND o.driver_id IS NOT NULL
    AND (
      o.customer_id = v_uid
      OR o.driver_id = v_uid
      OR v_role = 'admin'
    );

  RETURN v_result;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_public_driver_for_order(uuid) TO authenticated;
