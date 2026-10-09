
-- Reuse existing tables; preserve message/evidence IDs before removing legacy tables.
-- User approved the scope on 2026-10-09. GPS history older than 14 days is retired.
BEGIN;
SET LOCAL lock_timeout = '5s';
LOCK TABLE public.support_ticket_messages, public.risk_report_messages,
  public.risk_report_notes, public.risk_report_attachments,
  public.risk_report_message_evidence, public.driver_locations
  IN ACCESS EXCLUSIVE MODE;

DO $preflight$
BEGIN
  IF to_regclass('public.case_messages') IS NOT NULL
    OR to_regclass('public.risk_report_evidence') IS NOT NULL THEN
    RAISE EXCEPTION 'Consolidation target already exists';
  END IF;
  IF EXISTS (SELECT 1 FROM public.driver_locations
    WHERE created_at >= now() - interval '14 days') THEN
    RAISE EXCEPTION 'Refusing to retire GPS history with points within 14 days';
  END IF;
  IF EXISTS (SELECT 1 FROM public.risk_report_messages r
    JOIN public.support_ticket_messages s USING(id)) THEN
    RAISE EXCEPTION 'Conflicting support/risk message IDs';
  END IF;
  IF EXISTS (SELECT 1 FROM public.risk_report_notes n
    JOIN public.support_ticket_messages s USING(id)) THEN
    RAISE EXCEPTION 'Conflicting support/note IDs';
  END IF;
  IF EXISTS (SELECT 1 FROM public.risk_report_notes n
    JOIN public.risk_report_messages m USING(id)
    WHERE n.risk_report_id IS DISTINCT FROM m.risk_report_id
      OR n.author_id IS DISTINCT FROM m.sender_id OR m.visibility <> 'internal'
      OR n.body IS DISTINCT FROM m.body OR n.created_at IS DISTINCT FROM m.created_at) THEN
    RAISE EXCEPTION 'Conflicting mirrored internal notes';
  END IF;
  IF EXISTS (SELECT 1 FROM public.risk_report_attachments a
    JOIN public.risk_report_message_evidence m USING(id)) THEN
    RAISE EXCEPTION 'Conflicting evidence IDs';
  END IF;
END;
$preflight$;

ALTER TABLE public.support_ticket_messages RENAME TO case_messages;
ALTER TABLE public.case_messages ALTER COLUMN ticket_id DROP NOT NULL;
ALTER TABLE public.case_messages ADD COLUMN risk_report_id uuid
  REFERENCES public.risk_reports(id) ON DELETE CASCADE;
ALTER TABLE public.case_messages ADD CONSTRAINT case_messages_one_case_check
  CHECK ((ticket_id IS NOT NULL) <> (risk_report_id IS NOT NULL));
ALTER TABLE public.case_messages RENAME CONSTRAINT support_ticket_messages_pkey TO case_messages_pkey;
ALTER TABLE public.case_messages RENAME CONSTRAINT support_ticket_messages_ticket_id_fkey TO case_messages_ticket_id_fkey;
ALTER TABLE public.case_messages RENAME CONSTRAINT support_ticket_messages_sender_id_fkey TO case_messages_sender_id_fkey;
ALTER TABLE public.case_messages RENAME CONSTRAINT support_ticket_messages_body_check TO case_messages_body_check;
ALTER TABLE public.case_messages RENAME CONSTRAINT support_ticket_messages_sender_role_snapshot_check TO case_messages_sender_role_snapshot_check;
ALTER TABLE public.case_messages RENAME CONSTRAINT support_ticket_messages_visibility_check TO case_messages_visibility_check;
ALTER INDEX public.support_ticket_messages_ticket_idx RENAME TO case_messages_ticket_idx;
ALTER INDEX public.support_ticket_messages_sender_idx RENAME TO case_messages_sender_idx;
CREATE INDEX case_messages_report_idx ON public.case_messages(risk_report_id,created_at,id)
  WHERE risk_report_id IS NOT NULL;

INSERT INTO public.case_messages(id,risk_report_id,sender_id,sender_role_snapshot,visibility,body,created_at)
SELECT id,risk_report_id,sender_id,sender_role_snapshot,visibility,body,created_at
FROM public.risk_report_messages;
INSERT INTO public.case_messages(id,risk_report_id,sender_id,sender_role_snapshot,visibility,body,created_at)
SELECT n.id,n.risk_report_id,n.author_id,u.role::text,'internal',n.body,n.created_at
FROM public.risk_report_notes n JOIN public.users u ON u.id=n.author_id
WHERE NOT EXISTS (SELECT 1 FROM public.case_messages m WHERE m.id=n.id);

ALTER TABLE public.risk_report_attachments RENAME TO risk_report_evidence;
ALTER TABLE public.risk_report_evidence DROP CONSTRAINT risk_report_attachments_evidence_type_check;
ALTER TABLE public.risk_report_evidence DROP CONSTRAINT risk_report_attachment_shape_check;
ALTER TABLE public.risk_report_evidence
  ADD COLUMN source_message_id uuid REFERENCES public.order_messages(id) ON DELETE SET NULL,
  ADD COLUMN sender_id uuid REFERENCES public.users(id) ON DELETE RESTRICT,
  ADD COLUMN message_type text,
  ADD COLUMN body_snapshot text,
  ADD COLUMN sent_at_snapshot timestamptz;
ALTER TABLE public.risk_report_evidence
  ADD CONSTRAINT risk_report_evidence_type_check CHECK(evidence_type IN ('photo','location','message')),
  ADD CONSTRAINT risk_report_evidence_shape_check CHECK (
    CASE evidence_type
      WHEN 'photo' THEN storage_path IS NOT NULL AND latitude IS NULL AND longitude IS NULL
        AND source_message_id IS NULL AND sender_id IS NULL AND message_type IS NULL
        AND body_snapshot IS NULL AND sent_at_snapshot IS NULL
      WHEN 'location' THEN storage_path IS NULL AND latitude IS NOT NULL AND longitude IS NOT NULL
        AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180
        AND source_message_id IS NULL AND sender_id IS NULL AND message_type IS NULL
        AND body_snapshot IS NULL AND sent_at_snapshot IS NULL
      WHEN 'message' THEN storage_path IS NULL AND latitude IS NULL AND longitude IS NULL
        AND sender_id IS NOT NULL AND message_type IS NOT NULL
        AND message_type IN ('text','quick_reply','system') AND body_snapshot IS NOT NULL
        AND char_length(trim(body_snapshot)) BETWEEN 1 AND 1000 AND sent_at_snapshot IS NOT NULL
      ELSE false END
  ),
  ADD CONSTRAINT risk_report_evidence_message_source_unique UNIQUE(risk_report_id,source_message_id);
ALTER TABLE public.risk_report_evidence RENAME CONSTRAINT risk_report_attachments_pkey TO risk_report_evidence_pkey;
ALTER TABLE public.risk_report_evidence RENAME CONSTRAINT risk_report_attachments_risk_report_id_fkey TO risk_report_evidence_risk_report_id_fkey;
ALTER TABLE public.risk_report_evidence RENAME CONSTRAINT risk_report_attachments_order_id_fkey TO risk_report_evidence_order_id_fkey;
ALTER TABLE public.risk_report_evidence RENAME CONSTRAINT risk_report_attachments_added_by_fkey TO risk_report_evidence_added_by_fkey;
ALTER TABLE public.risk_report_evidence RENAME CONSTRAINT risk_report_attachment_photo_unique TO risk_report_evidence_photo_unique;
ALTER INDEX public.risk_report_attachments_order_idx RENAME TO risk_report_evidence_order_idx;
ALTER INDEX public.risk_report_attachments_report_idx RENAME TO risk_report_evidence_report_idx;
CREATE INDEX risk_report_evidence_added_by_idx ON public.risk_report_evidence(added_by);
CREATE INDEX risk_report_evidence_sender_idx ON public.risk_report_evidence(sender_id) WHERE sender_id IS NOT NULL;
CREATE INDEX risk_report_evidence_source_idx ON public.risk_report_evidence(source_message_id) WHERE source_message_id IS NOT NULL;

INSERT INTO public.risk_report_evidence(id,risk_report_id,order_id,evidence_type,
  source_message_id,sender_id,message_type,body_snapshot,sent_at_snapshot,added_by,created_at)
SELECT id,risk_report_id,order_id,'message',source_message_id,sender_id,message_type,
  body_snapshot,sent_at_snapshot,added_by,created_at
FROM public.risk_report_message_evidence;

DO $preserved$
BEGIN
  IF EXISTS (SELECT 1 FROM public.risk_report_messages old LEFT JOIN public.case_messages m USING(id)
    WHERE m.id IS NULL OR m.ticket_id IS NOT NULL
      OR ROW(old.risk_report_id,old.sender_id,old.sender_role_snapshot,old.visibility,old.body,old.created_at)
      IS DISTINCT FROM ROW(m.risk_report_id,m.sender_id,m.sender_role_snapshot,m.visibility,m.body,m.created_at)) THEN
    RAISE EXCEPTION 'Risk messages were not preserved';
  END IF;
  IF EXISTS (SELECT 1 FROM public.risk_report_notes old LEFT JOIN public.case_messages m USING(id)
    WHERE m.id IS NULL OR m.visibility <> 'internal'
      OR ROW(old.risk_report_id,old.author_id,old.body,old.created_at)
      IS DISTINCT FROM ROW(m.risk_report_id,m.sender_id,m.body,m.created_at)) THEN
    RAISE EXCEPTION 'Internal notes were not preserved';
  END IF;
  IF EXISTS (SELECT 1 FROM public.risk_report_message_evidence old
    LEFT JOIN public.risk_report_evidence e USING(id)
    WHERE e.id IS NULL OR e.evidence_type <> 'message'
      OR ROW(old.risk_report_id,old.order_id,old.source_message_id,old.sender_id,
        old.message_type,old.body_snapshot,old.sent_at_snapshot,old.added_by,old.created_at)
      IS DISTINCT FROM ROW(e.risk_report_id,e.order_id,e.source_message_id,e.sender_id,
        e.message_type,e.body_snapshot,e.sent_at_snapshot,e.added_by,e.created_at)) THEN
    RAISE EXCEPTION 'Message evidence was not preserved';
  END IF;
END;
$preserved$;

DROP POLICY support_ticket_messages_requester_or_staff_select ON public.case_messages;
CREATE POLICY case_messages_participant_or_staff_select ON public.case_messages
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.users actor WHERE actor.id=(SELECT auth.uid())
    AND actor.role IN ('support'::public.user_role,'admin'::public.user_role))
  OR (visibility='public' AND (
    EXISTS (SELECT 1 FROM public.support_tickets t WHERE t.id=case_messages.ticket_id
      AND t.requester_id=(SELECT auth.uid()))
    OR EXISTS (SELECT 1 FROM public.risk_reports r WHERE r.id=case_messages.risk_report_id
      AND r.reported_by=(SELECT auth.uid()))))
);
DROP POLICY risk_attachments_participant_select ON public.risk_report_evidence;
DROP POLICY risk_attachments_staff_select ON public.risk_report_evidence;
CREATE POLICY risk_report_evidence_participant_select ON public.risk_report_evidence
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.risk_reports r WHERE r.id=risk_report_evidence.risk_report_id
    AND r.reported_by=(SELECT auth.uid()))
);
CREATE POLICY risk_report_evidence_staff_select ON public.risk_report_evidence
FOR SELECT TO authenticated USING (
  (evidence_type='message' AND (SELECT private.can_review_order_chat(risk_report_evidence.order_id)))
  OR (evidence_type IN ('photo','location') AND EXISTS (SELECT 1 FROM public.users actor
    WHERE actor.id=(SELECT auth.uid()) AND actor.role IN ('support'::public.user_role,'admin'::public.user_role)))
);
-- Keep internal-note audit details hidden even when a note is posted as a message.
DROP POLICY risk_report_events_case_select ON public.risk_report_events;
CREATE POLICY risk_report_events_case_select ON public.risk_report_events
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.risk_reports r WHERE r.id=risk_report_events.risk_report_id
    AND (r.reported_by=(SELECT auth.uid()) OR EXISTS (SELECT 1 FROM public.users actor
      WHERE actor.id=(SELECT auth.uid()) AND actor.role IN ('support'::public.user_role,'admin'::public.user_role))))
  AND ((event_type <> 'note_added' AND COALESCE(details->>'visibility','public') <> 'internal')
    OR EXISTS (SELECT 1 FROM public.users actor WHERE actor.id=(SELECT auth.uid())
      AND actor.role IN ('support'::public.user_role,'admin'::public.user_role)))
);
ALTER TABLE public.case_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_report_evidence ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.case_messages, public.risk_report_evidence FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.case_messages, public.risk_report_evidence TO authenticated;
GRANT ALL ON public.case_messages, public.risk_report_evidence TO service_role;

-- Return types owned by the removed tables require explicit recreation.
DROP FUNCTION public.add_risk_report_note(uuid,text) RESTRICT;
DROP FUNCTION public.post_risk_report_message(uuid,text,text) RESTRICT;
DROP FUNCTION public.attach_risk_report_message_evidence(uuid,uuid[]) RESTRICT;
CREATE OR REPLACE FUNCTION private.require_recipient_call_evidence()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NEW.category = 'contact_issue' AND NEW.source = 'manual'
    AND NEW.reporter_role_snapshot = 'driver'
    AND EXISTS (SELECT 1 FROM public.order_status_logs WHERE order_id = NEW.order_id
      AND logged_by = NEW.reported_by AND title = 'Tài xế đã đến điểm giao')
    AND NOT EXISTS (SELECT 1 FROM public.risk_report_evidence
      WHERE risk_report_id = NEW.id AND evidence_type = 'photo'
        AND storage_path IS NOT NULL AND length(trim(storage_path)) > 0) THEN
    RAISE EXCEPTION 'RECIPIENT_CALL_EVIDENCE_REQUIRED' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION private.seed_support_ticket_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  creator_role public.user_role;
BEGIN
  SELECT role INTO creator_role
  FROM public.users
  WHERE id = NEW.created_by;

  INSERT INTO public.case_messages (
    ticket_id,
    sender_id,
    sender_role_snapshot,
    visibility,
    body,
    created_at
  ) VALUES (
    NEW.id,
    NEW.created_by,
    creator_role::text,
    'public',
    NEW.message,
    NEW.created_at
  );

  IF creator_role IN (
    'support'::public.user_role,
    'admin'::public.user_role
  ) THEN
    PERFORM private.enqueue_linked_case_notification(
      NEW.requester_id,
      'Yêu cầu hỗ trợ mới',
      NEW.subject,
      'support_ticket_created',
      NEW.order_id, NEW.id
    );
  END IF;
  RETURN NEW;
END;
$function$;


CREATE OR REPLACE FUNCTION public.add_risk_report_note(p_report_id uuid,p_body text)
RETURNS public.case_messages LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  actor_id uuid := private.require_risk_staff();
  actor_role public.user_role;
  report public.risk_reports%ROWTYPE;
  created_message public.case_messages%ROWTYPE;
  normalized_body text := trim(COALESCE(p_body,''));
BEGIN
  IF char_length(normalized_body) NOT BETWEEN 3 AND 4000 THEN
    RAISE EXCEPTION 'Note must contain between 3 and 4000 characters' USING ERRCODE='22023';
  END IF;
  SELECT role INTO actor_role FROM public.users WHERE id=actor_id;
  SELECT * INTO report FROM public.risk_reports WHERE id=p_report_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Risk report not found' USING ERRCODE='P0002'; END IF;
  IF report.assigned_to IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'Only the assigned staff member can add internal notes' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.case_messages(risk_report_id,sender_id,sender_role_snapshot,visibility,body)
  VALUES(p_report_id,actor_id,actor_role::text,'internal',normalized_body)
  RETURNING * INTO created_message;
  INSERT INTO public.risk_report_events(risk_report_id,actor_id,event_type,from_status,to_status,details)
  VALUES(p_report_id,actor_id,'note_added',report.status,report.status,
    jsonb_build_object('note_id',created_message.id,'message_id',created_message.id,'visibility','internal'));
  RETURN created_message;
END;
$function$;

CREATE OR REPLACE FUNCTION public.attach_risk_report_message_evidence(p_risk_report_id uuid, p_message_ids uuid[])
 RETURNS SETOF risk_report_evidence
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor_id uuid := (select auth.uid());
  report_order_id uuid;
  requested_count integer;
  matched_count integer;
begin
  if actor_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.users as actor
    where actor.id = actor_id
      and actor.role in (
        'support'::public.user_role,
        'admin'::public.user_role
      )
  ) then
    raise exception 'Only Support or Admin can attach message evidence'
      using errcode = '42501';
  end if;

  select rr.order_id
  into report_order_id
  from public.risk_reports as rr
  where rr.id = p_risk_report_id;

  if report_order_id is null then
    raise exception 'Risk report not found' using errcode = 'P0002';
  end if;

  select count(distinct message_id)
  into requested_count
  from unnest(coalesce(p_message_ids, array[]::uuid[])) as message_id;

  if requested_count < 1 or requested_count > 20 then
    raise exception 'Select between 1 and 20 messages'
      using errcode = '22023';
  end if;

  select count(*)
  into matched_count
  from public.order_messages as message
  where message.order_id = report_order_id
    and message.id = any(p_message_ids);

  if matched_count <> requested_count then
    raise exception 'Every message must belong to the risk report order'
      using errcode = '23514';
  end if;

  insert into public.risk_report_evidence (
    evidence_type, risk_report_id,
    source_message_id,
    order_id,
    sender_id,
    message_type,
    body_snapshot,
    sent_at_snapshot,
    added_by
  )
  select
    'message', p_risk_report_id,
    message.id,
    message.order_id,
    message.sender_id,
    message.message_type,
    message.body,
    message.created_at,
    actor_id
  from public.order_messages as message
  where message.order_id = report_order_id
    and message.id = any(p_message_ids)
  on conflict on constraint risk_report_evidence_message_source_unique do nothing;

  update public.risk_reports
  set updated_by = actor_id,
      updated_at = now()
  where id = p_risk_report_id;

  return query
  select evidence.*
  from public.risk_report_evidence as evidence
  where evidence.risk_report_id = p_risk_report_id
    and evidence.evidence_type = 'message'
  order by evidence.sent_at_snapshot, evidence.id;
end;
$function$;

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
$function$;

CREATE OR REPLACE FUNCTION public.post_risk_report_message(p_report_id uuid, p_body text, p_visibility text DEFAULT 'public'::text)
 RETURNS case_messages
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  report public.risk_reports%ROWTYPE;
  created_message public.case_messages%ROWTYPE;
  normalized_body text := trim(COALESCE(p_body, ''));
BEGIN
  SELECT role INTO actor_role
  FROM public.users
  WHERE id = actor_id;
  IF actor_id IS NULL OR actor_role IS NULL THEN
    RAISE EXCEPTION 'Authenticated user profile is required'
      USING ERRCODE = '42501';
  END IF;
  IF char_length(normalized_body) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'Message must contain between 1 and 4000 characters'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO report
  FROM public.risk_reports
  WHERE id = p_report_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Risk report not found' USING ERRCODE = 'P0002';
  END IF;
  IF report.status IN ('resolved', 'dismissed') THEN
    RAISE EXCEPTION 'Closed risk report cannot receive messages'
      USING ERRCODE = '23514';
  END IF;

  IF actor_role IN (
    'customer'::public.user_role,
    'driver'::public.user_role
  ) THEN
    IF report.reported_by <> actor_id OR p_visibility <> 'public' THEN
      RAISE EXCEPTION 'Reporter cannot post this message'
        USING ERRCODE = '42501';
    END IF;
  ELSIF actor_role IN (
    'support'::public.user_role,
    'admin'::public.user_role
  ) THEN
    IF report.assigned_to IS DISTINCT FROM actor_id THEN
      RAISE EXCEPTION 'Accept the report before replying'
        USING ERRCODE = '42501';
    END IF;
    IF p_visibility NOT IN ('public', 'internal') THEN
      RAISE EXCEPTION 'Unsupported message visibility'
        USING ERRCODE = '22023';
    END IF;
  ELSE
    RAISE EXCEPTION 'Role cannot post risk report messages'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.case_messages (
    risk_report_id,
    sender_id,
    sender_role_snapshot,
    visibility,
    body
  ) VALUES (
    report.id,
    actor_id,
    actor_role::text,
    p_visibility,
    normalized_body
  )
  RETURNING * INTO created_message;

  INSERT INTO public.risk_report_events (
    risk_report_id,
    actor_id,
    event_type,
    from_status,
    to_status,
    details
  ) VALUES (
    report.id,
    actor_id,
    'message_added',
    report.status,
    report.status,
    jsonb_build_object(
      'message_id', created_message.id,
      'visibility', p_visibility
    )
  );

  IF actor_role IN (
    'support'::public.user_role,
    'admin'::public.user_role
  ) AND p_visibility = 'public' THEN
    UPDATE public.risk_reports
    SET first_response_at = COALESCE(first_response_at, now()),
        updated_by = actor_id
    WHERE id = report.id
    RETURNING * INTO report;

    IF report.reported_by <> actor_id THEN
      PERFORM private.enqueue_linked_case_notification(
        report.reported_by,
        'CSKH vừa phản hồi báo cáo sự cố',
        normalized_body,
        'risk_report_message',
        report.order_id, NULL, report.id
      );
    END IF;
  ELSIF actor_role IN (
    'customer'::public.user_role,
    'driver'::public.user_role
  ) AND report.assigned_to IS NOT NULL THEN
    IF report.status = 'waiting_customer' THEN
      UPDATE public.risk_reports
      SET status = 'investigating',
          updated_by = actor_id
      WHERE id = report.id
      RETURNING * INTO report;
    END IF;

    PERFORM private.enqueue_linked_case_notification(
      report.assigned_to,
      'Người báo cáo vừa phản hồi',
      normalized_body,
      'risk_report_participant_message',
      report.order_id, NULL, report.id
    );
  END IF;
  RETURN created_message;
END;
$function$;

CREATE OR REPLACE FUNCTION public.post_support_ticket_message(p_ticket_id uuid, p_body text, p_visibility text DEFAULT 'public'::text)
 RETURNS case_messages
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  ticket public.support_tickets%ROWTYPE;
  created_message public.case_messages%ROWTYPE;
  normalized_body text := trim(COALESCE(p_body, ''));
BEGIN
  SELECT role INTO actor_role
  FROM public.users
  WHERE id = actor_id;
  IF actor_id IS NULL OR actor_role IS NULL THEN
    RAISE EXCEPTION 'Authenticated user profile is required'
      USING ERRCODE = '42501';
  END IF;
  IF char_length(normalized_body) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'Message must contain between 1 and 4000 characters'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO ticket
  FROM public.support_tickets
  WHERE id = p_ticket_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Support ticket not found' USING ERRCODE = 'P0002';
  END IF;
  IF ticket.status IN ('resolved', 'closed') THEN
    RAISE EXCEPTION 'Closed support ticket cannot receive messages'
      USING ERRCODE = '23514';
  END IF;

  IF actor_role IN (
    'customer'::public.user_role,
    'driver'::public.user_role
  ) THEN
    IF ticket.requester_id <> actor_id OR p_visibility <> 'public' THEN
      RAISE EXCEPTION 'Requester cannot post this message'
        USING ERRCODE = '42501';
    END IF;
  ELSIF actor_role IN (
    'support'::public.user_role,
    'admin'::public.user_role
  ) THEN
    IF ticket.assigned_to IS DISTINCT FROM actor_id THEN
      RAISE EXCEPTION 'Accept the ticket before replying'
        USING ERRCODE = '42501';
    END IF;
    IF p_visibility NOT IN ('public', 'internal') THEN
      RAISE EXCEPTION 'Unsupported message visibility'
        USING ERRCODE = '22023';
    END IF;
  ELSE
    RAISE EXCEPTION 'Role cannot post support messages'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.case_messages (
    ticket_id,
    sender_id,
    sender_role_snapshot,
    visibility,
    body
  ) VALUES (
    ticket.id,
    actor_id,
    actor_role::text,
    p_visibility,
    normalized_body
  )
  RETURNING * INTO created_message;

  IF actor_role IN (
    'support'::public.user_role,
    'admin'::public.user_role
  ) THEN
    UPDATE public.support_tickets
    SET first_response_at = CASE
          WHEN p_visibility = 'public'
            THEN COALESCE(first_response_at, now())
          ELSE first_response_at
        END,
        updated_at = now()
    WHERE id = ticket.id
    RETURNING * INTO ticket;

    IF p_visibility = 'public' THEN
      PERFORM private.enqueue_linked_case_notification(
        ticket.requester_id,
        'CSKH vừa phản hồi',
        normalized_body,
        'support_ticket_message',
        ticket.order_id, ticket.id
      );
    END IF;
  ELSE
    UPDATE public.support_tickets
    SET status = CASE
          WHEN status = 'waiting_customer' THEN 'in_progress'
          ELSE status
        END,
        updated_at = now()
    WHERE id = ticket.id
    RETURNING * INTO ticket;

    IF ticket.assigned_to IS NOT NULL THEN
      PERFORM private.enqueue_linked_case_notification(
        ticket.assigned_to,
        'Người dùng vừa phản hồi',
        normalized_body,
        'support_ticket_customer_message',
        ticket.order_id, ticket.id
      );
    END IF;
  END IF;

  RETURN created_message;
END;
$function$;

CREATE OR REPLACE FUNCTION public.reopen_support_ticket(p_ticket_id uuid, p_message text)
 RETURNS support_tickets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE actor_id uuid := (SELECT auth.uid()); ticket public.support_tickets%ROWTYPE;
  actor_role text; normalized text := trim(COALESCE(p_message,''));
BEGIN
  IF actor_id IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT role::text INTO actor_role FROM public.users WHERE id=actor_id;
  SELECT * INTO ticket FROM public.support_tickets WHERE id=p_ticket_id FOR UPDATE;
  IF NOT FOUND OR ticket.requester_id IS DISTINCT FROM actor_id OR actor_role NOT IN ('customer','driver') THEN
    RAISE EXCEPTION 'Only the requester can reopen this conversation' USING ERRCODE='42501';
  END IF;
  IF ticket.status NOT IN ('resolved','closed') THEN
    RAISE EXCEPTION 'Yêu cầu đã được mở lại. Hãy tải lại hội thoại.' USING ERRCODE='23514';
  END IF;
  IF char_length(normalized) NOT BETWEEN 3 AND 3900 THEN
    RAISE EXCEPTION 'Vui lòng nêu vấn đề cần tiếp tục hỗ trợ.' USING ERRCODE='22023';
  END IF;
  UPDATE public.support_tickets SET status='in_progress' WHERE id=ticket.id RETURNING * INTO ticket;
  INSERT INTO public.case_messages(ticket_id,sender_id,sender_role_snapshot,visibility,body)
    VALUES(ticket.id,actor_id,actor_role,'public','Mở lại yêu cầu: ' || normalized);
  PERFORM private.enqueue_linked_case_notification(ticket.assigned_to,'Người dùng mở lại yêu cầu',
    normalized,'support_ticket_customer_message',ticket.order_id,ticket.id);
  RETURN ticket;
END;
$function$;

CREATE OR REPLACE FUNCTION public.transition_support_ticket(p_ticket_id uuid, p_status text, p_resolution text DEFAULT NULL::text)
 RETURNS support_tickets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor_id uuid := private.require_risk_staff();
  ticket public.support_tickets%ROWTYPE;
  normalized_resolution text := NULLIF(trim(p_resolution), '');
  admin_id uuid;
BEGIN
  SELECT * INTO ticket
  FROM public.support_tickets
  WHERE id = p_ticket_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Support ticket not found' USING ERRCODE = 'P0002';
  END IF;
  IF ticket.assigned_to IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'Only the assigned staff member can transition this ticket'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.support_tickets
  SET status = p_status,
      resolution = CASE
        WHEN p_status IN ('resolved', 'closed') THEN normalized_resolution
        ELSE resolution
      END
  WHERE id = p_ticket_id
  RETURNING * INTO ticket;

  INSERT INTO public.case_messages(ticket_id,sender_id,sender_role_snapshot,visibility,body)
  SELECT ticket.id,actor_id,role::text,'public',
    CASE WHEN p_status IN ('resolved','closed')
      THEN left('Kết thúc: ' || ticket.resolution,4000)
      ELSE 'CSKH tiếp tục xử lý yêu cầu.' END
  FROM public.users WHERE id = actor_id;

  PERFORM private.enqueue_linked_case_notification(
    ticket.requester_id,
    'Yêu cầu hỗ trợ đã cập nhật',
    CASE p_status
      WHEN 'waiting_customer' THEN 'CSKH đang chờ bạn phản hồi.'
      WHEN 'waiting_admin' THEN 'Yêu cầu đã được chuyển Admin xem xét.'
      WHEN 'resolved' THEN COALESCE(ticket.resolution, 'Yêu cầu đã kết thúc.')
      WHEN 'closed' THEN COALESCE(ticket.resolution, 'Yêu cầu đã được đóng.')
      ELSE 'CSKH đang tiếp tục xử lý yêu cầu.'
    END,
    'support_ticket_status',
    ticket.order_id, ticket.id
  );

  IF p_status = 'waiting_admin' THEN
    FOR admin_id IN
      SELECT id FROM public.users
      WHERE role = 'admin'::public.user_role
    LOOP
      PERFORM private.enqueue_linked_case_notification(
        admin_id,
        'Yêu cầu hỗ trợ cần Admin',
        ticket.subject,
        'support_ticket_admin_required',
        ticket.order_id, ticket.id
      );
    END LOOP;
  END IF;
  RETURN ticket;
END;
$function$;

REVOKE ALL ON FUNCTION public.add_risk_report_note(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.add_risk_report_note(uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.post_risk_report_message(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.post_risk_report_message(uuid,text,text) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.attach_risk_report_message_evidence(uuid,uuid[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.attach_risk_report_message_evidence(uuid,uuid[]) TO authenticated;

-- Renaming support_ticket_messages preserves its existing Realtime publication membership.
DO $publication$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
    WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='case_messages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.case_messages;
  END IF;
END;
$publication$;
COMMENT ON TABLE public.case_messages IS 'Support-ticket and risk-report conversations; internal notes remain staff-only.';
COMMENT ON TABLE public.risk_report_evidence IS 'Immutable incident photo, location and message snapshots; independent of source-message expiry.';

DROP TABLE public.risk_report_notes RESTRICT;
DROP TABLE public.risk_report_messages RESTRICT;
DROP TABLE public.risk_report_message_evidence RESTRICT;
DROP TABLE public.driver_locations RESTRICT;

DO $verified$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname IN ('public','private') AND p.prokind IN ('f','p')
      AND p.prosrc ~ '\m(support_ticket_messages|risk_report_messages|risk_report_notes|risk_report_attachments|risk_report_message_evidence|driver_locations)\M') THEN
    RAISE EXCEPTION 'A function still references a retired table';
  END IF;
END;
$verified$;
NOTIFY pgrst, 'reload schema';
COMMIT;
