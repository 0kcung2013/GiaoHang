-- Reuse the existing support case tables for one-to-one requester <-> CSKH
-- conversations. A requester can be either a customer or a driver.

ALTER TABLE public.support_tickets
  RENAME COLUMN customer_id TO requester_id;

ALTER TABLE public.support_tickets
  RENAME CONSTRAINT support_tickets_customer_id_fkey
  TO support_tickets_requester_id_fkey;

ALTER INDEX IF EXISTS public.support_tickets_customer_idx
  RENAME TO support_tickets_requester_idx;

ALTER TABLE public.support_ticket_messages
  DROP CONSTRAINT IF EXISTS support_ticket_messages_sender_role_snapshot_check;

ALTER TABLE public.support_ticket_messages
  ADD CONSTRAINT support_ticket_messages_sender_role_snapshot_check
  CHECK (sender_role_snapshot IN ('customer', 'driver', 'support', 'admin'));

DROP POLICY IF EXISTS support_tickets_case_select
  ON public.support_tickets;
DROP POLICY IF EXISTS support_tickets_case_insert
  ON public.support_tickets;
DROP POLICY IF EXISTS support_ticket_messages_case_select
  ON public.support_ticket_messages;

CREATE POLICY support_tickets_requester_or_staff_select
ON public.support_tickets
FOR SELECT
TO authenticated
USING (
  requester_id = (SELECT auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.users AS actor
    WHERE actor.id = (SELECT auth.uid())
      AND actor.role IN (
        'support'::public.user_role,
        'admin'::public.user_role
      )
  )
);

CREATE POLICY support_tickets_requester_or_staff_insert
ON public.support_tickets
FOR INSERT
TO authenticated
WITH CHECK (
  (
    requester_id = (SELECT auth.uid())
    AND created_by = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.users AS requester
      WHERE requester.id = (SELECT auth.uid())
        AND requester.role IN (
          'customer'::public.user_role,
          'driver'::public.user_role
        )
    )
  )
  OR (
    created_by = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.users AS actor
      WHERE actor.id = (SELECT auth.uid())
        AND actor.role IN (
          'support'::public.user_role,
          'admin'::public.user_role
        )
    )
  )
);

CREATE POLICY support_ticket_messages_requester_or_staff_select
ON public.support_ticket_messages
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
  OR (
    visibility = 'public'
    AND EXISTS (
      SELECT 1
      FROM public.support_tickets AS ticket
      WHERE ticket.id = support_ticket_messages.ticket_id
        AND ticket.requester_id = (SELECT auth.uid())
    )
  )
);

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
    PERFORM private.enqueue_case_notification(
      NEW.requester_id,
      'Yêu cầu hỗ trợ mới',
      NEW.subject,
      'support_ticket_created',
      NEW.order_id
    );
  END IF;
  RETURN NEW;
END;
$$;

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
          OLD.status = 'waiting_customer'
          AND NEW.status = 'in_progress'
        )
      )
      AND (
        to_jsonb(NEW) - ARRAY['status', 'updated_at']
      ) = (
        to_jsonb(OLD) - ARRAY['status', 'updated_at']
      ) THEN
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
    ticket.requester_id,
    'CSKH đã tiếp nhận yêu cầu',
    ticket.subject,
    'support_ticket_accepted',
    ticket.order_id
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

  PERFORM private.enqueue_case_notification(
    ticket.requester_id,
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
      PERFORM private.enqueue_case_notification(
        ticket.requester_id,
        'CSKH vừa phản hồi',
        normalized_body,
        'support_ticket_message',
        ticket.order_id
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
      PERFORM private.enqueue_case_notification(
        ticket.assigned_to,
        'Người dùng vừa phản hồi',
        normalized_body,
        'support_ticket_customer_message',
        ticket.order_id
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

  PERFORM private.enqueue_case_notification(
    ticket.requester_id,
    'Yêu cầu đã chuyển sang xử lý sự cố',
    report.title,
    'support_ticket_converted',
    ticket.order_id
  );
  RETURN report;
END;
$$;

REVOKE ALL ON FUNCTION private.seed_support_ticket_message()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.validate_support_ticket_write()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.accept_support_ticket(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.transition_support_ticket(uuid, text, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.post_support_ticket_message(uuid, text, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.convert_support_ticket_to_risk(
  uuid, text, text, text, text, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.accept_support_ticket(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.transition_support_ticket(uuid, text, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_support_ticket_message(uuid, text, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.convert_support_ticket_to_risk(
  uuid, text, text, text, text, text
) TO authenticated;

COMMENT ON COLUMN public.support_tickets.requester_id IS
  'Customer or driver who owns this one-to-one support conversation.';
COMMENT ON TABLE public.support_ticket_messages IS
  'Public requester conversation and internal staff notes for a support ticket.';
