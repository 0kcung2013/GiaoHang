-- Transition guards for the return-order state machine.

CREATE OR REPLACE FUNCTION private.enforce_pending_custody_order_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  pending_intervention public.risk_report_interventions%ROWTYPE;
  authorized_resolution boolean := false;
  has_return_workflow boolean := false;
BEGIN
  SELECT * INTO pending_intervention
  FROM public.risk_report_interventions intervention
  WHERE intervention.order_id = OLD.id
    AND intervention.state IN ('return_required', 'handoff_required')
  LIMIT 1;

  IF FOUND AND (
    NEW.status IS DISTINCT FROM OLD.status
    OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
  ) THEN
    SELECT role INTO actor_role FROM public.users WHERE id = actor_id;
    SELECT EXISTS (
      SELECT 1 FROM public.order_returns order_return
      WHERE order_return.order_id = OLD.id
    ) INTO has_return_workflow;

    authorized_resolution := (
      (
        pending_intervention.state = 'return_required'
        AND (
          (actor_role = 'support'::public.user_role
            AND OLD.status = 'delivering'::public.order_status
            AND NEW.status = 'return_approved'::public.order_status)
          OR (actor_id = pending_intervention.driver_id
            AND OLD.status = 'return_approved'::public.order_status
            AND NEW.status = 'returning'::public.order_status)
          OR (actor_id = pending_intervention.driver_id
            AND OLD.status = 'returning'::public.order_status
            AND NEW.status = 'returned'::public.order_status)
          OR (NOT has_return_workflow
            AND actor_id = pending_intervention.driver_id
            AND NEW.status = 'cancelled'::public.order_status)
        )
        AND NEW.driver_id IS NOT DISTINCT FROM OLD.driver_id
      )
      OR (
        pending_intervention.state = 'handoff_required'
        AND actor_role IN (
          'support'::public.user_role,
          'admin'::public.user_role
        )
        AND NEW.status = 'risk_hold'::public.order_status
        AND NEW.driver_id IS NULL
      )
    );

    IF actor_role IS NULL OR NOT authorized_resolution THEN
      RAISE EXCEPTION 'Pending custody must be resolved before changing the order'
        USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_driver_order_status_progression()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  authorized_custody_transition boolean := false;
BEGIN
  IF OLD.driver_id = actor_id
    AND EXISTS (
      SELECT 1 FROM public.users actor
      WHERE actor.id = actor_id
        AND actor.role = 'driver'::public.user_role
    )
  THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.risk_report_interventions intervention
      WHERE intervention.order_id = OLD.id
        AND intervention.driver_id = actor_id
        AND (
          (intervention.state = 'return_required'
            AND (
              (OLD.status = 'return_approved'::public.order_status
                AND NEW.status = 'returning'::public.order_status)
              OR (OLD.status = 'returning'::public.order_status
                AND NEW.status = 'returned'::public.order_status)
            )
            AND NEW.driver_id IS NOT DISTINCT FROM OLD.driver_id)
          OR (intervention.state = 'handoff_required'
            AND NEW.status = 'risk_hold'::public.order_status
            AND NEW.driver_id IS NULL)
        )
    ) INTO authorized_custody_transition;

    IF authorized_custody_transition THEN
      IF (to_jsonb(NEW) - 'status' - 'driver_id' - 'risk_hold_report_id'
            - 'status_note' - 'cancelled_at' - 'updated_at') <>
         (to_jsonb(OLD) - 'status' - 'driver_id' - 'risk_hold_report_id'
            - 'status_note' - 'cancelled_at' - 'updated_at') THEN
        RAISE EXCEPTION
          'Custody transition may only update approved order fields.';
      END IF;
      RETURN NEW;
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.risk_report_interventions intervention
      WHERE intervention.order_id = OLD.id
        AND intervention.driver_id = actor_id
        AND intervention.state IN ('return_required', 'handoff_required')
    ) THEN
      RAISE EXCEPTION
        'Custody action must be resolved before delivery progression'
        USING ERRCODE = '23514';
    END IF;

    IF (to_jsonb(NEW) - 'status' - 'updated_at') <>
       (to_jsonb(OLD) - 'status' - 'updated_at') THEN
      RAISE EXCEPTION 'Drivers may only update order status fields.';
    END IF;

    IF NOT (
      (OLD.status = 'assigned'::public.order_status
        AND NEW.status = 'picking_up'::public.order_status)
      OR (OLD.status = 'picking_up'::public.order_status
        AND NEW.status = 'delivering'::public.order_status)
      OR (OLD.status = 'delivering'::public.order_status
        AND NEW.status = 'delivered'::public.order_status)
    ) THEN
      RAISE EXCEPTION 'Invalid driver order status transition.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Allow the assigned Driver to close only the risk report that belongs to a
-- server-validated, already completed return. All other report writes keep the
-- existing ownership and role rules.
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
  SELECT role INTO actor_role FROM public.users WHERE id = actor_id;

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
      FROM public.orders WHERE id = NEW.order_id;
      IF NOT (
        (actor_role = 'customer'::public.user_role
          AND order_customer_id = actor_id)
        OR (actor_role = 'driver'::public.user_role
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

  IF actor_role IN (
    'customer'::public.user_role,
    'driver'::public.user_role
  ) THEN
    IF actor_role = 'driver'::public.user_role
      AND OLD.status = 'action_required'
      AND NEW.status = 'resolved'
      AND EXISTS (
        SELECT 1
        FROM public.order_returns completed_return
        WHERE completed_return.risk_report_id = OLD.id
          AND completed_return.driver_id = actor_id
          AND completed_return.status = 'returned'
      )
      AND (
        to_jsonb(NEW) - ARRAY[
          'status', 'resolution', 'resolved_at', 'updated_by', 'updated_at'
        ]
      ) = (
        to_jsonb(OLD) - ARRAY[
          'status', 'resolution', 'resolved_at', 'updated_by', 'updated_at'
        ]
      ) THEN
      IF NEW.resolution IS NULL OR char_length(trim(NEW.resolution)) < 3 THEN
        RAISE EXCEPTION 'Resolution is required when closing a risk report'
          USING ERRCODE = '23514';
      END IF;
      NEW.resolved_at := COALESCE(OLD.resolved_at, now());
      NEW.updated_by := actor_id;
      NEW.updated_at := now();
      RETURN NEW;
    END IF;

    IF OLD.reported_by = actor_id
      AND OLD.status = 'waiting_customer'
      AND NEW.status = 'investigating'
      AND NEW.updated_by = actor_id
      AND (to_jsonb(NEW) - ARRAY['status', 'updated_by', 'updated_at'])
        = (to_jsonb(OLD) - ARRAY['status', 'updated_by', 'updated_at']) THEN
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
        OLD.status, NEW.status USING ERRCODE = '23514';
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


