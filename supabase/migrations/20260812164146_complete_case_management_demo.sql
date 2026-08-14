-- Case management schema and authorization foundation.
-- Adds professional workflow states, public conversations, ticket-risk links,
-- and support for system incidents that are not tied to an order.

ALTER TABLE public.support_tickets
  DROP CONSTRAINT IF EXISTS support_tickets_status_check;

ALTER TABLE public.support_tickets
  ADD CONSTRAINT support_tickets_status_check
  CHECK (status IN (
    'open',
    'in_progress',
    'waiting_customer',
    'waiting_admin',
    'resolved',
    'closed'
  ));

ALTER TABLE public.support_tickets
  ADD COLUMN IF NOT EXISTS risk_report_id uuid,
  ADD COLUMN IF NOT EXISTS first_response_at timestamptz,
  ADD COLUMN IF NOT EXISTS response_due_at timestamptz,
  ADD COLUMN IF NOT EXISTS escalated_at timestamptz;

UPDATE public.support_tickets
SET response_due_at = COALESCE(response_due_at, created_at + interval '4 hours')
WHERE response_due_at IS NULL;

ALTER TABLE public.support_tickets
  ALTER COLUMN response_due_at SET DEFAULT (now() + interval '4 hours');

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'support_tickets_risk_report_id_fkey'
      AND conrelid = 'public.support_tickets'::regclass
  ) THEN
    ALTER TABLE public.support_tickets
      ADD CONSTRAINT support_tickets_risk_report_id_fkey
      FOREIGN KEY (risk_report_id)
      REFERENCES public.risk_reports(id)
      ON DELETE SET NULL;
  END IF;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS support_tickets_risk_report_uidx
  ON public.support_tickets(risk_report_id)
  WHERE risk_report_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS support_tickets_active_queue_idx
  ON public.support_tickets(status, priority, response_due_at, updated_at DESC)
  WHERE status NOT IN ('resolved', 'closed');

CREATE INDEX IF NOT EXISTS support_tickets_created_by_idx
  ON public.support_tickets(created_by);

ALTER TABLE public.risk_reports
  ALTER COLUMN order_id DROP NOT NULL;

ALTER TABLE public.risk_reports
  ADD COLUMN IF NOT EXISTS scope text NOT NULL DEFAULT 'order',
  ADD COLUMN IF NOT EXISTS component text,
  ADD COLUMN IF NOT EXISTS first_response_at timestamptz,
  ADD COLUMN IF NOT EXISTS response_due_at timestamptz;

ALTER TABLE public.risk_reports
  DISABLE TRIGGER risk_reports_validate_write;
ALTER TABLE public.risk_reports
  DISABLE TRIGGER risk_reports_record_event;

UPDATE public.risk_reports
SET scope = CASE WHEN order_id IS NULL THEN 'system' ELSE 'order' END,
    response_due_at = COALESCE(
      response_due_at,
      triage_due_at,
      created_at + interval '10 minutes'
    );

ALTER TABLE public.risk_reports
  ENABLE TRIGGER risk_reports_record_event;
ALTER TABLE public.risk_reports
  ENABLE TRIGGER risk_reports_validate_write;

ALTER TABLE public.risk_reports
  ALTER COLUMN response_due_at SET DEFAULT (now() + interval '10 minutes');

ALTER TABLE public.risk_reports
  DROP CONSTRAINT IF EXISTS risk_reports_status_check,
  DROP CONSTRAINT IF EXISTS risk_reports_source_check;

ALTER TABLE public.risk_reports
  ADD CONSTRAINT risk_reports_status_check
  CHECK (status IN (
    'open',
    'investigating',
    'action_required',
    'waiting_customer',
    'waiting_admin',
    'resolved',
    'dismissed'
  )),
  ADD CONSTRAINT risk_reports_source_check
  CHECK (source IN ('manual', 'system', 'support_ticket'));

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'risk_reports_scope_check'
      AND conrelid = 'public.risk_reports'::regclass
  ) THEN
    ALTER TABLE public.risk_reports
      ADD CONSTRAINT risk_reports_scope_check
      CHECK (
        (scope = 'order' AND order_id IS NOT NULL)
        OR
        (scope = 'system' AND order_id IS NULL)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'risk_reports_component_check'
      AND conrelid = 'public.risk_reports'::regclass
  ) THEN
    ALTER TABLE public.risk_reports
      ADD CONSTRAINT risk_reports_component_check
      CHECK (
        component IS NULL
        OR char_length(trim(component)) BETWEEN 2 AND 80
      );
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS risk_reports_active_scope_queue_idx
  ON public.risk_reports(scope, status, severity, response_due_at, updated_at DESC)
  WHERE status NOT IN ('resolved', 'dismissed');

CREATE INDEX IF NOT EXISTS risk_reports_reported_by_idx
  ON public.risk_reports(reported_by);

CREATE INDEX IF NOT EXISTS risk_reports_updated_by_idx
  ON public.risk_reports(updated_by);

CREATE UNIQUE INDEX IF NOT EXISTS risk_reports_active_system_component_uidx
  ON public.risk_reports(category, COALESCE(component, 'general'))
  WHERE scope = 'system'
    AND status NOT IN ('resolved', 'dismissed');

ALTER TABLE public.risk_report_events
  DROP CONSTRAINT IF EXISTS risk_report_events_event_type_check;

ALTER TABLE public.risk_report_events
  ADD CONSTRAINT risk_report_events_event_type_check
  CHECK (event_type IN (
    'created',
    'updated',
    'assigned',
    'status_changed',
    'intervention_changed',
    'note_added',
    'message_added',
    'ticket_linked'
  ));

CREATE INDEX IF NOT EXISTS risk_report_events_actor_idx
  ON public.risk_report_events(actor_id)
  WHERE actor_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS risk_report_interventions_decided_by_idx
  ON public.risk_report_interventions(decided_by)
  WHERE decided_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS risk_report_interventions_driver_idx
  ON public.risk_report_interventions(driver_id)
  WHERE driver_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS risk_report_notes_author_idx
  ON public.risk_report_notes(author_id);

CREATE TABLE public.support_ticket_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL
    REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL
    REFERENCES public.users(id) ON DELETE RESTRICT,
  sender_role_snapshot text NOT NULL
    CHECK (sender_role_snapshot IN ('customer', 'support', 'admin')),
  visibility text NOT NULL DEFAULT 'public'
    CHECK (visibility IN ('public', 'internal')),
  body text NOT NULL
    CHECK (char_length(trim(body)) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX support_ticket_messages_ticket_idx
  ON public.support_ticket_messages(ticket_id, created_at, id);
CREATE INDEX support_ticket_messages_sender_idx
  ON public.support_ticket_messages(sender_id);

CREATE TABLE public.risk_report_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  risk_report_id uuid NOT NULL
    REFERENCES public.risk_reports(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL
    REFERENCES public.users(id) ON DELETE RESTRICT,
  sender_role_snapshot text NOT NULL
    CHECK (sender_role_snapshot IN (
      'customer', 'driver', 'support', 'admin'
    )),
  visibility text NOT NULL DEFAULT 'public'
    CHECK (visibility IN ('public', 'internal')),
  body text NOT NULL
    CHECK (char_length(trim(body)) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX risk_report_messages_report_idx
  ON public.risk_report_messages(risk_report_id, created_at, id);
CREATE INDEX risk_report_messages_sender_idx
  ON public.risk_report_messages(sender_id);

INSERT INTO public.support_ticket_messages (
  ticket_id,
  sender_id,
  sender_role_snapshot,
  visibility,
  body,
  created_at
)
SELECT
  ticket.id,
  ticket.created_by,
  CASE
    WHEN creator.role = 'admin'::public.user_role THEN 'admin'
    WHEN creator.role = 'support'::public.user_role THEN 'support'
    ELSE 'customer'
  END,
  'public',
  ticket.message,
  ticket.created_at
FROM public.support_tickets AS ticket
JOIN public.users AS creator ON creator.id = ticket.created_by
WHERE NOT EXISTS (
  SELECT 1
  FROM public.support_ticket_messages AS existing
  WHERE existing.ticket_id = ticket.id
);

ALTER TABLE public.support_ticket_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_report_messages ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.support_ticket_messages FROM anon, authenticated;
REVOKE ALL ON public.risk_report_messages FROM anon, authenticated;
GRANT SELECT ON public.support_ticket_messages TO authenticated;
GRANT SELECT ON public.risk_report_messages TO authenticated;

CREATE POLICY support_ticket_messages_case_select
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
        AND ticket.customer_id = (SELECT auth.uid())
    )
  )
);

CREATE POLICY risk_report_messages_case_select
ON public.risk_report_messages
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
      FROM public.risk_reports AS report
      WHERE report.id = risk_report_messages.risk_report_id
        AND report.reported_by = (SELECT auth.uid())
    )
  )
);

DROP POLICY IF EXISTS support_tickets_customer_select
  ON public.support_tickets;
DROP POLICY IF EXISTS support_tickets_staff_select
  ON public.support_tickets;
DROP POLICY IF EXISTS support_tickets_customer_insert
  ON public.support_tickets;
DROP POLICY IF EXISTS support_tickets_staff_insert
  ON public.support_tickets;
DROP POLICY IF EXISTS support_tickets_staff_update
  ON public.support_tickets;

CREATE POLICY support_tickets_case_select
ON public.support_tickets
FOR SELECT
TO authenticated
USING (
  customer_id = (SELECT auth.uid())
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

CREATE POLICY support_tickets_case_insert
ON public.support_tickets
FOR INSERT
TO authenticated
WITH CHECK (
  (
    customer_id = (SELECT auth.uid())
    AND created_by = (SELECT auth.uid())
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

DROP POLICY IF EXISTS risk_reports_participant_select
  ON public.risk_reports;
DROP POLICY IF EXISTS risk_reports_staff_select
  ON public.risk_reports;
DROP POLICY IF EXISTS risk_reports_staff_update
  ON public.risk_reports;

CREATE POLICY risk_reports_case_select
ON public.risk_reports
FOR SELECT
TO authenticated
USING (
  reported_by = (SELECT auth.uid())
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

DROP POLICY IF EXISTS risk_events_participant_select
  ON public.risk_report_events;
DROP POLICY IF EXISTS risk_report_events_staff_select
  ON public.risk_report_events;

CREATE POLICY risk_report_events_case_select
ON public.risk_report_events
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.risk_reports AS report
    WHERE report.id = risk_report_events.risk_report_id
      AND (
        report.reported_by = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1
          FROM public.users AS actor
          WHERE actor.id = (SELECT auth.uid())
            AND actor.role IN (
              'support'::public.user_role,
              'admin'::public.user_role
            )
        )
      )
  )
  AND (
    event_type <> 'note_added'
    OR EXISTS (
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

DROP POLICY IF EXISTS risk_interventions_participant_select
  ON public.risk_report_interventions;
DROP POLICY IF EXISTS risk_interventions_staff_select
  ON public.risk_report_interventions;

CREATE POLICY risk_interventions_case_select
ON public.risk_report_interventions
FOR SELECT
TO authenticated
USING (
  driver_id = (SELECT auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.orders AS participant_order
    WHERE participant_order.id = risk_report_interventions.order_id
      AND participant_order.customer_id = (SELECT auth.uid())
  )
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

REVOKE UPDATE ON public.support_tickets FROM authenticated;
REVOKE UPDATE ON public.risk_reports FROM authenticated;

CREATE OR REPLACE FUNCTION private.validate_support_ticket_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  customer_role public.user_role;
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
    IF actor_role = 'customer'::public.user_role THEN
      NEW.customer_id := actor_id;
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
      SELECT role INTO customer_role
      FROM public.users
      WHERE id = NEW.customer_id;
      IF customer_role <> 'customer'::public.user_role THEN
        RAISE EXCEPTION 'Support ticket customer must have Customer role'
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

  -- A customer reply reopens a waiting ticket. Direct table UPDATE remains
  -- revoked, so this narrow transition is only reachable through the message
  -- command that already validates the participant and message visibility.
  IF actor_role = 'customer'::public.user_role THEN
    IF OLD.customer_id = actor_id
      AND OLD.status = 'waiting_customer'
      AND NEW.status = 'in_progress'
      AND (
        to_jsonb(NEW) - ARRAY['status', 'updated_at']
      ) = (
        to_jsonb(OLD) - ARRAY['status', 'updated_at']
      ) THEN
      NEW.updated_at := now();
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Customer can only reopen a waiting ticket by replying'
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

  IF NEW.customer_id IS DISTINCT FROM OLD.customer_id
    OR NEW.order_id IS DISTINCT FROM OLD.order_id
    OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION 'Ticket customer, order and creator cannot be changed'
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

DROP TRIGGER IF EXISTS support_tickets_validate_write
  ON public.support_tickets;
CREATE TRIGGER support_tickets_validate_write
BEFORE INSERT OR UPDATE ON public.support_tickets
FOR EACH ROW EXECUTE FUNCTION private.validate_support_ticket_write();

CREATE OR REPLACE FUNCTION public.set_support_ticket_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = 'public', 'pg_temp'
AS $$
BEGIN
  NEW.updated_at = now();
  IF NEW.status IN ('resolved', 'closed')
    AND OLD.status NOT IN ('resolved', 'closed') THEN
    NEW.resolved_at = COALESCE(NEW.resolved_at, now());
  ELSIF NEW.status NOT IN ('resolved', 'closed') THEN
    NEW.resolved_at = NULL;
  END IF;
  RETURN NEW;
END;
$$;

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
      'support'::public.user_role,
      'admin'::public.user_role
    ) THEN
      IF NEW.order_id IS NULL THEN
        NEW.scope := 'system';
        NEW.source := CASE
          WHEN NEW.source = 'support_ticket' THEN NEW.source
          ELSE 'system'
        END;
      ELSE
        NEW.scope := 'order';
      END IF;
    ELSIF actor_role IN (
      'customer'::public.user_role,
      'driver'::public.user_role
    ) THEN
      IF NEW.order_id IS NULL THEN
        RAISE EXCEPTION 'Participants can only report an order incident'
          USING ERRCODE = '42501';
      END IF;

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
      NEW.scope := 'order';
      NEW.component := NULL;
    ELSE
      RAISE EXCEPTION 'Role cannot create risk reports'
        USING ERRCODE = '42501';
    END IF;

    NEW.reported_by := actor_id;
    NEW.updated_by := actor_id;
    NEW.reporter_role_snapshot := actor_role::text;
    NEW.created_at := now();
    NEW.updated_at := now();
    NEW.response_due_at := COALESCE(
      NEW.response_due_at,
      NEW.triage_due_at,
      now() + interval '10 minutes'
    );
    RETURN NEW;
  END IF;

  -- The original participant can put a waiting report back into the active
  -- investigation queue by replying. Direct table UPDATE is not granted.
  IF actor_role IN (
    'customer'::public.user_role,
    'driver'::public.user_role
  ) THEN
    IF OLD.reported_by = actor_id
      AND OLD.status = 'waiting_customer'
      AND NEW.status = 'investigating'
      AND NEW.updated_by = actor_id
      AND (
        to_jsonb(NEW) - ARRAY['status', 'updated_by', 'updated_at']
      ) = (
        to_jsonb(OLD) - ARRAY['status', 'updated_by', 'updated_at']
      ) THEN
      NEW.updated_at := now();
      RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Reporter can only reopen a waiting report by replying'
      USING ERRCODE = '42501';
  END IF;

  IF actor_role NOT IN (
    'support'::public.user_role,
    'admin'::public.user_role
  ) THEN
    RAISE EXCEPTION 'Only Support or Admin can update risk reports'
      USING ERRCODE = '42501';
  END IF;

  accepting := OLD.assigned_to IS NULL
    AND NEW.assigned_to = actor_id
    AND OLD.status = 'open'
    AND NEW.status = 'investigating';

  taking_over := actor_role = 'admin'::public.user_role
    AND OLD.assigned_to IS DISTINCT FROM actor_id
    AND NEW.assigned_to = actor_id
    AND NEW.status = OLD.status;

  IF NOT accepting
    AND NOT taking_over
    AND OLD.assigned_to IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'Only the assigned staff member can update this report'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.assigned_to IS NOT NULL THEN
    SELECT role INTO assignee_role
    FROM public.users
    WHERE id = NEW.assigned_to;
    IF assignee_role NOT IN (
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
    OR NEW.source IS DISTINCT FROM OLD.source
    OR NEW.scope IS DISTINCT FROM OLD.scope THEN
    RAISE EXCEPTION 'Scope, order, reporter and source cannot be changed'
      USING ERRCODE = '23514';
  END IF;

  IF OLD.severity = 'critical'
    AND NEW.severity IS DISTINCT FROM OLD.severity
    AND actor_role <> 'admin'::public.user_role THEN
    RAISE EXCEPTION 'Only Admin can change critical severity'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status
    AND NOT accepting
    AND NOT taking_over THEN
    IF NOT (
      (OLD.status = 'open' AND NEW.status IN ('investigating', 'dismissed'))
      OR (OLD.status = 'investigating' AND NEW.status IN (
        'action_required', 'waiting_customer', 'waiting_admin',
        'resolved', 'dismissed'
      ))
      OR (OLD.status = 'action_required' AND NEW.status IN (
        'investigating', 'waiting_customer', 'waiting_admin',
        'resolved', 'dismissed'
      ))
      OR (OLD.status = 'waiting_customer' AND NEW.status IN (
        'investigating', 'action_required', 'resolved', 'dismissed'
      ))
      OR (OLD.status = 'waiting_admin' AND NEW.status IN (
        'investigating', 'action_required', 'resolved', 'dismissed'
      ))
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

CREATE OR REPLACE FUNCTION private.create_risk_intervention()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.order_id IS NOT NULL THEN
    INSERT INTO public.risk_report_interventions (
      risk_report_id,
      order_id,
      driver_id,
      decision_due_at
    )
    SELECT
      NEW.id,
      NEW.order_id,
      participant_order.driver_id,
      COALESCE(
        NEW.triage_due_at,
        NEW.response_due_at,
        now() + interval '10 minutes'
      )
    FROM public.orders AS participant_order
    WHERE participant_order.id = NEW.order_id
    ON CONFLICT (risk_report_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.validate_support_ticket_write()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.validate_risk_report_write()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.create_risk_intervention()
  FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.support_ticket_messages IS
  'Public customer conversation and internal staff notes for a support ticket.';
COMMENT ON TABLE public.risk_report_messages IS
  'Public reporter conversation and internal staff messages for a risk report.';
COMMENT ON COLUMN public.risk_reports.scope IS
  'order for order-linked incidents; system for platform-wide incidents.';
