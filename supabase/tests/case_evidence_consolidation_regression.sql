-- Exercise real RPCs and RLS with synthetic fixtures. No data is retained.
BEGIN;
CREATE TEMP TABLE consolidation_fixture (
  requester uuid, staff uuid, outsider uuid, other_staff uuid, driver uuid,
  order_id uuid, ticket_id uuid, report_id uuid, source_id uuid
) ON COMMIT DROP;
INSERT INTO consolidation_fixture VALUES (
  gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),
  gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid()
);
DO $fixture$
DECLARE f consolidation_fixture%ROWTYPE;
BEGIN
  SELECT * INTO f FROM consolidation_fixture;
  PERFORM set_config('request.jwt.claim.sub','',true);
  INSERT INTO public.users(id,email,full_name,role) VALUES
    (f.requester,f.requester::text || '@consolidation-test.invalid','Requester','customer'),
    (f.staff,f.staff::text || '@consolidation-test.invalid','Support','support'),
    (f.outsider,f.outsider::text || '@consolidation-test.invalid','Outsider','customer'),
    (f.other_staff,f.other_staff::text || '@consolidation-test.invalid','Other support','support'),
    (f.driver,f.driver::text || '@consolidation-test.invalid','Driver','driver');
  INSERT INTO public.orders(id,customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,
    delivery_address,delivery_lat,delivery_lng,tracking_code)
  VALUES(f.order_id,f.requester,f.driver,'delivering','Synthetic pickup',11,106,
    'Synthetic delivery',11.01,106.01,'GH-DEMO-CONSOLIDATE-' || f.order_id::text);
  INSERT INTO public.order_messages(id,order_id,sender_id,message_type,body,client_message_id)
  VALUES(f.source_id,f.order_id,f.requester,'text','Original order conversation',gen_random_uuid());
  PERFORM set_config('request.jwt.claim.sub',f.requester::text,true);
  SET LOCAL ROLE authenticated;
  INSERT INTO public.support_tickets(id,order_id,requester_id,created_by,subject,message)
  VALUES(f.ticket_id,f.order_id,f.requester,f.requester,'Consolidation test','Please investigate this request');
  PERFORM public.create_participant_risk_report(
    f.report_id,f.order_id,'other','Synthetic incident with all three evidence types',
    ARRAY['r2://media/orders/' || f.order_id::text || '/risk-evidence/' || f.report_id::text || '/photo.webp'],
    11.01,106.01,now(),ARRAY[f.source_id]);
  RESET ROLE;
  IF (SELECT count(*) FROM public.risk_report_evidence WHERE risk_report_id=f.report_id) <> 3 THEN
    RAISE EXCEPTION 'Creation must retain photo, location and message evidence';
  END IF;
  PERFORM set_config('request.jwt.claim.sub',f.staff::text,true);
  SET LOCAL ROLE authenticated;
  PERFORM public.accept_support_ticket(f.ticket_id);
  PERFORM public.accept_risk_report(f.report_id);
  PERFORM public.post_support_ticket_message(f.ticket_id,'Visible ticket reply','public');
  PERFORM public.post_support_ticket_message(f.ticket_id,'Hidden ticket note','internal');
  PERFORM public.post_risk_report_message(f.report_id,'Visible risk reply','public');
  PERFORM public.post_risk_report_message(f.report_id,'Hidden risk reply','internal');
  PERFORM public.add_risk_report_note(f.report_id,'Hidden legacy-note RPC');
  PERFORM public.attach_risk_report_message_evidence(f.report_id,ARRAY[f.source_id]);
  RESET ROLE;
  IF (SELECT count(*) FROM public.risk_report_evidence
    WHERE risk_report_id=f.report_id AND evidence_type='message') <> 1 THEN
    RAISE EXCEPTION 'Repeated attachment must remain idempotent';
  END IF;
  IF (SELECT count(*) FROM public.case_messages
    WHERE risk_report_id=f.report_id AND body='Hidden legacy-note RPC') <> 1 THEN
    RAISE EXCEPTION 'Note adapter must create exactly one internal message';
  END IF;
END;
$fixture$;
DO $access$
DECLARE f consolidation_fixture%ROWTYPE;
BEGIN
  SELECT * INTO f FROM consolidation_fixture;
  PERFORM set_config('request.jwt.claim.sub',f.requester::text,true);
  SET LOCAL ROLE authenticated;
  IF EXISTS (SELECT 1 FROM public.case_messages
    WHERE (ticket_id=f.ticket_id OR risk_report_id=f.report_id) AND visibility='internal') THEN
    RAISE EXCEPTION 'Requester can read staff-only notes';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_messages
    WHERE risk_report_id=f.report_id AND body='Visible risk reply') THEN
    RAISE EXCEPTION 'Reporter cannot read public risk replies';
  END IF;
  IF EXISTS (SELECT 1 FROM public.risk_report_events WHERE risk_report_id=f.report_id
    AND (event_type='note_added' OR details->>'visibility'='internal')) THEN
    RAISE EXCEPTION 'Requester can read internal-note audit events';
  END IF;
  IF (SELECT count(*) FROM public.risk_report_evidence WHERE risk_report_id=f.report_id) <> 3 THEN
    RAISE EXCEPTION 'Reporter cannot read own evidence';
  END IF;
  BEGIN
    PERFORM public.post_risk_report_message(f.report_id,'Unauthorized internal note','internal');
    RAISE EXCEPTION 'Reporter can write an internal risk note';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.case_messages(ticket_id,sender_id,sender_role_snapshot,visibility,body)
    VALUES(f.ticket_id,f.requester,'customer','public','Bypass RPC');
    RAISE EXCEPTION 'Client can bypass message RPC';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.risk_report_evidence(risk_report_id,order_id,evidence_type,storage_path,added_by)
    VALUES(f.report_id,f.order_id,'photo','Unauthorized photo',f.requester);
    RAISE EXCEPTION 'Client can bypass evidence RPC';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RESET ROLE;

  PERFORM set_config('request.jwt.claim.sub',f.outsider::text,true);
  SET LOCAL ROLE authenticated;
  IF EXISTS (SELECT 1 FROM public.case_messages WHERE ticket_id=f.ticket_id OR risk_report_id=f.report_id)
    OR EXISTS (SELECT 1 FROM public.risk_report_evidence WHERE risk_report_id=f.report_id) THEN
    RAISE EXCEPTION 'Outsider can read another participant case';
  END IF;
  BEGIN
    PERFORM public.post_support_ticket_message(f.ticket_id,'Not my ticket','public');
    RAISE EXCEPTION 'Outsider can post to another ticket';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM public.post_risk_report_message(f.report_id,'Not my report','public');
    RAISE EXCEPTION 'Outsider can post to another report';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RESET ROLE;

  PERFORM set_config('request.jwt.claim.sub',f.other_staff::text,true);
  SET LOCAL ROLE authenticated;
  BEGIN
    PERFORM public.add_risk_report_note(f.report_id,'Other assignee note');
    RAISE EXCEPTION 'Unassigned staff can add internal notes';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM public.post_support_ticket_message(f.ticket_id,'Other staff reply','public');
    RAISE EXCEPTION 'Unassigned staff can reply';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RESET ROLE;

  SET LOCAL ROLE anon;
  BEGIN
    PERFORM count(*) FROM public.case_messages;
    RAISE EXCEPTION 'Anonymous role can read messages';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM public.post_risk_report_message(f.report_id,'Anonymous reply','public');
    RAISE EXCEPTION 'Anonymous role can execute risk message RPC';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RESET ROLE;
END;
$access$;
DO $shapes$
DECLARE f consolidation_fixture%ROWTYPE;
BEGIN
  SELECT * INTO f FROM consolidation_fixture;
  PERFORM set_config('request.jwt.claim.sub','',true);
  BEGIN
    INSERT INTO public.case_messages(ticket_id,risk_report_id,sender_id,sender_role_snapshot,visibility,body)
    VALUES(f.ticket_id,f.report_id,f.staff,'support','public','Ambiguous case');
    RAISE EXCEPTION 'A message can belong to both case types';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO public.case_messages(sender_id,sender_role_snapshot,visibility,body)
    VALUES(f.staff,'support','public','Missing case');
    RAISE EXCEPTION 'A message can have no parent case';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO public.risk_report_evidence(risk_report_id,order_id,evidence_type,added_by)
    VALUES(f.report_id,f.order_id,'message',f.staff);
    RAISE EXCEPTION 'Message evidence accepts an empty snapshot';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO public.risk_report_evidence(risk_report_id,order_id,evidence_type,added_by)
    VALUES(f.report_id,f.order_id,'location',f.staff);
    RAISE EXCEPTION 'Location evidence accepts null coordinates';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  DELETE FROM public.order_messages WHERE id=f.source_id;
  IF NOT EXISTS (SELECT 1 FROM public.risk_report_evidence WHERE risk_report_id=f.report_id
    AND evidence_type='message' AND source_message_id IS NULL
    AND body_snapshot='Original order conversation' AND sender_id=f.requester
    AND sent_at_snapshot IS NOT NULL) THEN
    RAISE EXCEPTION 'Message expiry removed or changed the durable snapshot';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime'
    AND schemaname='public' AND tablename='case_messages') THEN
    RAISE EXCEPTION 'Unified messages are missing from Realtime';
  END IF;
  IF to_regclass('public.driver_locations') IS NOT NULL OR to_regclass('public.risk_report_notes') IS NOT NULL
    OR to_regclass('public.risk_report_messages') IS NOT NULL OR to_regclass('public.support_ticket_messages') IS NOT NULL
    OR to_regclass('public.risk_report_attachments') IS NOT NULL OR to_regclass('public.risk_report_message_evidence') IS NOT NULL THEN
    RAISE EXCEPTION 'Legacy tables were not retired';
  END IF;
END;
$shapes$;
ROLLBACK;
