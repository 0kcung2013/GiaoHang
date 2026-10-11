-- Approved compact incident flow. Reuse current data, RPC signatures and grants.
-- The same order row lock serializes reporting, pickup and staff cancellation.
CREATE OR REPLACE FUNCTION public.create_participant_risk_report(p_report_id uuid, p_order_id uuid, p_category text, p_description text, p_photo_paths text[], p_latitude double precision, p_longitude double precision, p_location_captured_at timestamp with time zone, p_message_ids uuid[])
 RETURNS TABLE(report_id uuid, status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  -- Custody boundary is authoritative, including old clients and concurrent pickup.
  IF actor_role = 'driver'::public.user_role AND p_category = 'cargo_issue' THEN
    IF v_order.status NOT IN ('assigned'::public.order_status, 'picking_up'::public.order_status)
      OR v_order.actual_picked_up_at IS NOT NULL THEN
      RAISE EXCEPTION 'CARGO_REPORT_AFTER_PICKUP' USING ERRCODE='23514';
    END IF;
    IF cardinality(normalized_photos)=0 THEN
      RAISE EXCEPTION 'CARGO_PHOTO_REQUIRED' USING ERRCODE='23514';
    END IF;
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
    WHEN 'delivery_delay' THEN 'Giao hĂ ng cháº­m'
    WHEN 'suspicious_address' THEN 'Äá»‹a chá»‰ báº¥t thÆ°á»ng'
    WHEN 'contact_issue' THEN 'KhĂ´ng liĂªn láº¡c Ä‘Æ°á»£c'
    WHEN 'cargo_issue' THEN 'HĂ ng hĂ³a báº¥t thÆ°á»ng'
    WHEN 'payment' THEN 'Váº¥n Ä‘á» thanh toĂ¡n'
    WHEN 'safety' THEN 'Váº¥n Ä‘á» an toĂ n'
    ELSE 'Sá»± cá»‘ khĂ¡c'
  END;

  IF actor_role = 'driver'::public.user_role THEN
    report_title := CASE p_category
      WHEN 'cargo_issue' THEN 'Hàng không đúng thông tin · Yêu cầu hủy trước nhận hàng'
      WHEN 'contact_issue' THEN CASE WHEN v_order.actual_picked_up_at IS NOT NULL
        OR v_order.status='delivering'::public.order_status
        THEN 'Không thể giao hàng' ELSE 'Không thể nhận hàng' END
      WHEN 'other' THEN 'Sự cố khác'
      ELSE report_title END;
  END IF;

  INSERT INTO public.risk_reports (
    id, order_id, reported_by, updated_by, source, category, severity,
    status, title, description, reporter_role_snapshot, triage_due_at
  ) VALUES (
    p_report_id, p_order_id, actor_id, actor_id, 'manual', p_category,
    'medium', 'open', report_title, normalized_description,
    actor_role::text, now() + interval '10 minutes'
  );

  INSERT INTO public.risk_report_evidence (
    risk_report_id, order_id, evidence_type, storage_path, added_by
  )
  SELECT p_report_id, p_order_id, 'photo', path, actor_id
  FROM unnest(normalized_photos) AS path;

  IF p_latitude IS NOT NULL THEN
    INSERT INTO public.risk_report_evidence (
      risk_report_id, order_id, evidence_type, latitude, longitude,
      captured_at, added_by
    ) VALUES (
      p_report_id, p_order_id, 'location', p_latitude, p_longitude,
      COALESCE(p_location_captured_at, now()), actor_id
    );
  END IF;

  INSERT INTO public.risk_report_evidence (
    evidence_type, risk_report_id, source_message_id, order_id, sender_id, message_type,
    body_snapshot, sent_at_snapshot, added_by
  )
  SELECT 'message', p_report_id, message.id, message.order_id, message.sender_id,
    message.message_type, message.body, message.created_at, actor_id
  FROM public.order_messages AS message
  WHERE message.order_id = p_order_id AND message.id = ANY(normalized_messages)
  ON CONFLICT ON CONSTRAINT risk_report_evidence_message_source_unique DO NOTHING;

  RETURN QUERY SELECT p_report_id, 'open'::text;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.confirm_driver_pickup(p_order_id uuid)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_driver_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_confirmed_at timestamptz;
BEGIN
  IF v_driver_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users actor
    WHERE actor.id = v_driver_id AND actor.role = 'driver'::public.user_role
  ) THEN RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED'; END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.driver_id IS DISTINCT FROM v_driver_id
    THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED'; END IF;
  IF v_order.status <> 'picking_up'::public.order_status
    THEN RAISE EXCEPTION 'ORDER_NOT_PICKING_UP'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.risk_report_interventions intervention
    WHERE intervention.order_id = v_order.id
      AND intervention.driver_id = v_driver_id
      AND intervention.state IN ('return_required', 'handoff_required')
  ) THEN RAISE EXCEPTION 'CUSTODY_ACTION_REQUIRED'; END IF;

  IF v_order.actual_picked_up_at IS NULL AND EXISTS (
    SELECT 1 FROM public.risk_reports report
    JOIN public.risk_report_interventions intervention
      ON intervention.risk_report_id=report.id
    WHERE report.order_id=v_order.id AND report.category='cargo_issue'
      AND report.reporter_role_snapshot='driver' AND report.reported_by=v_driver_id
      AND report.status NOT IN ('resolved','dismissed')
      AND intervention.driver_id=v_driver_id
      AND intervention.state='awaiting_triage'
  ) THEN RAISE EXCEPTION 'PICKUP_INCIDENT_PENDING' USING ERRCODE='23514'; END IF;

  -- Reserve principal and confirm custody atomically; failed proof validation
  -- also rolls this hold back through the existing handoff trigger.
  PERFORM private.hold_paid_goods_deposit(v_order, v_driver_id);

  IF v_order.actual_picked_up_at IS NOT NULL THEN
    RETURN v_order.actual_picked_up_at;
  END IF;

  UPDATE public.orders
  SET actual_picked_up_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE id = p_order_id
  RETURNING actual_picked_up_at INTO v_confirmed_at;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, 'picking_up'::public.order_status, 'Tài xế đã nhận hàng',
    'Tài xế đã xác nhận nhận kiện và đang chờ bắt đầu giao.', v_driver_id
  );
  RETURN v_confirmed_at;
END;
$function$
;
CREATE OR REPLACE FUNCTION private.enforce_driver_handoff_geofence()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  proof public.order_delivery_proofs%ROWTYPE;
  handoff_stage text;
  target_lat double precision;
  target_lng double precision;
BEGIN
  -- A new assignment must not inherit the previous driver's handoff.
  IF NEW.driver_id IS DISTINCT FROM OLD.driver_id
     OR (NEW.status IN ('pending', 'confirmed', 'assigned')
         AND NEW.status IS DISTINCT FROM OLD.status) THEN
    NEW.actual_picked_up_at := NULL;
    RETURN NEW;
  END IF;

  IF OLD.status = 'picking_up'::public.order_status
     AND NEW.status = 'delivering'::public.order_status THEN
    -- Preserve the actual handoff time when the driver starts moving later.
    NEW.actual_picked_up_at := COALESCE(
      OLD.actual_picked_up_at, NEW.actual_picked_up_at
    );
  END IF;

  IF OLD.status IS NOT DISTINCT FROM NEW.status
     AND OLD.actual_picked_up_at IS NOT DISTINCT FROM NEW.actual_picked_up_at THEN
    RETURN NEW;
  END IF;

  -- Staff/system recovery workflows are handled by their own authorization
  -- rules. This guard targets status changes initiated by the assigned driver.
  IF OLD.driver_id IS NULL OR auth.uid() IS DISTINCT FROM OLD.driver_id THEN
    IF OLD.actual_picked_up_at IS DISTINCT FROM NEW.actual_picked_up_at
       AND auth.uid() IS NOT NULL
       AND NOT EXISTS (
         SELECT 1 FROM public.users actor
         WHERE actor.id = auth.uid() AND actor.role IN ('support', 'admin')
       ) THEN
      RAISE EXCEPTION 'PICKUP_CONFIRMATION_DRIVER_REQUIRED';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.status = 'picking_up'::public.order_status
     AND (
       NEW.status = 'delivering'::public.order_status
       OR (NEW.status = 'picking_up'::public.order_status
           AND OLD.actual_picked_up_at IS NULL
           AND NEW.actual_picked_up_at IS NOT NULL)
     ) THEN
    IF OLD.actual_picked_up_at IS NULL AND EXISTS (
    SELECT 1 FROM public.risk_reports report
    JOIN public.risk_report_interventions intervention
      ON intervention.risk_report_id=report.id
    WHERE report.order_id=OLD.id AND report.category='cargo_issue'
      AND report.reporter_role_snapshot='driver' AND report.reported_by=OLD.driver_id
      AND report.status NOT IN ('resolved','dismissed')
      AND intervention.driver_id=OLD.driver_id
      AND intervention.state='awaiting_triage'
    ) THEN RAISE EXCEPTION 'PICKUP_INCIDENT_PENDING' USING ERRCODE='23514'; END IF;
    handoff_stage := 'pickup';
    target_lat := OLD.pickup_lat;
    target_lng := OLD.pickup_lng;
  ELSIF OLD.status = 'delivering'::public.order_status
        AND NEW.status = 'delivered'::public.order_status THEN
    handoff_stage := 'delivery';
    target_lat := OLD.delivery_lat;
    target_lng := OLD.delivery_lng;
  ELSE
    IF OLD.actual_picked_up_at IS DISTINCT FROM NEW.actual_picked_up_at THEN
      RAISE EXCEPTION 'INVALID_PICKUP_CONFIRMATION_TRANSITION';
    END IF;
    RETURN NEW;
  END IF;

  SELECT handoff_proof.*
  INTO proof
  FROM public.order_delivery_proofs AS handoff_proof
  WHERE handoff_proof.order_id = OLD.id
    AND handoff_proof.driver_id = OLD.driver_id
    AND handoff_proof.stage = handoff_stage
  FOR UPDATE;

  IF NOT FOUND OR proof.captured_lat IS NULL
     OR proof.captured_lng IS NULL THEN
    IF handoff_stage = 'pickup' THEN
      RAISE EXCEPTION 'PICKUP_PROOF_LOCATION_REQUIRED'
        USING ERRCODE = '23514';
    END IF;
    RAISE EXCEPTION 'DELIVERY_PROOF_LOCATION_REQUIRED'
      USING ERRCODE = '23514';
  END IF;

  IF NOT public.ST_DWithin(
    public.ST_SetSRID(
      public.ST_MakePoint(proof.captured_lng, proof.captured_lat),
      4326
    )::public.geography,
    public.ST_SetSRID(
      public.ST_MakePoint(target_lng, target_lat),
      4326
    )::public.geography,
    100
  ) THEN
    IF handoff_stage = 'pickup' THEN
      RAISE EXCEPTION 'PICKUP_OUTSIDE_GEOFENCE'
        USING ERRCODE = '23514';
    END IF;
    RAISE EXCEPTION 'DELIVERY_OUTSIDE_GEOFENCE'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$
;
