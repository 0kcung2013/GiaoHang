-- Draft documents are private. Only approved avatars are published publicly,
-- and that promotion is performed by the service-role Edge Function.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  (
    'driver-profile-request-files',
    'driver-profile-request-files',
    false,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'driver-avatars',
    'driver-avatars',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp']
  )
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS driver_profile_request_files_driver_select
  ON storage.objects;
CREATE POLICY driver_profile_request_files_driver_select
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'driver-profile-request-files'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND array_length(storage.foldername(name), 1) = 2
  AND EXISTS (
    SELECT 1
    FROM public.driver_profile_change_requests AS request
    JOIN public.users AS actor ON actor.id = request.requested_by
    WHERE request.id::text = (storage.foldername(name))[2]
      AND request.requested_by = (SELECT auth.uid())
      AND actor.role = 'driver'::public.user_role
  )
);

DROP POLICY IF EXISTS driver_profile_request_files_driver_insert
  ON storage.objects;
CREATE POLICY driver_profile_request_files_driver_insert
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'driver-profile-request-files'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND array_length(storage.foldername(name), 1) = 2
  AND storage.filename(name) ~
    '^(avatar|id_card_front|id_card_back|driver_license|vehicle_photo)[.](jpg|jpeg|png|webp)$'
  AND EXISTS (
    SELECT 1
    FROM public.driver_profile_change_requests AS request
    JOIN public.users AS actor ON actor.id = request.requested_by
    WHERE request.id::text = (storage.foldername(name))[2]
      AND request.requested_by = (SELECT auth.uid())
      AND request.status = 'draft'
      AND actor.role = 'driver'::public.user_role
  )
);

DROP POLICY IF EXISTS driver_profile_request_files_driver_update
  ON storage.objects;
CREATE POLICY driver_profile_request_files_driver_update
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'driver-profile-request-files'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND array_length(storage.foldername(name), 1) = 2
  AND EXISTS (
    SELECT 1
    FROM public.driver_profile_change_requests AS request
    JOIN public.users AS actor ON actor.id = request.requested_by
    WHERE request.id::text = (storage.foldername(name))[2]
      AND request.requested_by = (SELECT auth.uid())
      AND request.status = 'draft'
      AND actor.role = 'driver'::public.user_role
  )
)
WITH CHECK (
  bucket_id = 'driver-profile-request-files'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND array_length(storage.foldername(name), 1) = 2
  AND storage.filename(name) ~
    '^(avatar|id_card_front|id_card_back|driver_license|vehicle_photo)[.](jpg|jpeg|png|webp)$'
  AND EXISTS (
    SELECT 1
    FROM public.driver_profile_change_requests AS request
    JOIN public.users AS actor ON actor.id = request.requested_by
    WHERE request.id::text = (storage.foldername(name))[2]
      AND request.requested_by = (SELECT auth.uid())
      AND request.status = 'draft'
      AND actor.role = 'driver'::public.user_role
  )
);

DROP POLICY IF EXISTS driver_profile_request_files_driver_delete
  ON storage.objects;
CREATE POLICY driver_profile_request_files_driver_delete
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'driver-profile-request-files'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND array_length(storage.foldername(name), 1) = 2
  AND EXISTS (
    SELECT 1
    FROM public.driver_profile_change_requests AS request
    JOIN public.users AS actor ON actor.id = request.requested_by
    WHERE request.id::text = (storage.foldername(name))[2]
      AND request.requested_by = (SELECT auth.uid())
      AND request.status IN ('draft', 'cancelled', 'rejected')
      AND actor.role = 'driver'::public.user_role
  )
);

DROP POLICY IF EXISTS driver_profile_request_files_admin_select
  ON storage.objects;
CREATE POLICY driver_profile_request_files_admin_select
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'driver-profile-request-files'
  AND array_length(storage.foldername(name), 1) = 2
  AND EXISTS (
    SELECT 1
    FROM public.driver_profile_change_requests AS request
    JOIN public.users AS actor ON actor.id = (SELECT auth.uid())
    WHERE request.id::text = (storage.foldername(name))[2]
      AND request.status <> 'draft'
      AND actor.role = 'admin'::public.user_role
  )
);

DROP POLICY IF EXISTS driver_profile_request_files_admin_delete
  ON storage.objects;
CREATE POLICY driver_profile_request_files_admin_delete
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'driver-profile-request-files'
  AND array_length(storage.foldername(name), 1) = 2
  AND EXISTS (
    SELECT 1
    FROM public.driver_profile_change_requests AS request
    JOIN public.users AS actor ON actor.id = (SELECT auth.uid())
    WHERE request.id::text = (storage.foldername(name))[2]
      AND request.status IN ('cancelled', 'rejected')
      AND actor.role = 'admin'::public.user_role
  )
);

DROP POLICY IF EXISTS driver_avatars_public_select ON storage.objects;
CREATE POLICY driver_avatars_public_select
ON storage.objects
FOR SELECT
TO PUBLIC
USING (bucket_id = 'driver-avatars');

CREATE OR REPLACE FUNCTION public.prepare_driver_profile_change_approval(
  p_request_id uuid,
  p_admin_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_request public.driver_profile_change_requests%ROWTYPE;
  v_driver public.drivers%ROWTYPE;
  v_user public.users%ROWTYPE;
  v_key text;
  v_snapshot_key text;
  v_current_text text;
  v_snapshot_text text;
  v_has_conflict boolean := false;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.users AS actor
    WHERE actor.id = p_admin_id
      AND actor.role = 'admin'::public.user_role
  ) THEN
    RAISE EXCEPTION 'ADMIN_ROLE_REQUIRED';
  END IF;

  SELECT request.*
  INTO v_request
  FROM public.driver_profile_change_requests AS request
  WHERE request.id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_FOUND';
  END IF;

  IF v_request.status = 'approved' THEN
    RETURN jsonb_build_object(
      'status', 'approved',
      'request_id', v_request.id
    );
  END IF;

  IF v_request.status = 'applying'
    AND v_request.decided_by = p_admin_id THEN
    SELECT app_user.*
    INTO v_user
    FROM public.users AS app_user
    WHERE app_user.id = v_request.requested_by;

    RETURN jsonb_build_object(
      'status', 'applying',
      'request_id', v_request.id,
      'user_id', v_request.requested_by,
      'old_email', v_user.email,
      'new_email', v_request.requested_changes ->> 'email',
      'avatar_draft_path', v_request.requested_changes ->> 'avatar_path'
    );
  END IF;

  IF v_request.status <> 'pending' THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_PENDING';
  END IF;

  SELECT driver.*
  INTO v_driver
  FROM public.drivers AS driver
  WHERE driver.id = v_request.driver_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND';
  END IF;

  SELECT app_user.*
  INTO v_user
  FROM public.users AS app_user
  WHERE app_user.id = v_request.requested_by
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'DRIVER_USER_NOT_FOUND';
  END IF;

  FOR v_key IN SELECT jsonb_object_keys(v_request.requested_changes) LOOP
    v_snapshot_key := CASE v_key
      WHEN 'avatar_path' THEN 'avatar_url'
      WHEN 'id_card_front_path' THEN 'id_card_front_url'
      WHEN 'id_card_back_path' THEN 'id_card_back_url'
      WHEN 'driver_license_path' THEN 'driver_license_url'
      WHEN 'vehicle_photo_path' THEN 'vehicle_photo_url'
      ELSE v_key
    END;

    v_current_text := CASE v_key
      WHEN 'full_name' THEN v_user.full_name
      WHEN 'email' THEN lower(v_user.email)
      WHEN 'phone' THEN v_user.phone
      WHEN 'avatar_path' THEN v_user.avatar_url
      WHEN 'vehicle_type' THEN v_driver.vehicle_type
      WHEN 'vehicle_brand_model' THEN v_driver.vehicle_brand_model
      WHEN 'vehicle_color' THEN v_driver.vehicle_color
      WHEN 'license_plate' THEN upper(v_driver.license_plate)
      WHEN 'id_card_number' THEN upper(v_driver.id_card_number)
      WHEN 'id_card_front_path' THEN v_driver.id_card_front_url
      WHEN 'id_card_back_path' THEN v_driver.id_card_back_url
      WHEN 'driver_license_number' THEN upper(v_driver.driver_license_number)
      WHEN 'driver_license_path' THEN v_driver.driver_license_url
      WHEN 'vehicle_photo_path' THEN v_driver.vehicle_photo_url
      ELSE NULL
    END;
    v_snapshot_text := v_request.current_snapshot ->> v_snapshot_key;

    IF v_current_text IS DISTINCT FROM v_snapshot_text THEN
      v_has_conflict := true;
      EXIT;
    END IF;
  END LOOP;

  IF v_has_conflict THEN
    UPDATE public.driver_profile_change_requests
    SET status = 'conflicted',
        decided_by = p_admin_id,
        decided_at = now(),
        decision_reason = 'Hồ sơ đã thay đổi sau khi yêu cầu được gửi.',
        updated_at = now()
    WHERE id = p_request_id
    RETURNING * INTO v_request;

    RETURN jsonb_build_object(
      'status', 'conflicted',
      'request_id', v_request.id
    );
  END IF;

  UPDATE public.driver_profile_change_requests
  SET status = 'applying',
      decided_by = p_admin_id,
      decided_at = NULL,
      decision_reason = NULL,
      updated_at = now()
  WHERE id = p_request_id
  RETURNING * INTO v_request;

  RETURN jsonb_build_object(
    'status', 'applying',
    'request_id', v_request.id,
    'user_id', v_request.requested_by,
    'old_email', v_user.email,
    'new_email', v_request.requested_changes ->> 'email',
    'avatar_draft_path', v_request.requested_changes ->> 'avatar_path'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.finalize_driver_profile_change_approval(
  p_request_id uuid,
  p_admin_id uuid,
  p_avatar_url text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_request public.driver_profile_change_requests%ROWTYPE;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.users AS actor
    WHERE actor.id = p_admin_id
      AND actor.role = 'admin'::public.user_role
  ) THEN
    RAISE EXCEPTION 'ADMIN_ROLE_REQUIRED';
  END IF;

  SELECT request.*
  INTO v_request
  FROM public.driver_profile_change_requests AS request
  WHERE request.id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_FOUND';
  END IF;

  IF v_request.status = 'approved' THEN
    RETURN jsonb_build_object(
      'status', 'approved',
      'request_id', v_request.id
    );
  END IF;

  IF v_request.status <> 'applying'
    OR v_request.decided_by IS DISTINCT FROM p_admin_id THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_APPLYING';
  END IF;

  IF v_request.requested_changes ? 'avatar_path'
    AND NULLIF(btrim(p_avatar_url), '') IS NULL THEN
    RAISE EXCEPTION 'PUBLISHED_AVATAR_REQUIRED';
  END IF;

  IF NOT (v_request.requested_changes ? 'avatar_path')
    AND p_avatar_url IS NOT NULL THEN
    RAISE EXCEPTION 'UNEXPECTED_PUBLISHED_AVATAR';
  END IF;

  UPDATE public.users
  SET full_name = CASE
        WHEN v_request.requested_changes ? 'full_name'
          THEN v_request.requested_changes ->> 'full_name'
        ELSE full_name
      END,
      email = CASE
        WHEN v_request.requested_changes ? 'email'
          THEN v_request.requested_changes ->> 'email'
        ELSE email
      END,
      phone = CASE
        WHEN v_request.requested_changes ? 'phone'
          THEN v_request.requested_changes ->> 'phone'
        ELSE phone
      END,
      avatar_url = CASE
        WHEN v_request.requested_changes ? 'avatar_path'
          THEN btrim(p_avatar_url)
        ELSE avatar_url
      END
  WHERE id = v_request.requested_by;

  UPDATE public.drivers
  SET vehicle_type = CASE
        WHEN v_request.requested_changes ? 'vehicle_type'
          THEN v_request.requested_changes ->> 'vehicle_type'
        ELSE vehicle_type
      END,
      vehicle_brand_model = CASE
        WHEN v_request.requested_changes ? 'vehicle_brand_model'
          THEN v_request.requested_changes ->> 'vehicle_brand_model'
        ELSE vehicle_brand_model
      END,
      vehicle_color = CASE
        WHEN v_request.requested_changes ? 'vehicle_color'
          THEN v_request.requested_changes ->> 'vehicle_color'
        ELSE vehicle_color
      END,
      license_plate = CASE
        WHEN v_request.requested_changes ? 'license_plate'
          THEN v_request.requested_changes ->> 'license_plate'
        ELSE license_plate
      END,
      id_card_number = CASE
        WHEN v_request.requested_changes ? 'id_card_number'
          THEN v_request.requested_changes ->> 'id_card_number'
        ELSE id_card_number
      END,
      id_card_front_url = CASE
        WHEN v_request.requested_changes ? 'id_card_front_path'
          THEN v_request.requested_changes ->> 'id_card_front_path'
        ELSE id_card_front_url
      END,
      id_card_back_url = CASE
        WHEN v_request.requested_changes ? 'id_card_back_path'
          THEN v_request.requested_changes ->> 'id_card_back_path'
        ELSE id_card_back_url
      END,
      driver_license_number = CASE
        WHEN v_request.requested_changes ? 'driver_license_number'
          THEN v_request.requested_changes ->> 'driver_license_number'
        ELSE driver_license_number
      END,
      driver_license_url = CASE
        WHEN v_request.requested_changes ? 'driver_license_path'
          THEN v_request.requested_changes ->> 'driver_license_path'
        ELSE driver_license_url
      END,
      vehicle_photo_url = CASE
        WHEN v_request.requested_changes ? 'vehicle_photo_path'
          THEN v_request.requested_changes ->> 'vehicle_photo_path'
        ELSE vehicle_photo_url
      END,
      updated_at = now()
  WHERE id = v_request.driver_id;

  UPDATE public.driver_profile_change_requests
  SET status = 'approved',
      decided_by = p_admin_id,
      decided_at = now(),
      decision_reason = NULL,
      updated_at = now()
  WHERE id = p_request_id
  RETURNING * INTO v_request;

  RETURN jsonb_build_object(
    'status', 'approved',
    'request_id', v_request.id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rollback_driver_profile_change_approval(
  p_request_id uuid,
  p_admin_id uuid,
  p_reason text,
  p_compensation_failed boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_request public.driver_profile_change_requests%ROWTYPE;
  v_reason text := NULLIF(btrim(p_reason), '');
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.users AS actor
    WHERE actor.id = p_admin_id
      AND actor.role = 'admin'::public.user_role
  ) THEN
    RAISE EXCEPTION 'ADMIN_ROLE_REQUIRED';
  END IF;

  IF v_reason IS NULL OR char_length(v_reason) > 1000 THEN
    RAISE EXCEPTION 'INVALID_ROLLBACK_REASON';
  END IF;

  SELECT request.*
  INTO v_request
  FROM public.driver_profile_change_requests AS request
  WHERE request.id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_FOUND';
  END IF;

  IF v_request.status IN ('pending', 'conflicted') THEN
    RETURN jsonb_build_object(
      'status', v_request.status,
      'request_id', v_request.id
    );
  END IF;

  IF v_request.status <> 'applying'
    OR v_request.decided_by IS DISTINCT FROM p_admin_id THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_APPLYING';
  END IF;

  IF p_compensation_failed THEN
    UPDATE public.driver_profile_change_requests
    SET status = 'conflicted',
        decided_by = p_admin_id,
        decided_at = now(),
        decision_reason = v_reason,
        updated_at = now()
    WHERE id = p_request_id
    RETURNING * INTO v_request;
  ELSE
    UPDATE public.driver_profile_change_requests
    SET status = 'pending',
        decided_by = NULL,
        decided_at = NULL,
        decision_reason = NULL,
        updated_at = now()
    WHERE id = p_request_id
    RETURNING * INTO v_request;
  END IF;

  RETURN jsonb_build_object(
    'status', v_request.status,
    'request_id', v_request.id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.prepare_driver_profile_change_approval(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finalize_driver_profile_change_approval(uuid, uuid, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rollback_driver_profile_change_approval(uuid, uuid, text, boolean)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.prepare_driver_profile_change_approval(uuid, uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.finalize_driver_profile_change_approval(uuid, uuid, text)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.rollback_driver_profile_change_approval(uuid, uuid, text, boolean)
  TO service_role;
