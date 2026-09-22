-- Cho phép hồ sơ tài xế tham chiếu object R2 mới, đồng thời giữ đường dẫn
-- Supabase Storage cũ trong giai đoạn chuyển tiếp.
CREATE OR REPLACE FUNCTION public.submit_driver_profile_change_request(
  p_request_id uuid,
  p_requested_changes jsonb,
  p_reason text
)
RETURNS public.driver_profile_change_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_request public.driver_profile_change_requests%ROWTYPE;
  v_driver public.drivers%ROWTYPE;
  v_user public.users%ROWTYPE;
  v_allowed_keys constant text[] := ARRAY[
    'full_name', 'email', 'phone', 'avatar_path', 'vehicle_type',
    'vehicle_brand_model', 'vehicle_color', 'license_plate',
    'id_card_number', 'id_card_front_path', 'id_card_back_path',
    'driver_license_number', 'driver_license_path', 'vehicle_photo_path'
  ];
  v_file_keys constant text[] := ARRAY[
    'avatar_path', 'id_card_front_path', 'id_card_back_path',
    'driver_license_path', 'vehicle_photo_path'
  ];
  v_changes jsonb := '{}'::jsonb;
  v_snapshot jsonb := '{}'::jsonb;
  v_key text;
  v_text text;
  v_current_text text;
  v_snapshot_key text;
  v_changed_count integer := 0;
  v_reason text := NULLIF(btrim(p_reason), '');
  v_required_prefix text;
  v_r2_required_prefix text;
BEGIN
  IF v_actor_id IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED'; END IF;
  IF p_requested_changes IS NULL
    OR jsonb_typeof(p_requested_changes) <> 'object'
    OR p_requested_changes = '{}'::jsonb THEN
    RAISE EXCEPTION 'REQUESTED_CHANGES_REQUIRED';
  END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_object_keys(p_requested_changes) AS requested_key(key)
    WHERE requested_key.key <> ALL(v_allowed_keys)
  ) THEN
    RAISE EXCEPTION 'UNSUPPORTED_PROFILE_FIELD';
  END IF;
  IF v_reason IS NULL OR char_length(v_reason) < 3 OR char_length(v_reason) > 1000 THEN
    RAISE EXCEPTION 'INVALID_CHANGE_REASON';
  END IF;

  SELECT request.* INTO v_request
  FROM public.driver_profile_change_requests AS request
  WHERE request.id = p_request_id
  FOR UPDATE;
  IF NOT FOUND OR v_request.requested_by <> v_actor_id THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_FOUND';
  END IF;
  IF v_request.status <> 'draft' THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_DRAFT';
  END IF;

  SELECT driver.* INTO v_driver
  FROM public.drivers AS driver
  WHERE driver.id = v_request.driver_id AND driver.user_id = v_actor_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND'; END IF;

  SELECT app_user.* INTO v_user
  FROM public.users AS app_user
  WHERE app_user.id = v_actor_id
    AND app_user.role = 'driver'::public.user_role
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED'; END IF;

  v_required_prefix := v_actor_id::text || '/' || p_request_id::text || '/';
  v_r2_required_prefix := 'r2://media/users/' || v_actor_id::text
    || '/driver-profile-changes/' || p_request_id::text || '/';

  FOREACH v_key IN ARRAY v_allowed_keys LOOP
    CONTINUE WHEN NOT (p_requested_changes ? v_key);
    IF jsonb_typeof(p_requested_changes -> v_key) <> 'string' THEN
      RAISE EXCEPTION 'PROFILE_FIELD_MUST_BE_TEXT: %', v_key;
    END IF;
    v_text := btrim(p_requested_changes ->> v_key);
    IF v_text = '' THEN RAISE EXCEPTION 'PROFILE_FIELD_REQUIRED: %', v_key; END IF;

    CASE v_key
      WHEN 'full_name' THEN
        IF char_length(v_text) < 2 OR char_length(v_text) > 120 THEN RAISE EXCEPTION 'INVALID_FULL_NAME'; END IF;
        v_current_text := v_user.full_name;
      WHEN 'email' THEN
        v_text := lower(v_text);
        IF char_length(v_text) > 254 OR v_text !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' THEN RAISE EXCEPTION 'INVALID_EMAIL'; END IF;
        v_current_text := lower(v_user.email);
      WHEN 'phone' THEN
        IF v_text !~ '^\+?[0-9]{9,15}$' THEN RAISE EXCEPTION 'INVALID_PHONE'; END IF;
        v_current_text := v_user.phone;
      WHEN 'avatar_path' THEN v_current_text := v_user.avatar_url;
      WHEN 'vehicle_type' THEN
        IF char_length(v_text) > 50 THEN RAISE EXCEPTION 'INVALID_VEHICLE_TYPE'; END IF;
        v_current_text := v_driver.vehicle_type;
      WHEN 'vehicle_brand_model' THEN
        IF char_length(v_text) > 120 THEN RAISE EXCEPTION 'INVALID_VEHICLE_MODEL'; END IF;
        v_current_text := v_driver.vehicle_brand_model;
      WHEN 'vehicle_color' THEN
        IF char_length(v_text) > 80 THEN RAISE EXCEPTION 'INVALID_VEHICLE_COLOR'; END IF;
        v_current_text := v_driver.vehicle_color;
      WHEN 'license_plate' THEN
        v_text := upper(v_text);
        IF char_length(v_text) > 30 THEN RAISE EXCEPTION 'INVALID_LICENSE_PLATE'; END IF;
        v_current_text := upper(v_driver.license_plate);
      WHEN 'id_card_number' THEN
        v_text := upper(v_text);
        IF char_length(v_text) > 30 THEN RAISE EXCEPTION 'INVALID_ID_CARD_NUMBER'; END IF;
        v_current_text := upper(v_driver.id_card_number);
      WHEN 'id_card_front_path' THEN v_current_text := v_driver.id_card_front_url;
      WHEN 'id_card_back_path' THEN v_current_text := v_driver.id_card_back_url;
      WHEN 'driver_license_number' THEN
        v_text := upper(v_text);
        IF char_length(v_text) > 50 THEN RAISE EXCEPTION 'INVALID_DRIVER_LICENSE_NUMBER'; END IF;
        v_current_text := upper(v_driver.driver_license_number);
      WHEN 'driver_license_path' THEN v_current_text := v_driver.driver_license_url;
      WHEN 'vehicle_photo_path' THEN v_current_text := v_driver.vehicle_photo_url;
      ELSE RAISE EXCEPTION 'UNSUPPORTED_PROFILE_FIELD';
    END CASE;

    IF v_key = ANY(v_file_keys) THEN
      IF (
          left(v_text, char_length(v_required_prefix)) <> v_required_prefix
          AND left(v_text, char_length(v_r2_required_prefix)) <> v_r2_required_prefix
        ) OR v_text LIKE '%..%' OR v_text LIKE '%\%' THEN
        RAISE EXCEPTION 'INVALID_PRIVATE_UPLOAD_PATH: %', v_key;
      END IF;
    END IF;

    v_changes := v_changes || jsonb_build_object(v_key, v_text);
    v_snapshot_key := CASE v_key
      WHEN 'avatar_path' THEN 'avatar_url'
      WHEN 'id_card_front_path' THEN 'id_card_front_url'
      WHEN 'id_card_back_path' THEN 'id_card_back_url'
      WHEN 'driver_license_path' THEN 'driver_license_url'
      WHEN 'vehicle_photo_path' THEN 'vehicle_photo_url'
      ELSE v_key
    END;
    v_snapshot := v_snapshot || jsonb_build_object(v_snapshot_key, v_current_text);
    IF v_text IS DISTINCT FROM v_current_text THEN v_changed_count := v_changed_count + 1; END IF;
  END LOOP;

  IF v_changed_count = 0 THEN RAISE EXCEPTION 'NO_PROFILE_CHANGES'; END IF;
  UPDATE public.driver_profile_change_requests
  SET current_snapshot = v_snapshot,
      requested_changes = v_changes,
      reason = v_reason,
      status = 'pending',
      decided_by = NULL,
      decided_at = NULL,
      decision_reason = NULL,
      updated_at = now()
  WHERE id = p_request_id
  RETURNING * INTO v_request;
  RETURN v_request;
END;
$$;
