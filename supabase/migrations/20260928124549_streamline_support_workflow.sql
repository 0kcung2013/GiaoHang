-- Three visible stages reuse the existing status values and case tables.
-- Applied to DATN as 20260928124549 after synthetic rollback regression passed.
BEGIN;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS support_ticket_id uuid REFERENCES public.support_tickets(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS risk_report_id uuid REFERENCES public.risk_reports(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS notifications_support_ticket_idx
  ON public.notifications(support_ticket_id) WHERE support_ticket_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS notifications_risk_report_idx
  ON public.notifications(risk_report_id) WHERE risk_report_id IS NOT NULL;

CREATE OR REPLACE FUNCTION private.enqueue_linked_case_notification(
  p_user_id uuid, p_title text, p_body text, p_type text, p_order_id uuid,
  p_ticket_id uuid DEFAULT NULL, p_report_id uuid DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF p_user_id IS NULL THEN RETURN; END IF;
  INSERT INTO public.notifications(user_id,title,body,type,order_id,support_ticket_id,risk_report_id)
  VALUES(p_user_id,left(trim(p_title),160),left(trim(p_body),500),left(trim(p_type),80),
    p_order_id,p_ticket_id,p_report_id);
END;
$$;
REVOKE ALL ON FUNCTION private.enqueue_linked_case_notification(uuid,text,text,text,uuid,uuid,uuid)
  FROM PUBLIC, anon, authenticated;


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
      status = 'in_progress'
  WHERE id = p_ticket_id
  RETURNING * INTO ticket;

  PERFORM private.enqueue_linked_case_notification(
    ticket.requester_id,
    'CSKH đã tiếp nhận yêu cầu',
    ticket.subject,
    'support_ticket_accepted',
    ticket.order_id, ticket.id
  );
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

  INSERT INTO public.support_ticket_messages(ticket_id,sender_id,sender_role_snapshot,visibility,body)
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

  PERFORM private.enqueue_linked_case_notification(
    ticket.requester_id,
    'Yêu cầu đã chuyển sang xử lý sự cố',
    report.title,
    'support_ticket_converted',
    ticket.order_id, ticket.id
  );
  RETURN report;
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
    PERFORM private.enqueue_linked_case_notification(
      report.reported_by,
      'Báo cáo sự cố đã được tiếp nhận',
      report.title,
      'risk_report_accepted',
      report.order_id, NULL, report.id
    );
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
    PERFORM private.enqueue_linked_case_notification(
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
      report.order_id, NULL, report.id
    );
  END IF;

  IF p_status = 'waiting_admin' THEN
    FOR admin_id IN
      SELECT id FROM public.users
      WHERE role = 'admin'::public.user_role
        AND id <> actor_id
    LOOP
      PERFORM private.enqueue_linked_case_notification(
        admin_id,
        'Báo cáo sự cố cần Admin',
        report.title,
        'risk_report_admin_required',
        report.order_id, NULL, report.id
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
$$;


-- A ticket cannot be finished while a linked investigation or cargo obligation
-- is still open. The existing incident custody guard remains authoritative.
CREATE OR REPLACE FUNCTION private.guard_support_ticket_completion()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE linked_status text;
BEGIN
  IF NEW.status NOT IN ('resolved','closed') OR NEW.status = OLD.status THEN RETURN NEW; END IF;
  IF NEW.risk_report_id IS NOT NULL THEN
    SELECT status INTO linked_status FROM public.risk_reports
      WHERE id = NEW.risk_report_id FOR UPDATE;
    IF linked_status NOT IN ('resolved','dismissed') THEN
      RAISE EXCEPTION 'Hãy xử lý xong sự cố liên quan trước khi kết thúc yêu cầu.' USING ERRCODE='23514';
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM public.risk_report_interventions i
      WHERE i.order_id = NEW.order_id AND i.state IN ('return_required','handoff_required')) THEN
    RAISE EXCEPTION 'Chưa thể kết thúc: hàng đang chờ hoàn hoặc bàn giao.' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER support_ticket_completion_guard BEFORE UPDATE OF status ON public.support_tickets
FOR EACH ROW EXECUTE FUNCTION private.guard_support_ticket_completion();
REVOKE ALL ON FUNCTION private.guard_support_ticket_completion() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.validate_support_ticket_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  requester_role public.user_role;
  assignee_role public.user_role;
  accepting boolean := false;
  taking_over boolean := false;
BEGIN
  SELECT role INTO actor_role
  FROM public.users
  WHERE id = actor_id;

  IF actor_id IS NULL OR actor_role IS NULL THEN
    IF TG_OP = 'UPDATE' AND actor_id IS NULL THEN
      NEW.updated_at := now();
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Authenticated user profile is required'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF actor_role IN (
      'customer'::public.user_role,
      'driver'::public.user_role
    ) THEN
      NEW.requester_id := actor_id;
      NEW.created_by := actor_id;
      NEW.assigned_to := NULL;
      NEW.status := 'open';
      NEW.resolution := NULL;
      NEW.risk_report_id := NULL;
      NEW.first_response_at := NULL;
      NEW.escalated_at := NULL;
    ELSIF actor_role IN (
      'support'::public.user_role,
      'admin'::public.user_role
    ) THEN
      SELECT role INTO requester_role
      FROM public.users
      WHERE id = NEW.requester_id;
      IF requester_role NOT IN (
        'customer'::public.user_role,
        'driver'::public.user_role
      ) THEN
        RAISE EXCEPTION 'Support ticket requester must be Customer or Driver'
          USING ERRCODE = '23514';
      END IF;
      NEW.created_by := actor_id;
      NEW.assigned_to := COALESCE(NEW.assigned_to, actor_id);
      NEW.status := CASE
        WHEN NEW.assigned_to IS NULL THEN 'open'
        ELSE 'in_progress'
      END;
    ELSE
      RAISE EXCEPTION 'Role cannot create support tickets'
        USING ERRCODE = '42501';
    END IF;

    NEW.created_at := now();
    NEW.updated_at := now();
    NEW.response_due_at := COALESCE(
      NEW.response_due_at,
      now() + interval '4 hours'
    );
    RETURN NEW;
  END IF;

  -- A requester may only touch the activity timestamp and, when replying,
  -- move a waiting case back into the active queue.
  IF actor_role IN (
    'customer'::public.user_role,
    'driver'::public.user_role
  ) THEN
    IF OLD.requester_id = actor_id
      AND (
        NEW.status = OLD.status
        OR (
          OLD.status IN ('waiting_customer','resolved','closed')
          AND NEW.status = 'in_progress'
        )
      )
      AND (
        to_jsonb(NEW) - ARRAY['status', 'updated_at', 'resolved_at']
      ) = (
        to_jsonb(OLD) - ARRAY['status', 'updated_at', 'resolved_at']
      )
      AND NEW.resolved_at IS NOT DISTINCT FROM (CASE
        WHEN OLD.status IN ('resolved','closed') AND NEW.status = 'in_progress'
          THEN NULL::timestamptz
        ELSE OLD.resolved_at
      END) THEN
      IF OLD.status IN ('resolved','closed') AND NEW.status = 'in_progress' THEN
        NEW.resolved_at := NULL;
      END IF;
      NEW.updated_at := now();
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Requester can only update activity by replying'
      USING ERRCODE = '42501';
  END IF;

  IF actor_role NOT IN (
    'support'::public.user_role,
    'admin'::public.user_role
  ) THEN
    RAISE EXCEPTION 'Only Support or Admin can update support tickets'
      USING ERRCODE = '42501';
  END IF;

  accepting := OLD.assigned_to IS NULL
    AND NEW.assigned_to = actor_id
    AND OLD.status = 'open'
    AND NEW.status = 'in_progress';

  taking_over := actor_role = 'admin'::public.user_role
    AND OLD.assigned_to IS DISTINCT FROM actor_id
    AND NEW.assigned_to = actor_id
    AND NEW.status = OLD.status;

  IF NOT accepting
    AND NOT taking_over
    AND OLD.assigned_to IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'Only the assigned staff member can update this ticket'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.requester_id IS DISTINCT FROM OLD.requester_id
    OR NEW.order_id IS DISTINCT FROM OLD.order_id
    OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION 'Ticket requester, order and creator cannot be changed'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.assigned_to IS NOT NULL THEN
    SELECT role INTO assignee_role
    FROM public.users
    WHERE id = NEW.assigned_to;
    IF assignee_role NOT IN (
      'support'::public.user_role,
      'admin'::public.user_role
    ) THEN
      RAISE EXCEPTION 'Ticket assignee must be Support or Admin'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status
    AND NOT accepting
    AND NOT taking_over THEN
    IF NOT (
      (OLD.status = 'open' AND NEW.status IN ('in_progress', 'closed'))
      OR (OLD.status = 'in_progress' AND NEW.status IN (
        'waiting_customer', 'waiting_admin', 'resolved', 'closed'
      ))
      OR (OLD.status = 'waiting_customer' AND NEW.status IN (
        'in_progress', 'resolved', 'closed'
      ))
      OR (OLD.status = 'waiting_admin' AND NEW.status IN (
        'in_progress', 'resolved', 'closed'
      ))
      OR (OLD.status = 'resolved' AND NEW.status IN ('closed', 'in_progress'))
      OR (OLD.status = 'closed' AND NEW.status = 'in_progress')
    ) THEN
      RAISE EXCEPTION 'Invalid support ticket status transition: % -> %',
        OLD.status, NEW.status
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF NEW.status IN ('resolved', 'closed') THEN
    IF NEW.resolution IS NULL OR char_length(trim(NEW.resolution)) < 3 THEN
      RAISE EXCEPTION 'Resolution is required when closing a ticket'
        USING ERRCODE = '23514';
    END IF;
    NEW.resolved_at := COALESCE(OLD.resolved_at, now());
  ELSE
    NEW.resolved_at := NULL;
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.reopen_support_ticket(p_ticket_id uuid, p_message text)
RETURNS public.support_tickets LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
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
  INSERT INTO public.support_ticket_messages(ticket_id,sender_id,sender_role_snapshot,visibility,body)
    VALUES(ticket.id,actor_id,actor_role,'public','Mở lại yêu cầu: ' || normalized);
  PERFORM private.enqueue_linked_case_notification(ticket.assigned_to,'Người dùng mở lại yêu cầu',
    normalized,'support_ticket_customer_message',ticket.order_id,ticket.id);
  RETURN ticket;
END;
$$;
REVOKE ALL ON FUNCTION public.reopen_support_ticket(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reopen_support_ticket(uuid,text) TO authenticated;

-- Staff-created conversations must refer to an actual party of the selected order.
CREATE OR REPLACE FUNCTION private.guard_support_ticket_order_context()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.order_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.orders o WHERE o.id=NEW.order_id
      AND NEW.requester_id IN (o.customer_id,o.driver_id)
  ) THEN
    RAISE EXCEPTION 'Người yêu cầu không thuộc đơn hàng đã chọn.' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER zz_support_ticket_order_context BEFORE INSERT ON public.support_tickets
FOR EACH ROW EXECUTE FUNCTION private.guard_support_ticket_order_context();
REVOKE ALL ON FUNCTION private.guard_support_ticket_order_context() FROM PUBLIC, anon, authenticated;

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
$$;
COMMIT;
