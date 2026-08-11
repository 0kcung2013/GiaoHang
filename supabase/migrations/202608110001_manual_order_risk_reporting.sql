-- Customer/Driver initiated order incident reports with immutable evidence.
-- Participant creation is available only through one validated command.

ALTER TABLE public.risk_reports
  DROP CONSTRAINT IF EXISTS risk_reports_category_check;

ALTER TABLE public.risk_reports
  ADD CONSTRAINT risk_reports_category_check
  CHECK (category IN (
    'delivery_delay',
    'suspicious_address',
    'contact_issue',
    'cargo_issue',
    'repeated_cancellation',
    'payment',
    'safety',
    'system',
    'other'
  ));

ALTER TABLE public.risk_reports
  ADD COLUMN reporter_role_snapshot text,
  ADD COLUMN triage_due_at timestamptz,
  ADD COLUMN escalated_at timestamptz,
  ADD CONSTRAINT risk_reports_reporter_role_check
    CHECK (reporter_role_snapshot IN ('customer', 'driver', 'support', 'admin'));

UPDATE public.risk_reports AS report
SET reporter_role_snapshot = actor.role::text
FROM public.users AS actor
WHERE actor.id = report.reported_by
  AND report.reporter_role_snapshot IS NULL;

ALTER TABLE public.risk_reports
  ALTER COLUMN reporter_role_snapshot SET NOT NULL;

CREATE TABLE public.risk_report_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  risk_report_id uuid NOT NULL
    REFERENCES public.risk_reports(id) ON DELETE CASCADE,
  order_id uuid NOT NULL
    REFERENCES public.orders(id) ON DELETE RESTRICT,
  evidence_type text NOT NULL
    CHECK (evidence_type IN ('photo', 'location')),
  storage_path text,
  latitude double precision,
  longitude double precision,
  captured_at timestamptz,
  added_by uuid NOT NULL
    REFERENCES public.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT risk_report_attachment_shape_check CHECK (
    (
      evidence_type = 'photo'
      AND storage_path IS NOT NULL
      AND latitude IS NULL
      AND longitude IS NULL
    )
    OR
    (
      evidence_type = 'location'
      AND storage_path IS NULL
      AND latitude BETWEEN -90 AND 90
      AND longitude BETWEEN -180 AND 180
    )
  ),
  CONSTRAINT risk_report_attachment_photo_unique UNIQUE (storage_path)
);

CREATE INDEX risk_report_attachments_report_idx
  ON public.risk_report_attachments(risk_report_id, created_at);
CREATE INDEX risk_report_attachments_order_idx
  ON public.risk_report_attachments(order_id);

ALTER TABLE public.risk_report_attachments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.risk_report_attachments FROM anon, authenticated;
GRANT SELECT ON public.risk_report_attachments TO authenticated;

CREATE POLICY risk_reports_participant_select
ON public.risk_reports
FOR SELECT
TO authenticated
USING (reported_by = (SELECT auth.uid()));

CREATE POLICY risk_events_participant_select
ON public.risk_report_events
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.risk_reports AS report
    WHERE report.id = risk_report_events.risk_report_id
      AND report.reported_by = (SELECT auth.uid())
  )
);

CREATE POLICY risk_attachments_participant_select
ON public.risk_report_attachments
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.risk_reports AS report
    WHERE report.id = risk_report_attachments.risk_report_id
      AND report.reported_by = (SELECT auth.uid())
  )
);

CREATE POLICY risk_attachments_staff_select
ON public.risk_report_attachments
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.users AS actor
    WHERE actor.id = (SELECT auth.uid())
      AND actor.role IN (
        'support'::public.user_role,
        'admin'::public.user_role
      )
  )
);

CREATE POLICY risk_message_evidence_participant_select
ON public.risk_report_message_evidence
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.risk_reports AS report
    WHERE report.id = risk_report_message_evidence.risk_report_id
      AND report.reported_by = (SELECT auth.uid())
  )
);

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'risk-report-evidence',
  'risk-report-evidence',
  false,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE POLICY risk_evidence_upload_own_prefix
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'risk-report-evidence'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND array_length(storage.foldername(name), 1) = 2
  AND (storage.foldername(name))[2] IS NOT NULL
);

CREATE POLICY risk_evidence_delete_unregistered_own
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'risk-report-evidence'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND NOT EXISTS (
    SELECT 1
    FROM public.risk_report_attachments AS attachment
    WHERE attachment.storage_path = storage.objects.name
  )
);

CREATE POLICY risk_evidence_select_registered
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'risk-report-evidence'
  AND EXISTS (
    SELECT 1
    FROM public.risk_report_attachments AS attachment
    JOIN public.risk_reports AS report
      ON report.id = attachment.risk_report_id
    JOIN public.users AS actor
      ON actor.id = (SELECT auth.uid())
    WHERE attachment.storage_path = storage.objects.name
      AND (
        report.reported_by = actor.id
        OR actor.role IN (
          'support'::public.user_role,
          'admin'::public.user_role
        )
      )
  )
);

CREATE OR REPLACE FUNCTION private.validate_risk_report_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  assignee_role public.user_role;
  order_customer_id uuid;
  order_driver_id uuid;
BEGIN
  SELECT role INTO actor_role
  FROM public.users
  WHERE id = actor_id;

  IF actor_role IS NULL THEN
    RAISE EXCEPTION 'Authenticated user profile is required'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF actor_role IN (
      'support'::public.user_role,
      'admin'::public.user_role
    ) THEN
      NULL;
    ELSIF actor_role IN (
      'customer'::public.user_role,
      'driver'::public.user_role
    ) THEN
      SELECT customer_id, driver_id
      INTO order_customer_id, order_driver_id
      FROM public.orders
      WHERE id = NEW.order_id;

      IF NOT (
        (actor_role = 'customer'::public.user_role
          AND order_customer_id = actor_id)
        OR
        (actor_role = 'driver'::public.user_role
          AND order_driver_id = actor_id)
      ) THEN
        RAISE EXCEPTION 'Reporter is not a participant of this order'
          USING ERRCODE = '42501';
      END IF;

      IF NEW.severity <> 'medium'
        OR NEW.status <> 'open'
        OR NEW.assigned_to IS NOT NULL
        OR NEW.source <> 'manual' THEN
        RAISE EXCEPTION 'Participant report fields cannot be elevated'
          USING ERRCODE = '42501';
      END IF;
    ELSE
      RAISE EXCEPTION 'Role cannot create risk reports'
        USING ERRCODE = '42501';
    END IF;

    NEW.reported_by := actor_id;
    NEW.updated_by := actor_id;
    NEW.reporter_role_snapshot := actor_role::text;
    NEW.created_at := now();
    NEW.updated_at := now();
    RETURN NEW;
  END IF;

  IF actor_role NOT IN (
    'support'::public.user_role,
    'admin'::public.user_role
  ) THEN
    RAISE EXCEPTION 'Only Support or Admin can update risk reports'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.assigned_to IS NOT NULL THEN
    SELECT role INTO assignee_role
    FROM public.users
    WHERE id = NEW.assigned_to;

    IF assignee_role IS NULL OR assignee_role NOT IN (
      'support'::public.user_role,
      'admin'::public.user_role
    ) THEN
      RAISE EXCEPTION 'Risk report assignee must be Support or Admin'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF NEW.order_id IS DISTINCT FROM OLD.order_id
    OR NEW.reported_by IS DISTINCT FROM OLD.reported_by
    OR NEW.reporter_role_snapshot IS DISTINCT FROM OLD.reporter_role_snapshot
    OR NEW.source IS DISTINCT FROM OLD.source THEN
    RAISE EXCEPTION 'Order, reporter and source cannot be changed'
      USING ERRCODE = '23514';
  END IF;

  IF OLD.severity = 'critical'
    AND NEW.severity IS DISTINCT FROM OLD.severity
    AND actor_role <> 'admin'::public.user_role THEN
    RAISE EXCEPTION 'Only Admin can change critical severity'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT (
      (OLD.status = 'open' AND NEW.status IN ('investigating', 'dismissed'))
      OR (OLD.status = 'investigating'
        AND NEW.status IN ('action_required', 'resolved', 'dismissed'))
      OR (OLD.status = 'action_required'
        AND NEW.status IN ('investigating', 'resolved', 'dismissed'))
      OR (OLD.status IN ('resolved', 'dismissed')
        AND NEW.status = 'investigating')
    ) THEN
      RAISE EXCEPTION 'Invalid risk report status transition: % -> %',
        OLD.status, NEW.status
        USING ERRCODE = '23514';
    END IF;

    IF (OLD.severity = 'critical' OR NEW.severity = 'critical')
      AND NEW.status IN ('resolved', 'dismissed')
      AND actor_role <> 'admin'::public.user_role THEN
      RAISE EXCEPTION 'Only Admin can close a critical risk report'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF NEW.status IN ('resolved', 'dismissed') THEN
    IF NEW.resolution IS NULL OR char_length(trim(NEW.resolution)) < 3 THEN
      RAISE EXCEPTION 'Resolution is required when closing a risk report'
        USING ERRCODE = '23514';
    END IF;
    NEW.resolved_at := COALESCE(OLD.resolved_at, now());
  ELSE
    NEW.resolved_at := NULL;
  END IF;

  NEW.updated_by := actor_id;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_participant_risk_report(
  p_report_id uuid,
  p_order_id uuid,
  p_category text,
  p_description text,
  p_photo_paths text[],
  p_latitude double precision,
  p_longitude double precision,
  p_location_captured_at timestamptz,
  p_message_ids uuid[]
)
RETURNS TABLE(report_id uuid, status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  v_order public.orders%ROWTYPE;
  normalized_description text := trim(COALESCE(p_description, ''));
  normalized_photos text[] := COALESCE(p_photo_paths, ARRAY[]::text[]);
  normalized_messages uuid[] := COALESCE(p_message_ids, ARRAY[]::uuid[]);
  photo_path text;
  requested_message_count integer;
  matched_message_count integer;
  requested_photo_count integer;
  matched_photo_count integer;
  report_title text;
BEGIN
  IF actor_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  SELECT actor.role INTO actor_role
  FROM public.users AS actor
  WHERE actor.id = actor_id;

  IF actor_role NOT IN (
    'customer'::public.user_role,
    'driver'::public.user_role
  ) THEN
    RAISE EXCEPTION 'Only Customer or Driver can use this command'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    (actor_role = 'customer'::public.user_role
      AND v_order.customer_id = actor_id)
    OR
    (actor_role = 'driver'::public.user_role
      AND v_order.driver_id = actor_id)
  ) THEN
    RAISE EXCEPTION 'Reporter is not a participant of this order'
      USING ERRCODE = '42501';
  END IF;

  IF p_category NOT IN (
    'delivery_delay',
    'suspicious_address',
    'contact_issue',
    'cargo_issue',
    'payment',
    'safety',
    'other'
  ) THEN
    RAISE EXCEPTION 'Unsupported participant risk category'
      USING ERRCODE = '22023';
  END IF;

  IF char_length(normalized_description) NOT BETWEEN 10 AND 4000 THEN
    RAISE EXCEPTION 'Description must contain between 10 and 4000 characters'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(DISTINCT path), count(*)
  INTO requested_photo_count, matched_photo_count
  FROM unnest(normalized_photos) AS path;

  IF matched_photo_count > 5
    OR requested_photo_count <> matched_photo_count THEN
    RAISE EXCEPTION 'Select at most five unique photos'
      USING ERRCODE = '22023';
  END IF;

  FOREACH photo_path IN ARRAY normalized_photos LOOP
    IF (storage.foldername(photo_path))[1] <> actor_id::text
      OR (storage.foldername(photo_path))[2] <> p_report_id::text
      OR array_length(storage.foldername(photo_path), 1) <> 2 THEN
      RAISE EXCEPTION 'Photo path does not belong to this report'
        USING ERRCODE = '42501';
    END IF;
  END LOOP;

  SELECT count(*) INTO matched_photo_count
  FROM storage.objects AS object
  WHERE object.bucket_id = 'risk-report-evidence'
    AND object.name = ANY(normalized_photos);

  IF matched_photo_count <> requested_photo_count THEN
    RAISE EXCEPTION 'Every photo must be uploaded before report creation'
      USING ERRCODE = '23514';
  END IF;

  IF (p_latitude IS NULL) <> (p_longitude IS NULL) THEN
    RAISE EXCEPTION 'Latitude and longitude must be supplied together'
      USING ERRCODE = '22023';
  END IF;

  IF p_latitude IS NOT NULL
    AND (p_latitude NOT BETWEEN -90 AND 90
      OR p_longitude NOT BETWEEN -180 AND 180) THEN
    RAISE EXCEPTION 'Invalid location coordinates'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(DISTINCT message_id)
  INTO requested_message_count
  FROM unnest(normalized_messages) AS message_id;

  IF requested_message_count > 20 THEN
    RAISE EXCEPTION 'Select at most twenty messages'
      USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO matched_message_count
  FROM public.order_messages AS message
  WHERE message.order_id = p_order_id
    AND message.id = ANY(normalized_messages);

  IF matched_message_count <> requested_message_count THEN
    RAISE EXCEPTION 'Every message must belong to the report order'
      USING ERRCODE = '23514';
  END IF;

  report_title := CASE p_category
    WHEN 'delivery_delay' THEN 'Giao hàng chậm'
    WHEN 'suspicious_address' THEN 'Địa chỉ bất thường'
    WHEN 'contact_issue' THEN 'Không liên lạc được'
    WHEN 'cargo_issue' THEN 'Hàng hóa bất thường'
    WHEN 'payment' THEN 'Vấn đề thanh toán'
    WHEN 'safety' THEN 'Vấn đề an toàn'
    ELSE 'Sự cố khác'
  END;

  INSERT INTO public.risk_reports (
    id,
    order_id,
    reported_by,
    updated_by,
    source,
    category,
    severity,
    status,
    title,
    description,
    reporter_role_snapshot,
    triage_due_at
  ) VALUES (
    p_report_id,
    p_order_id,
    actor_id,
    actor_id,
    'manual',
    p_category,
    'medium',
    'open',
    report_title,
    normalized_description,
    actor_role::text,
    now() + interval '10 minutes'
  );

  INSERT INTO public.risk_report_attachments (
    risk_report_id,
    order_id,
    evidence_type,
    storage_path,
    added_by
  )
  SELECT p_report_id, p_order_id, 'photo', path, actor_id
  FROM unnest(normalized_photos) AS path;

  IF p_latitude IS NOT NULL THEN
    INSERT INTO public.risk_report_attachments (
      risk_report_id,
      order_id,
      evidence_type,
      latitude,
      longitude,
      captured_at,
      added_by
    ) VALUES (
      p_report_id,
      p_order_id,
      'location',
      p_latitude,
      p_longitude,
      COALESCE(p_location_captured_at, now()),
      actor_id
    );
  END IF;

  INSERT INTO public.risk_report_message_evidence (
    risk_report_id,
    source_message_id,
    order_id,
    sender_id,
    message_type,
    body_snapshot,
    sent_at_snapshot,
    added_by
  )
  SELECT
    p_report_id,
    message.id,
    message.order_id,
    message.sender_id,
    message.message_type,
    message.body,
    message.created_at,
    actor_id
  FROM public.order_messages AS message
  WHERE message.order_id = p_order_id
    AND message.id = ANY(normalized_messages)
  ON CONFLICT (risk_report_id, source_message_id) DO NOTHING;

  RETURN QUERY SELECT p_report_id, 'open'::text;
END;
$$;

REVOKE ALL ON FUNCTION public.create_participant_risk_report(
  uuid,
  uuid,
  text,
  text,
  text[],
  double precision,
  double precision,
  timestamptz,
  uuid[]
) FROM public, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.create_participant_risk_report(
  uuid,
  uuid,
  text,
  text,
  text[],
  double precision,
  double precision,
  timestamptz,
  uuid[]
) TO authenticated;

COMMENT ON TABLE public.risk_report_attachments IS
  'Immutable photo and location snapshots attached to an order risk report.';
COMMENT ON FUNCTION public.create_participant_risk_report(
  uuid,
  uuid,
  text,
  text,
  text[],
  double precision,
  double precision,
  timestamptz,
  uuid[]
) IS 'Creates one validated Customer/Driver report with immutable evidence.';
