-- Wizard KYC params on create_driver_profile + admin detail fields + storage bucket

-- ── create_driver_profile with full KYC ─────────────────────────────────────
DROP FUNCTION IF EXISTS public.create_driver_profile(text, text, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION public.create_driver_profile(
  p_email text,
  p_full_name text,
  p_phone text,
  p_vehicle_type text,
  p_license_plate text,
  p_vehicle_brand_model text DEFAULT NULL,
  p_vehicle_color text DEFAULT NULL,
  p_avatar_url text DEFAULT NULL,
  p_id_card_number text DEFAULT NULL,
  p_id_card_front_url text DEFAULT NULL,
  p_id_card_back_url text DEFAULT NULL,
  p_driver_license_number text DEFAULT NULL,
  p_driver_license_url text DEFAULT NULL,
  p_vehicle_photo_url text DEFAULT NULL
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
    id_card_number,
    id_card_front_url,
    id_card_back_url,
    driver_license_number,
    driver_license_url,
    vehicle_photo_url,
    is_available,
    approval_status,
    submitted_at,
    rejection_reason,
    updated_at
  )
  VALUES (
    v_user_id,
    p_vehicle_type,
    p_license_plate,
    NULLIF(trim(p_vehicle_brand_model), ''),
    NULLIF(trim(p_vehicle_color), ''),
    NULLIF(trim(p_id_card_number), ''),
    NULLIF(trim(p_id_card_front_url), ''),
    NULLIF(trim(p_id_card_back_url), ''),
    NULLIF(trim(p_driver_license_number), ''),
    NULLIF(trim(p_driver_license_url), ''),
    NULLIF(trim(p_vehicle_photo_url), ''),
    false,
    'pending'::public.approval_status,
    now(),
    NULL,
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    vehicle_type = EXCLUDED.vehicle_type,
    license_plate = EXCLUDED.license_plate,
    vehicle_brand_model = COALESCE(EXCLUDED.vehicle_brand_model, public.drivers.vehicle_brand_model),
    vehicle_color = COALESCE(EXCLUDED.vehicle_color, public.drivers.vehicle_color),
    id_card_number = COALESCE(EXCLUDED.id_card_number, public.drivers.id_card_number),
    id_card_front_url = COALESCE(EXCLUDED.id_card_front_url, public.drivers.id_card_front_url),
    id_card_back_url = COALESCE(EXCLUDED.id_card_back_url, public.drivers.id_card_back_url),
    driver_license_number = COALESCE(EXCLUDED.driver_license_number, public.drivers.driver_license_number),
    driver_license_url = COALESCE(EXCLUDED.driver_license_url, public.drivers.driver_license_url),
    vehicle_photo_url = COALESCE(EXCLUDED.vehicle_photo_url, public.drivers.vehicle_photo_url),
    approval_status = 'pending'::public.approval_status,
    rejection_reason = NULL,
    submitted_at = now(),
    updated_at = now();
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_driver_profile(
  text, text, text, text, text, text, text, text, text, text, text, text, text, text
) TO authenticated;

-- ── admin_list_drivers: include KYC media + ids ─────────────────────────────
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
  rejection_reason text,
  submitted_at timestamptz,
  id_card_number text,
  id_card_front_url text,
  id_card_back_url text,
  driver_license_number text,
  driver_license_url text,
  vehicle_photo_url text
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
    d.rejection_reason,
    d.submitted_at,
    d.id_card_number,
    d.id_card_front_url,
    d.id_card_back_url,
    d.driver_license_number,
    d.driver_license_url,
    d.vehicle_photo_url
  FROM public.drivers d
  JOIN public.users u ON u.id = d.user_id
  WHERE d.approval_status::text = p_status
  ORDER BY d.updated_at DESC;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_list_drivers(text) TO authenticated;

-- ensure reject_driver has reason param
DROP FUNCTION IF EXISTS public.reject_driver(uuid);
DROP FUNCTION IF EXISTS public.reject_driver(uuid, text);

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

GRANT EXECUTE ON FUNCTION public.reject_driver(uuid, text) TO authenticated;

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

GRANT EXECUTE ON FUNCTION public.approve_driver(uuid) TO authenticated;

-- ── Storage: driver-kyc (public URLs for DATN simplicity) ───────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'driver-kyc',
  'driver-kyc',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "driver_kyc_select_public" ON storage.objects;
CREATE POLICY "driver_kyc_select_public"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'driver-kyc');

DROP POLICY IF EXISTS "driver_kyc_insert_own" ON storage.objects;
CREATE POLICY "driver_kyc_insert_own"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'driver-kyc'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "driver_kyc_update_own" ON storage.objects;
CREATE POLICY "driver_kyc_update_own"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'driver-kyc'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'driver-kyc'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
