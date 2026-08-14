-- Atomic commands for ownership, workflow, conversations and ticket-risk conversion.

CREATE OR REPLACE FUNCTION private.enqueue_case_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text,
  p_order_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.notifications (
    user_id,
    title,
    body,
    type,
    order_id
  ) VALUES (
    p_user_id,
    left(trim(p_title), 160),
    left(trim(p_body), 500),
    left(trim(p_type), 80),
    p_order_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION private.seed_support_ticket_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  creator_role public.user_role;
BEGIN
  SELECT role INTO creator_role
  FROM public.users
  WHERE id = NEW.created_by;

  INSERT INTO public.support_ticket_messages (
    ticket_id,
    sender_id,
    sender_role_snapshot,
    visibility,
    body,
    created_at
  ) VALUES (
    NEW.id,
    NEW.created_by,
    CASE
      WHEN creator_role = 'admin'::public.user_role THEN 'admin'
      WHEN creator_role = 'support'::public.user_role THEN 'support'
      ELSE 'customer'
    END,
    'public',
    NEW.message,
    NEW.created_at
  );

  IF creator_role IN (
    'support'::public.user_role,
    'admin'::public.user_role
  ) THEN
    PERFORM private.enqueue_case_notification(
      NEW.customer_id,
      'Yêu cầu hỗ trợ mới',
      NEW.subject,
      'support_ticket_created',
      NEW.order_id
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS support_tickets_seed_message
  ON public.support_tickets;
CREATE TRIGGER support_tickets_seed_message
AFTER INSERT ON public.support_tickets
FOR EACH ROW EXECUTE FUNCTION private.seed_support_ticket_message();

CREATE OR REPLACE FUNCTION private.enforce_risk_intervention_owner()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  report_assignee uuid;
BEGIN
  -- Scheduled internal escalation has no end-user JWT.
  IF actor_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT role INTO actor_role
  FROM public.users
  WHERE id = actor_id;

  SELECT assigned_to INTO report_assignee
  FROM public.risk_reports
  WHERE id = NEW.risk_report_id;

  IF actor_role IN (
    'support'::public.user_role,
    'admin'::public.user_role
  ) THEN
    IF report_assignee IS DISTINCT FROM actor_id THEN
      RAISE EXCEPTION 'Only the assigned staff member can change intervention'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  IF actor_role = 'driver'::public.user_role
    AND OLD.driver_id = actor_id
    AND OLD.state IN ('return_required', 'handoff_required')
    AND NEW.state = 'released' THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'User cannot change this intervention'
    USING ERRCODE = '42501';
END;
$$;

DROP TRIGGER IF EXISTS risk_interventions_enforce_owner
  ON public.risk_report_interventions;
CREATE TRIGGER risk_interventions_enforce_owner
BEFORE UPDATE ON public.risk_report_interventions
FOR EACH ROW EXECUTE FUNCTION private.enforce_risk_intervention_owner();

CREATE OR REPLACE FUNCTION public.accept_support_ticket(p_ticket_id uuid)
RETURNS public.support_tickets
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := private.require_risk_staff();
  ticket public.support_tickets%ROWTYPE;
BEGIN
  SELECT * INTO ticket
  FROM public.support_tickets
  WHERE id = p_ticket_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Support ticket not found' USING ERRCODE = 'P0002';
  END IF;
  IF ticket.status <> 'open' THEN
    RAISE EXCEPTION 'Support ticket is not open' USING ERRCODE = '23514';
  END IF;
  IF ticket.assigned_to IS NOT NULL
    AND ticket.assigned_to <> actor_id THEN
    RAISE EXCEPTION 'Support ticket is assigned to another staff member'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.support_tickets
  SET assigned_to = actor_id,
      status = 'in_progress',
      first_response_at = COALESCE(first_response_at, now())
  WHERE id = p_ticket_id
  RETURNING * INTO ticket;

  PERFORM private.enqueue_case_notification(
    ticket.customer_id,
    'CSKH đã tiếp nhận yêu cầu',
    ticket.subject,
    'support_ticket_accepted',
    ticket.order_id
  );
  RETURN ticket;
END;
$$;

CREATE OR REPLACE FUNCTION public.takeover_support_ticket(p_ticket_id uuid)
RETURNS public.support_tickets
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  ticket public.support_tickets%ROWTYPE;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = actor_id AND role = 'admin'::public.user_role
  ) THEN
    RAISE EXCEPTION 'Only Admin can take over a support ticket'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.support_tickets
  SET assigned_to = actor_id
  WHERE id = p_ticket_id
    AND status NOT IN ('resolved', 'closed')
  RETURNING * INTO ticket;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active support ticket not found'
      USING ERRCODE = 'P0002';
  END IF;
  RETURN ticket;
END;
$$;

CREATE OR REPLACE FUNCTION public.transition_support_ticket(
  p_ticket_id uuid,
  p_status text,
  p_resolution text DEFAULT NULL
)
RETURNS public.support_tickets
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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

  PERFORM private.enqueue_case_notification(
    ticket.customer_id,
    'Yêu cầu hỗ trợ đã cập nhật',
    CASE p_status
      WHEN 'waiting_customer' THEN 'CSKH đang chờ bạn phản hồi.'
      WHEN 'waiting_admin' THEN 'Yêu cầu đã được chuyển Admin xem xét.'
      WHEN 'resolved' THEN COALESCE(ticket.resolution, 'Yêu cầu đã được xử lý.')
      WHEN 'closed' THEN COALESCE(ticket.resolution, 'Yêu cầu đã được đóng.')
      ELSE 'CSKH đang tiếp tục xử lý yêu cầu.'
    END,
    'support_ticket_status',
    ticket.order_id
  );

  IF p_status = 'waiting_admin' THEN
    FOR admin_id IN
      SELECT id FROM public.users
      WHERE role = 'admin'::public.user_role
    LOOP
      PERFORM private.enqueue_case_notification(
        admin_id,
        'Yêu cầu hỗ trợ cần Admin',
        ticket.subject,
        'support_ticket_admin_required',
        ticket.order_id
      );
    END LOOP;
  END IF;
  RETURN ticket;
END;
$$;

CREATE OR REPLACE FUNCTION public.post_support_ticket_message(
  p_ticket_id uuid,
  p_body text,
  p_visibility text DEFAULT 'public'
)
RETURNS public.support_ticket_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  ticket public.support_tickets%ROWTYPE;
  created_message public.support_ticket_messages%ROWTYPE;
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

  IF actor_role = 'customer'::public.user_role THEN
    IF ticket.customer_id <> actor_id OR p_visibility <> 'public' THEN
      RAISE EXCEPTION 'Customer cannot post this message'
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

  INSERT INTO public.support_ticket_messages (
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
  ) AND p_visibility = 'public' THEN
    UPDATE public.support_tickets
    SET first_response_at = COALESCE(first_response_at, now())
    WHERE id = ticket.id
    RETURNING * INTO ticket;

    PERFORM private.enqueue_case_notification(
      ticket.customer_id,
      'CSKH vừa phản hồi',
      normalized_body,
      'support_ticket_message',
      ticket.order_id
    );
  ELSIF actor_role = 'customer'::public.user_role
    AND ticket.assigned_to IS NOT NULL THEN
    IF ticket.status = 'waiting_customer' THEN
      UPDATE public.support_tickets
      SET status = 'in_progress'
      WHERE id = ticket.id
      RETURNING * INTO ticket;
    END IF;

    PERFORM private.enqueue_case_notification(
      ticket.assigned_to,
      'Khách hàng vừa phản hồi',
      normalized_body,
      'support_ticket_customer_message',
      ticket.order_id
    );
  END IF;

  RETURN created_message;
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_risk_report(p_report_id uuid)
RETURNS public.risk_reports
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := private.require_risk_staff();
  report public.risk_reports%ROWTYPE;
BEGIN
  SELECT * INTO report
  FROM public.risk_reports
  WHERE id = p_report_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Risk report not found' USING ERRCODE = 'P0002';
  END IF;
  IF report.status <> 'open' THEN
    RAISE EXCEPTION 'Risk report is not open' USING ERRCODE = '23514';
  END IF;
  IF report.assigned_to IS NOT NULL
    AND report.assigned_to <> actor_id THEN
    RAISE EXCEPTION 'Risk report is assigned to another staff member'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.risk_reports
  SET assigned_to = actor_id,
      status = 'investigating',
      first_response_at = COALESCE(first_response_at, now()),
      updated_by = actor_id
  WHERE id = p_report_id
  RETURNING * INTO report;

  IF report.reported_by <> actor_id THEN
    PERFORM private.enqueue_case_notification(
      report.reported_by,
      'Báo cáo sự cố đã được tiếp nhận',
      report.title,
      'risk_report_accepted',
      report.order_id
    );
  END IF;
  RETURN report;
END;
$$;

CREATE OR REPLACE FUNCTION public.takeover_risk_report(p_report_id uuid)
RETURNS public.risk_reports
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  report public.risk_reports%ROWTYPE;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = actor_id AND role = 'admin'::public.user_role
  ) THEN
    RAISE EXCEPTION 'Only Admin can take over a risk report'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.risk_reports
  SET assigned_to = actor_id,
      updated_by = actor_id
  WHERE id = p_report_id
    AND status NOT IN ('resolved', 'dismissed')
  RETURNING * INTO report;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active risk report not found'
      USING ERRCODE = 'P0002';
  END IF;
  RETURN report;
END;
$$;

CREATE OR REPLACE FUNCTION public.transition_risk_report(
  p_report_id uuid,
  p_status text,
  p_resolution text DEFAULT NULL
)
RETURNS public.risk_reports
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := private.require_risk_staff();
  report public.risk_reports%ROWTYPE;
  normalized_resolution text := NULLIF(trim(p_resolution), '');
  admin_id uuid;
BEGIN
  SELECT * INTO report
  FROM public.risk_reports
  WHERE id = p_report_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Risk report not found' USING ERRCODE = 'P0002';
  END IF;
  IF report.assigned_to IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'Only the assigned staff member can transition this report'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.risk_reports
  SET status = p_status,
      resolution = CASE
        WHEN p_status IN ('resolved', 'dismissed') THEN normalized_resolution
        ELSE resolution
      END,
      updated_by = actor_id
  WHERE id = p_report_id
  RETURNING * INTO report;

  IF report.reported_by <> actor_id THEN
    PERFORM private.enqueue_case_notification(
      report.reported_by,
      'Báo cáo sự cố đã cập nhật',
      CASE p_status
        WHEN 'waiting_customer' THEN 'CSKH đang chờ bạn phản hồi.'
        WHEN 'waiting_admin' THEN 'Báo cáo đã được chuyển Admin xem xét.'
        WHEN 'resolved' THEN COALESCE(report.resolution, 'Sự cố đã được xử lý.')
        WHEN 'dismissed' THEN COALESCE(report.resolution, 'Báo cáo đã được kết thúc.')
        ELSE 'CSKH đang tiếp tục xác minh báo cáo.'
      END,
      'risk_report_status',
      report.order_id
    );
  END IF;

  IF p_status = 'waiting_admin' THEN
    FOR admin_id IN
      SELECT id FROM public.users
      WHERE role = 'admin'::public.user_role
        AND id <> actor_id
    LOOP
      PERFORM private.enqueue_case_notification(
        admin_id,
        'Báo cáo sự cố cần Admin',
        report.title,
        'risk_report_admin_required',
        report.order_id
      );
    END LOOP;
  END IF;
  RETURN report;
END;
$$;

CREATE OR REPLACE FUNCTION public.post_risk_report_message(
  p_report_id uuid,
  p_body text,
  p_visibility text DEFAULT 'public'
)
RETURNS public.risk_report_messages
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  report public.risk_reports%ROWTYPE;
  created_message public.risk_report_messages%ROWTYPE;
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

  INSERT INTO public.risk_report_messages (
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
      PERFORM private.enqueue_case_notification(
        report.reported_by,
        'CSKH vừa phản hồi báo cáo sự cố',
        normalized_body,
        'risk_report_message',
        report.order_id
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

    PERFORM private.enqueue_case_notification(
      report.assigned_to,
      'Người báo cáo vừa phản hồi',
      normalized_body,
      'risk_report_participant_message',
      report.order_id
    );
  END IF;
  RETURN created_message;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_risk_report_note(
  p_report_id uuid,
  p_body text
)
RETURNS public.risk_report_notes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := private.require_risk_staff();
  report public.risk_reports%ROWTYPE;
  created_note public.risk_report_notes%ROWTYPE;
  normalized_body text := trim(COALESCE(p_body, ''));
BEGIN
  IF char_length(normalized_body) NOT BETWEEN 3 AND 4000 THEN
    RAISE EXCEPTION 'Note must contain between 3 and 4000 characters'
      USING ERRCODE = '22023';
  END IF;
  SELECT * INTO report
  FROM public.risk_reports
  WHERE id = p_report_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Risk report not found' USING ERRCODE = 'P0002';
  END IF;
  IF report.assigned_to IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'Only the assigned staff member can add internal notes'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.risk_report_notes(risk_report_id, author_id, body)
  VALUES (p_report_id, actor_id, normalized_body)
  RETURNING * INTO created_note;

  INSERT INTO public.risk_report_events(
    risk_report_id,
    actor_id,
    event_type,
    from_status,
    to_status,
    details
  ) VALUES (
    p_report_id,
    actor_id,
    'note_added',
    report.status,
    report.status,
    jsonb_build_object('note_id', created_note.id)
  );
  RETURN created_note;
END;
$$;

CREATE OR REPLACE FUNCTION public.convert_support_ticket_to_risk(
  p_ticket_id uuid,
  p_category text,
  p_severity text,
  p_title text,
  p_description text,
  p_component text DEFAULT NULL
)
RETURNS public.risk_reports
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := private.require_risk_staff();
  ticket public.support_tickets%ROWTYPE;
  report public.risk_reports%ROWTYPE;
  normalized_title text := trim(COALESCE(p_title, ''));
  normalized_description text := trim(COALESCE(p_description, ''));
  normalized_component text := NULLIF(trim(p_component), '');
BEGIN
  SELECT * INTO ticket
  FROM public.support_tickets
  WHERE id = p_ticket_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Support ticket not found' USING ERRCODE = 'P0002';
  END IF;
  IF ticket.assigned_to IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'Only the assigned staff member can convert this ticket'
      USING ERRCODE = '42501';
  END IF;
  IF ticket.status IN ('resolved', 'closed') THEN
    RAISE EXCEPTION 'Closed ticket cannot be converted'
      USING ERRCODE = '23514';
  END IF;
  IF ticket.risk_report_id IS NOT NULL THEN
    SELECT * INTO report
    FROM public.risk_reports
    WHERE id = ticket.risk_report_id;
    RETURN report;
  END IF;

  IF ticket.order_id IS NOT NULL THEN
    SELECT * INTO report
    FROM public.risk_reports AS existing
    WHERE existing.order_id = ticket.order_id
      AND existing.category = p_category
      AND existing.status NOT IN ('resolved', 'dismissed')
    ORDER BY existing.updated_at DESC
    LIMIT 1;
  ELSE
    SELECT * INTO report
    FROM public.risk_reports AS existing
    WHERE existing.scope = 'system'
      AND existing.category = p_category
      AND COALESCE(existing.component, 'general') =
        COALESCE(normalized_component, 'general')
      AND existing.status NOT IN ('resolved', 'dismissed')
    ORDER BY existing.updated_at DESC
    LIMIT 1;
  END IF;

  IF report.id IS NULL THEN
    INSERT INTO public.risk_reports (
      order_id,
      reported_by,
      assigned_to,
      updated_by,
      source,
      scope,
      component,
      category,
      severity,
      status,
      title,
      description,
      reporter_role_snapshot,
      first_response_at,
      triage_due_at,
      response_due_at
    ) VALUES (
      ticket.order_id,
      actor_id,
      actor_id,
      actor_id,
      'support_ticket',
      CASE WHEN ticket.order_id IS NULL THEN 'system' ELSE 'order' END,
      CASE WHEN ticket.order_id IS NULL THEN normalized_component ELSE NULL END,
      p_category,
      p_severity,
      'investigating',
      normalized_title,
      normalized_description,
      (SELECT role::text FROM public.users WHERE id = actor_id),
      now(),
      now() + interval '10 minutes',
      now() + interval '10 minutes'
    )
    RETURNING * INTO report;
  END IF;

  UPDATE public.support_tickets
  SET risk_report_id = report.id,
      status = CASE
        WHEN p_severity = 'critical' THEN 'waiting_admin'
        ELSE 'in_progress'
      END
  WHERE id = ticket.id
  RETURNING * INTO ticket;

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
    'ticket_linked',
    report.status,
    report.status,
    jsonb_build_object('support_ticket_id', ticket.id)
  );

  PERFORM private.enqueue_case_notification(
    ticket.customer_id,
    'Yêu cầu đã chuyển sang xử lý sự cố',
    report.title,
    'support_ticket_converted',
    ticket.order_id
  );
  RETURN report;
END;
$$;

REVOKE ALL ON FUNCTION private.enqueue_case_notification(
  uuid, text, text, text, uuid
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.seed_support_ticket_message()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.enforce_risk_intervention_owner()
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.accept_support_ticket(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.takeover_support_ticket(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.transition_support_ticket(uuid, text, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.post_support_ticket_message(uuid, text, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.accept_risk_report(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.takeover_risk_report(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.transition_risk_report(uuid, text, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.post_risk_report_message(uuid, text, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.add_risk_report_note(uuid, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.convert_support_ticket_to_risk(
  uuid, text, text, text, text, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.accept_support_ticket(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.takeover_support_ticket(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.transition_support_ticket(uuid, text, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_support_ticket_message(uuid, text, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_risk_report(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.takeover_risk_report(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.transition_risk_report(uuid, text, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_risk_report_message(uuid, text, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_risk_report_note(uuid, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.convert_support_ticket_to_risk(
  uuid, text, text, text, text, text
) TO authenticated;
