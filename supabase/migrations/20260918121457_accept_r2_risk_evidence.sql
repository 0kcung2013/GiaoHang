-- Chấp nhận ảnh bằng chứng mới trên R2 và vẫn kiểm tra object Supabase cũ.
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
  legacy_photos text[] := ARRAY[]::text[];
  photo_path text;
  r2_prefix text;
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
  IF actor_role NOT IN ('customer'::public.user_role, 'driver'::public.user_role) THEN
    RAISE EXCEPTION 'Only Customer or Driver can use this command' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0002'; END IF;
  IF NOT (
    (actor_role = 'customer'::public.user_role AND v_order.customer_id = actor_id)
    OR (actor_role = 'driver'::public.user_role AND v_order.driver_id = actor_id)
  ) THEN
    RAISE EXCEPTION 'Reporter is not a participant of this order' USING ERRCODE = '42501';
  END IF;

  IF p_category NOT IN (
    'delivery_delay', 'suspicious_address', 'contact_issue', 'cargo_issue',
    'payment', 'safety', 'other'
  ) THEN
    RAISE EXCEPTION 'Unsupported participant risk category' USING ERRCODE = '22023';
  END IF;
  IF char_length(normalized_description) NOT BETWEEN 10 AND 4000 THEN
    RAISE EXCEPTION 'Description must contain between 10 and 4000 characters' USING ERRCODE = '22023';
  END IF;

  SELECT count(DISTINCT path), count(*)
  INTO requested_photo_count, matched_photo_count
  FROM unnest(normalized_photos) AS path;
  IF matched_photo_count > 5 OR requested_photo_count <> matched_photo_count THEN
    RAISE EXCEPTION 'Select at most five unique photos' USING ERRCODE = '22023';
  END IF;

  r2_prefix := 'r2://media/orders/' || p_order_id::text
    || '/risk-evidence/' || p_report_id::text || '/';
  FOREACH photo_path IN ARRAY normalized_photos LOOP
    IF left(photo_path, 5) = 'r2://' THEN
      IF left(photo_path, char_length(r2_prefix)) <> r2_prefix
        OR photo_path LIKE '%..%'
        OR photo_path LIKE '%\%' THEN
        RAISE EXCEPTION 'R2 photo path does not belong to this report' USING ERRCODE = '42501';
      END IF;
    ELSE
      IF (storage.foldername(photo_path))[1] <> actor_id::text
        OR (storage.foldername(photo_path))[2] <> p_report_id::text
        OR array_length(storage.foldername(photo_path), 1) <> 2 THEN
        RAISE EXCEPTION 'Photo path does not belong to this report' USING ERRCODE = '42501';
      END IF;
      legacy_photos := array_append(legacy_photos, photo_path);
    END IF;
  END LOOP;

  SELECT count(*) INTO matched_photo_count
  FROM storage.objects AS object
  WHERE object.bucket_id = 'risk-report-evidence'
    AND object.name = ANY(legacy_photos);
  IF matched_photo_count <> cardinality(legacy_photos) THEN
    RAISE EXCEPTION 'Every legacy photo must be uploaded before report creation' USING ERRCODE = '23514';
  END IF;

  IF (p_latitude IS NULL) <> (p_longitude IS NULL) THEN
    RAISE EXCEPTION 'Latitude and longitude must be supplied together' USING ERRCODE = '22023';
  END IF;
  IF p_latitude IS NOT NULL
    AND (p_latitude NOT BETWEEN -90 AND 90 OR p_longitude NOT BETWEEN -180 AND 180) THEN
    RAISE EXCEPTION 'Invalid location coordinates' USING ERRCODE = '22023';
  END IF;

  SELECT count(DISTINCT message_id) INTO requested_message_count
  FROM unnest(normalized_messages) AS message_id;
  IF requested_message_count > 20 THEN
    RAISE EXCEPTION 'Select at most twenty messages' USING ERRCODE = '22023';
  END IF;
  SELECT count(*) INTO matched_message_count
  FROM public.order_messages AS message
  WHERE message.order_id = p_order_id AND message.id = ANY(normalized_messages);
  IF matched_message_count <> requested_message_count THEN
    RAISE EXCEPTION 'Every message must belong to the report order' USING ERRCODE = '23514';
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
    id, order_id, reported_by, updated_by, source, category, severity,
    status, title, description, reporter_role_snapshot, triage_due_at
  ) VALUES (
    p_report_id, p_order_id, actor_id, actor_id, 'manual', p_category,
    'medium', 'open', report_title, normalized_description,
    actor_role::text, now() + interval '10 minutes'
  );

  INSERT INTO public.risk_report_attachments (
    risk_report_id, order_id, evidence_type, storage_path, added_by
  )
  SELECT p_report_id, p_order_id, 'photo', path, actor_id
  FROM unnest(normalized_photos) AS path;

  IF p_latitude IS NOT NULL THEN
    INSERT INTO public.risk_report_attachments (
      risk_report_id, order_id, evidence_type, latitude, longitude,
      captured_at, added_by
    ) VALUES (
      p_report_id, p_order_id, 'location', p_latitude, p_longitude,
      COALESCE(p_location_captured_at, now()), actor_id
    );
  END IF;

  INSERT INTO public.risk_report_message_evidence (
    risk_report_id, source_message_id, order_id, sender_id, message_type,
    body_snapshot, sent_at_snapshot, added_by
  )
  SELECT p_report_id, message.id, message.order_id, message.sender_id,
    message.message_type, message.body, message.created_at, actor_id
  FROM public.order_messages AS message
  WHERE message.order_id = p_order_id AND message.id = ANY(normalized_messages)
  ON CONFLICT (risk_report_id, source_message_id) DO NOTHING;

  RETURN QUERY SELECT p_report_id, 'open'::text;
END;
$$;
