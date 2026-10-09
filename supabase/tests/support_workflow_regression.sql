-- Run after streamline_support_workflow, or together before it is committed.
-- Synthetic fixtures only; all writes and notifications are rolled back.
BEGIN;
DO $test$
DECLARE
  requester uuid := gen_random_uuid();
  staff uuid := gen_random_uuid();
  outsider uuid := gen_random_uuid();
  ticket public.support_tickets%ROWTYPE;
BEGIN
  INSERT INTO public.users(id,email,full_name,role) VALUES
    (requester,requester::text || '@support-test.invalid','Requester','customer'),
    (staff,staff::text || '@support-test.invalid','Support','support'),
    (outsider,outsider::text || '@support-test.invalid','Other requester','driver');

  PERFORM set_config('request.jwt.claim.sub',requester::text,true);
  SET LOCAL ROLE authenticated;
  INSERT INTO public.support_tickets(requester_id,created_by,subject,message)
  VALUES(requester,requester,'Support regression','Please investigate this request')
  RETURNING * INTO ticket;
  RESET ROLE;

  PERFORM set_config('request.jwt.claim.sub',staff::text,true);
  SET LOCAL ROLE authenticated;
  ticket := public.accept_support_ticket(ticket.id);
  IF ticket.status <> 'in_progress' OR ticket.first_response_at IS NOT NULL THEN
    RAISE EXCEPTION 'Acceptance must not count as a public response';
  END IF;
  PERFORM public.post_support_ticket_message(ticket.id,'Internal investigation','internal');
  SELECT * INTO ticket FROM public.support_tickets WHERE id=ticket.id;
  IF ticket.first_response_at IS NOT NULL THEN
    RAISE EXCEPTION 'Internal note must not count as a public response';
  END IF;
  PERFORM public.post_support_ticket_message(ticket.id,'We are checking your request','public');
  SELECT * INTO ticket FROM public.support_tickets WHERE id=ticket.id;
  IF ticket.first_response_at IS NULL THEN RAISE EXCEPTION 'Missing public response time'; END IF;
  BEGIN
    PERFORM public.transition_support_ticket(ticket.id,'resolved','');
    RAISE EXCEPTION 'Expected missing resolution rejection';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  ticket := public.transition_support_ticket(ticket.id,'resolved','Investigation completed');
  RESET ROLE;
  IF NOT EXISTS (SELECT 1 FROM public.notifications n
      WHERE n.user_id=requester AND n.support_ticket_id=ticket.id) THEN
    RAISE EXCEPTION 'Missing notification case link';
  END IF;

  PERFORM set_config('request.jwt.claim.sub',outsider::text,true);
  SET LOCAL ROLE authenticated;
  BEGIN
    PERFORM public.reopen_support_ticket(ticket.id,'Not my case');
    RAISE EXCEPTION 'Expected ownership rejection';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub',requester::text,true);
  SET LOCAL ROLE authenticated;
  ticket := public.reopen_support_ticket(ticket.id,'The issue is still present');
  IF ticket.status <> 'in_progress' OR ticket.resolved_at IS NOT NULL THEN
    RAISE EXCEPTION 'Requester reopen did not restore the active case';
  END IF;
  BEGIN
    PERFORM public.post_support_ticket_message(ticket.id,'Requester internal note','internal');
    RAISE EXCEPTION 'Expected requester internal-note rejection';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  IF NOT EXISTS (SELECT 1 FROM public.case_messages m
      WHERE m.ticket_id=ticket.id AND m.body='Internal investigation') THEN
    NULL; -- The requester must not see internal notes under RLS.
  ELSE
    RAISE EXCEPTION 'Requester can read internal notes';
  END IF;
  RESET ROLE;
END;
$test$;
DO $custody$
DECLARE
  requester uuid := gen_random_uuid();
  staff uuid := gen_random_uuid();
  order_id uuid := gen_random_uuid();
  linked public.support_tickets%ROWTYPE;
  unlinked public.support_tickets%ROWTYPE;
  report public.risk_reports%ROWTYPE;
  custody_state text;
BEGIN
  PERFORM set_config('request.jwt.claim.sub','',true);
  INSERT INTO public.users(id,email,full_name,role) VALUES
    (requester,requester::text || '@support-test.invalid','Custody requester','customer'),
    (staff,staff::text || '@support-test.invalid','Custody support','support');
  INSERT INTO public.orders(id,customer_id,status,pickup_address,pickup_lat,pickup_lng,
      delivery_address,delivery_lat,delivery_lng,tracking_code)
    VALUES(order_id,requester,'cancelled','Test pickup',80,160,
      'Test delivery',80.01,160.01,'GH-SUPPORT-' || order_id::text);

  PERFORM set_config('request.jwt.claim.sub',staff::text,true);
  SET LOCAL ROLE authenticated;
  INSERT INTO public.support_tickets(order_id,requester_id,created_by,subject,message)
    VALUES(order_id,requester,staff,'Linked request','Investigate linked incident') RETURNING * INTO linked;
  INSERT INTO public.support_tickets(order_id,requester_id,created_by,subject,message)
    VALUES(order_id,requester,staff,'Other order request','Investigate order context') RETURNING * INTO unlinked;
  report := public.convert_support_ticket_to_risk(linked.id,'other','medium',
    'Synthetic incident','Synthetic incident for custody regression',NULL);
  BEGIN
    PERFORM public.transition_support_ticket(linked.id,'resolved','Attempt while incident active');
    RAISE EXCEPTION 'Expected active incident rejection';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RESET ROLE;

  FOREACH custody_state IN ARRAY ARRAY['return_required','handoff_required'] LOOP
    UPDATE public.risk_report_interventions SET state=custody_state,instruction='Synthetic custody instruction'
      WHERE risk_report_id=report.id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Missing custody fixture'; END IF;
    SET LOCAL ROLE authenticated;
    BEGIN
      PERFORM public.transition_support_ticket(unlinked.id,'resolved','Attempt while custody pending');
      RAISE EXCEPTION 'Expected order custody rejection for %',custody_state;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
      PERFORM public.transition_risk_report(report.id,'resolved','Attempt while custody pending');
      RAISE EXCEPTION 'Expected risk custody rejection for %',custody_state;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    RESET ROLE;
  END LOOP;
  UPDATE public.risk_report_interventions SET state='released' WHERE risk_report_id=report.id;
  SET LOCAL ROLE authenticated;
  PERFORM public.transition_risk_report(report.id,'resolved','Custody completed');
  PERFORM public.transition_support_ticket(linked.id,'resolved','Incident completed');
  PERFORM public.transition_support_ticket(unlinked.id,'resolved','Order support completed');
  RESET ROLE;
END;
$custody$;
ROLLBACK;
