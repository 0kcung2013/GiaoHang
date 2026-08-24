-- Driver profile changes are an approval aggregate. Clients can read rows
-- allowed by RLS, but every write must go through the commands below.

CREATE TABLE public.driver_profile_change_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  requested_by uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  current_snapshot jsonb,
  requested_changes jsonb,
  reason text,
  status text NOT NULL DEFAULT 'draft',
  decided_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  decided_at timestamptz,
  decision_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT driver_profile_change_requests_status_check CHECK (
    status IN (
      'draft',
      'pending',
      'applying',
      'approved',
      'rejected',
      'cancelled',
      'conflicted'
    )
  ),
  CONSTRAINT driver_profile_change_requests_submitted_payload_check CHECK (
    status = 'draft'
    OR (
      jsonb_typeof(current_snapshot) = 'object'
      AND jsonb_typeof(requested_changes) = 'object'
      AND jsonb_object_length(requested_changes) > 0
      AND char_length(btrim(reason)) BETWEEN 3 AND 1000
    )
  ),
  CONSTRAINT driver_profile_change_requests_decision_check CHECK (
    (
      status IN ('approved', 'rejected', 'conflicted')
      AND decided_at IS NOT NULL
    )
    OR status IN ('draft', 'pending', 'applying', 'cancelled')
  )
);

CREATE UNIQUE INDEX driver_profile_change_requests_one_active_idx
  ON public.driver_profile_change_requests(driver_id)
  WHERE status IN ('draft', 'pending', 'applying');

CREATE INDEX driver_profile_change_requests_admin_queue_idx
  ON public.driver_profile_change_requests(status, created_at)
  WHERE status IN ('pending', 'applying');

CREATE INDEX driver_profile_change_requests_driver_history_idx
  ON public.driver_profile_change_requests(requested_by, created_at DESC);

ALTER TABLE public.driver_profile_change_requests ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.driver_profile_change_requests
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.driver_profile_change_requests TO authenticated;

CREATE POLICY driver_profile_changes_driver_select
ON public.driver_profile_change_requests
FOR SELECT
TO authenticated
USING (
  requested_by = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.users AS app_user
    WHERE app_user.id = (SELECT auth.uid())
      AND app_user.role = 'driver'::public.user_role
  )
);

CREATE POLICY driver_profile_changes_admin_select
ON public.driver_profile_change_requests
FOR SELECT
TO authenticated
USING (
  status <> 'draft'
  AND EXISTS (
    SELECT 1
    FROM public.users AS app_user
    WHERE app_user.id = (SELECT auth.uid())
      AND app_user.role = 'admin'::public.user_role
  )
);

CREATE OR REPLACE FUNCTION public.create_driver_profile_change_draft()
RETURNS public.driver_profile_change_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_driver public.drivers%ROWTYPE;
  v_request public.driver_profile_change_requests%ROWTYPE;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;

  SELECT driver.*
  INTO v_driver
  FROM public.drivers AS driver
  JOIN public.users AS app_user ON app_user.id = driver.user_id
  WHERE driver.user_id = v_actor_id
    AND app_user.role = 'driver'::public.user_role
  FOR UPDATE OF driver;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND';
  END IF;

  SELECT request.*
  INTO v_request
  FROM public.driver_profile_change_requests AS request
  WHERE request.driver_id = v_driver.id
    AND request.status IN ('draft', 'pending', 'applying')
  FOR UPDATE;

  IF FOUND THEN
    IF v_request.status = 'draft' THEN
      RETURN v_request;
    END IF;
    RAISE EXCEPTION 'ACTIVE_PROFILE_CHANGE_REQUEST_EXISTS';
  END IF;

  INSERT INTO public.driver_profile_change_requests (
    driver_id,
    requested_by
  ) VALUES (
    v_driver.id,
    v_actor_id
  )
  RETURNING * INTO v_request;

  RETURN v_request;
END;
$$;

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
    'full_name',
    'email',
    'phone',
    'avatar_path',
    'vehicle_type',
    'vehicle_brand_model',
    'vehicle_color',
    'license_plate',
    'id_card_number',
    'id_card_front_path',
    'id_card_back_path',
    'driver_license_number',
    'driver_license_path',
    'vehicle_photo_path'
  ];
  v_file_keys constant text[] := ARRAY[
    'avatar_path',
    'id_card_front_path',
    'id_card_back_path',
    'driver_license_path',
    'vehicle_photo_path'
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
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;

  IF p_requested_changes IS NULL
    OR jsonb_typeof(p_requested_changes) <> 'object'
    OR p_requested_changes = '{}'::jsonb THEN
    RAISE EXCEPTION 'REQUESTED_CHANGES_REQUIRED';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_object_keys(p_requested_changes) AS requested_key(key)
    WHERE requested_key.key <> ALL(v_allowed_keys)
  ) THEN
    RAISE EXCEPTION 'UNSUPPORTED_PROFILE_FIELD';
  END IF;

  IF v_reason IS NULL OR char_length(v_reason) < 3 OR char_length(v_reason) > 1000 THEN
    RAISE EXCEPTION 'INVALID_CHANGE_REASON';
  END IF;

  SELECT request.*
  INTO v_request
  FROM public.driver_profile_change_requests AS request
  WHERE request.id = p_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_request.requested_by <> v_actor_id THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_FOUND';
  END IF;

  IF v_request.status <> 'draft' THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_DRAFT';
  END IF;

  SELECT driver.*
  INTO v_driver
  FROM public.drivers AS driver
  WHERE driver.id = v_request.driver_id
    AND driver.user_id = v_actor_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND';
  END IF;

  SELECT app_user.*
  INTO v_user
  FROM public.users AS app_user
  WHERE app_user.id = v_actor_id
    AND app_user.role = 'driver'::public.user_role
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED';
  END IF;

  v_required_prefix := (SELECT auth.uid())::text || '/' || p_request_id::text || '/';

  FOREACH v_key IN ARRAY v_allowed_keys LOOP
    CONTINUE WHEN NOT (p_requested_changes ? v_key);

    IF jsonb_typeof(p_requested_changes -> v_key) <> 'string' THEN
      RAISE EXCEPTION 'PROFILE_FIELD_MUST_BE_TEXT: %', v_key;
    END IF;

    v_text := btrim(p_requested_changes ->> v_key);
    IF v_text = '' THEN
      RAISE EXCEPTION 'PROFILE_FIELD_REQUIRED: %', v_key;
    END IF;

    CASE v_key
      WHEN 'full_name' THEN
        IF char_length(v_text) < 2 OR char_length(v_text) > 120 THEN
          RAISE EXCEPTION 'INVALID_FULL_NAME';
        END IF;
        v_current_text := v_user.full_name;
      WHEN 'email' THEN
        v_text := lower(v_text);
        IF char_length(v_text) > 254
          OR v_text !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' THEN
          RAISE EXCEPTION 'INVALID_EMAIL';
        END IF;
        v_current_text := lower(v_user.email);
      WHEN 'phone' THEN
        IF v_text !~ '^\+?[0-9]{9,15}$' THEN
          RAISE EXCEPTION 'INVALID_PHONE';
        END IF;
        v_current_text := v_user.phone;
      WHEN 'avatar_path' THEN
        v_current_text := v_user.avatar_url;
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
      WHEN 'id_card_front_path' THEN
        v_current_text := v_driver.id_card_front_url;
      WHEN 'id_card_back_path' THEN
        v_current_text := v_driver.id_card_back_url;
      WHEN 'driver_license_number' THEN
        v_text := upper(v_text);
        IF char_length(v_text) > 50 THEN RAISE EXCEPTION 'INVALID_DRIVER_LICENSE_NUMBER'; END IF;
        v_current_text := upper(v_driver.driver_license_number);
      WHEN 'driver_license_path' THEN
        v_current_text := v_driver.driver_license_url;
      WHEN 'vehicle_photo_path' THEN
        v_current_text := v_driver.vehicle_photo_url;
      ELSE
        RAISE EXCEPTION 'UNSUPPORTED_PROFILE_FIELD';
    END CASE;

    IF v_key = ANY(v_file_keys) THEN
      IF left(v_text, char_length(v_required_prefix)) <> v_required_prefix
        OR v_text LIKE '%..%'
        OR v_text LIKE '%\\%' THEN
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

    IF v_text IS DISTINCT FROM v_current_text THEN
      v_changed_count := v_changed_count + 1;
    END IF;
  END LOOP;

  IF v_changed_count = 0 THEN
    RAISE EXCEPTION 'NO_PROFILE_CHANGES';
  END IF;

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

CREATE OR REPLACE FUNCTION public.cancel_driver_profile_change_request(
  p_request_id uuid
)
RETURNS public.driver_profile_change_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_actor_role public.user_role;
  v_request public.driver_profile_change_requests%ROWTYPE;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;

  SELECT app_user.role
  INTO v_actor_role
  FROM public.users AS app_user
  WHERE app_user.id = v_actor_id;

  IF v_actor_role IS DISTINCT FROM 'driver'::public.user_role THEN
    RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED';
  END IF;

  SELECT request.*
  INTO v_request
  FROM public.driver_profile_change_requests AS request
  WHERE request.id = p_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_request.requested_by <> v_actor_id THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_FOUND';
  END IF;

  IF v_request.status = 'draft' THEN
    DELETE FROM public.driver_profile_change_requests
    WHERE id = p_request_id
    RETURNING * INTO v_request;
    RETURN v_request;
  END IF;

  IF v_request.status <> 'pending' THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_CANCELLABLE';
  END IF;

  UPDATE public.driver_profile_change_requests
  SET status = 'cancelled',
      updated_at = now()
  WHERE id = p_request_id
  RETURNING * INTO v_request;

  RETURN v_request;
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_driver_profile_change_request(
  p_request_id uuid,
  p_decision_reason text
)
RETURNS public.driver_profile_change_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_actor_role public.user_role;
  v_request public.driver_profile_change_requests%ROWTYPE;
  v_reason text := NULLIF(btrim(p_decision_reason), '');
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;

  SELECT app_user.role
  INTO v_actor_role
  FROM public.users AS app_user
  WHERE app_user.id = v_actor_id;

  IF v_actor_role IS DISTINCT FROM 'admin'::public.user_role THEN
    RAISE EXCEPTION 'ADMIN_ROLE_REQUIRED';
  END IF;

  IF v_reason IS NULL OR char_length(v_reason) < 3 OR char_length(v_reason) > 1000 THEN
    RAISE EXCEPTION 'INVALID_DECISION_REASON';
  END IF;

  SELECT request.*
  INTO v_request
  FROM public.driver_profile_change_requests AS request
  WHERE request.id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_FOUND';
  END IF;

  IF v_request.status <> 'pending' THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_PENDING';
  END IF;

  UPDATE public.driver_profile_change_requests
  SET status = 'rejected',
      decided_by = v_actor_id,
      decided_at = now(),
      decision_reason = v_reason,
      updated_at = now()
  WHERE id = p_request_id
  RETURNING * INTO v_request;

  RETURN v_request;
END;
$$;

CREATE OR REPLACE FUNCTION public.approve_driver_profile_change_request(
  p_request_id uuid
)
RETURNS public.driver_profile_change_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid := (SELECT auth.uid());
  v_actor_role public.user_role;
  v_request public.driver_profile_change_requests%ROWTYPE;
  v_driver public.drivers%ROWTYPE;
  v_user public.users%ROWTYPE;
  v_key text;
  v_snapshot_key text;
  v_current_text text;
  v_snapshot_text text;
  v_has_conflict boolean := false;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED';
  END IF;

  SELECT app_user.role
  INTO v_actor_role
  FROM public.users AS app_user
  WHERE app_user.id = v_actor_id;

  IF v_actor_role IS DISTINCT FROM 'admin'::public.user_role THEN
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

  IF v_request.status <> 'pending' THEN
    RAISE EXCEPTION 'PROFILE_CHANGE_REQUEST_NOT_PENDING';
  END IF;

  -- Auth identity and avatar changes must be applied by the service-role Edge
  -- Function so auth.users, profile data and file promotion stay coordinated.
  IF v_request.requested_changes ? 'email'
    OR v_request.requested_changes ? 'avatar_path' THEN
    RAISE EXCEPTION 'REQUIRES_EDGE_FUNCTION';
  END IF;

  UPDATE public.driver_profile_change_requests
  SET status = 'applying',
      updated_at = now()
  WHERE id = p_request_id
  RETURNING * INTO v_request;

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
        decided_by = v_actor_id,
        decided_at = now(),
        decision_reason = 'Hồ sơ đã thay đổi sau khi yêu cầu được gửi.',
        updated_at = now()
    WHERE id = p_request_id
    RETURNING * INTO v_request;

    RETURN v_request;
  END IF;

  UPDATE public.users
  SET full_name = CASE
        WHEN v_request.requested_changes ? 'full_name'
          THEN v_request.requested_changes ->> 'full_name'
        ELSE full_name
      END,
      phone = CASE
        WHEN v_request.requested_changes ? 'phone'
          THEN v_request.requested_changes ->> 'phone'
        ELSE phone
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
      decided_by = v_actor_id,
      decided_at = now(),
      decision_reason = NULL,
      updated_at = now()
  WHERE id = p_request_id
  RETURNING * INTO v_request;

  RETURN v_request;
END;
$$;

REVOKE ALL ON FUNCTION public.create_driver_profile_change_draft()
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.submit_driver_profile_change_request(uuid, jsonb, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cancel_driver_profile_change_request(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.approve_driver_profile_change_request(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reject_driver_profile_change_request(uuid, text)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_driver_profile_change_draft()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_driver_profile_change_request(uuid, jsonb, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_driver_profile_change_request(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_driver_profile_change_request(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_driver_profile_change_request(uuid, text)
  TO authenticated;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'driver_profile_change_requests'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_profile_change_requests';
  END IF;
END;
$$;
