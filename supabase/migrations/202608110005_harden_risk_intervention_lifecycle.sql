-- Keep operational custody, order progression, audit, and Realtime delivery
-- consistent when multiple reports exist for the same order.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'risk_report_interventions'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.risk_report_interventions;
  END IF;
END;
$$;

ALTER TABLE public.orders
  ADD COLUMN risk_hold_report_id uuid
  REFERENCES public.risk_reports(id) ON DELETE SET NULL;

CREATE INDEX orders_risk_hold_report_idx
  ON public.orders(risk_hold_report_id)
  WHERE risk_hold_report_id IS NOT NULL;

DO $$
DECLARE
  conflicting_order_id uuid;
BEGIN
  SELECT intervention.order_id
  INTO conflicting_order_id
  FROM public.risk_report_interventions AS intervention
  WHERE intervention.state IN ('return_required', 'handoff_required')
  GROUP BY intervention.order_id
  HAVING count(*) > 1
  LIMIT 1;

  IF conflicting_order_id IS NOT NULL THEN
    RAISE EXCEPTION
      'Resolve duplicate pending custody decisions before applying migration: %',
      conflicting_order_id;
  END IF;
END;
$$;

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
BEGIN
  SELECT * INTO pending_intervention
  FROM public.risk_report_interventions AS intervention
  WHERE intervention.order_id = OLD.id
    AND intervention.state IN ('return_required', 'handoff_required')
  LIMIT 1;

  IF FOUND AND (
    NEW.status IS DISTINCT FROM OLD.status
    OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
  ) THEN
    SELECT role INTO actor_role FROM public.users WHERE id = actor_id;
    authorized_resolution := (
      actor_role IN ('support'::public.user_role, 'admin'::public.user_role)
      OR actor_id = pending_intervention.driver_id
    ) AND (
      (
        pending_intervention.state = 'return_required'
        AND NEW.status = 'cancelled'::public.order_status
        AND NEW.driver_id IS NOT DISTINCT FROM OLD.driver_id
      )
      OR (
        pending_intervention.state = 'handoff_required'
        AND NEW.status = 'risk_hold'::public.order_status
        AND NEW.driver_id IS NULL
      )
    );

    IF actor_role IS NULL OR NOT authorized_resolution THEN
      RAISE EXCEPTION
        'Pending custody must be resolved before changing the order'
        USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER orders_pending_custody_transition_guard
BEFORE UPDATE OF status, driver_id ON public.orders
FOR EACH ROW
EXECUTE FUNCTION private.enforce_pending_custody_order_transition();

CREATE OR REPLACE FUNCTION private.capture_risk_hold_cause()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.state = 'held_before_pickup'
    OR (OLD.state = 'handoff_required' AND NEW.state = 'released') THEN
    UPDATE public.orders
    SET risk_hold_report_id = NEW.risk_report_id,
        updated_at = now()
    WHERE id = NEW.order_id
      AND status = 'risk_hold'::public.order_status;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER risk_interventions_capture_hold_cause
AFTER UPDATE OF state ON public.risk_report_interventions
FOR EACH ROW
EXECUTE FUNCTION private.capture_risk_hold_cause();

CREATE OR REPLACE FUNCTION private.enforce_single_pending_risk_custody()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.state IN ('return_required', 'handoff_required')
    AND OLD.state IS DISTINCT FROM NEW.state THEN
    PERFORM 1
    FROM public.orders AS risk_order
    WHERE risk_order.id = NEW.order_id
    FOR UPDATE;

    IF EXISTS (
      SELECT 1
      FROM public.risk_report_interventions AS other_intervention
      WHERE other_intervention.order_id = NEW.order_id
        AND other_intervention.risk_report_id <> NEW.risk_report_id
        AND other_intervention.state IN ('return_required', 'handoff_required')
    ) THEN
      RAISE EXCEPTION 'Custody action is already pending for this order'
        USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER risk_interventions_one_pending_custody
BEFORE UPDATE OF state ON public.risk_report_interventions
FOR EACH ROW
EXECUTE FUNCTION private.enforce_single_pending_risk_custody();

CREATE OR REPLACE FUNCTION private.prevent_risk_report_closure_with_pending_custody()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.status IN ('resolved', 'dismissed')
    AND OLD.status IS DISTINCT FROM NEW.status
    AND EXISTS (
      SELECT 1
      FROM public.risk_report_interventions AS intervention
      WHERE intervention.risk_report_id = NEW.id
        AND intervention.state IN ('return_required', 'handoff_required')
    ) THEN
    RAISE EXCEPTION 'Cannot close a report while custody is pending'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER risk_reports_pending_custody_blocks_closure
BEFORE UPDATE OF status ON public.risk_reports
FOR EACH ROW
EXECUTE FUNCTION private.prevent_risk_report_closure_with_pending_custody();

CREATE OR REPLACE FUNCTION private.record_combined_risk_assignment_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.assigned_to IS DISTINCT FROM OLD.assigned_to
    AND NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO public.risk_report_events (
      risk_report_id,
      actor_id,
      event_type,
      from_status,
      to_status,
      details
    ) VALUES (
      NEW.id,
      (SELECT auth.uid()),
      'assigned',
      OLD.status,
      NEW.status,
      jsonb_build_object(
        'from', OLD.assigned_to,
        'to', NEW.assigned_to,
        'operation', 'accepted_report'
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER risk_reports_record_combined_assignment
AFTER UPDATE OF assigned_to, status ON public.risk_reports
FOR EACH ROW
EXECUTE FUNCTION private.record_combined_risk_assignment_event();

CREATE OR REPLACE FUNCTION public.enforce_driver_order_status_progression()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  authorized_custody_release boolean := false;
BEGIN
  IF OLD.driver_id = actor_id
    AND EXISTS (
      SELECT 1
      FROM public.users AS actor
      WHERE actor.id = actor_id
        AND actor.role = 'driver'::public.user_role
    )
  THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.risk_report_interventions AS intervention
      JOIN public.risk_reports AS report
        ON report.id = intervention.risk_report_id
      WHERE report.order_id = OLD.id
        AND intervention.order_id = OLD.id
        AND intervention.driver_id = actor_id
        AND OLD.status IN (
          'picking_up'::public.order_status,
          'delivering'::public.order_status
        )
        AND (
          (
            intervention.state = 'return_required'
            AND NEW.status = 'cancelled'::public.order_status
            AND NEW.driver_id IS NOT DISTINCT FROM OLD.driver_id
          )
          OR (
            intervention.state = 'handoff_required'
            AND NEW.status = 'risk_hold'::public.order_status
            AND NEW.driver_id IS NULL
          )
        )
    ) INTO authorized_custody_release;

    IF authorized_custody_release THEN
      IF (to_jsonb(NEW)
          - 'status'
          - 'driver_id'
          - 'risk_hold_report_id'
          - 'status_note'
          - 'cancelled_at'
          - 'updated_at') <>
         (to_jsonb(OLD)
          - 'status'
          - 'driver_id'
          - 'risk_hold_report_id'
          - 'status_note'
          - 'cancelled_at'
          - 'updated_at') THEN
        RAISE EXCEPTION
          'Custody resolution may only update approved order release fields.';
      END IF;
      RETURN NEW;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.risk_report_interventions AS intervention
      WHERE intervention.order_id = OLD.id
        AND intervention.driver_id = actor_id
        AND intervention.state IN ('return_required', 'handoff_required')
    ) THEN
      RAISE EXCEPTION 'Custody action must be resolved before delivery progression'
        USING ERRCODE = '23514';
    END IF;

    IF (to_jsonb(NEW) - 'status' - 'updated_at') <>
       (to_jsonb(OLD) - 'status' - 'updated_at') THEN
      RAISE EXCEPTION 'Drivers may only update order status fields.';
    END IF;

    IF NOT (
      (OLD.status = 'assigned'::public.order_status AND NEW.status = 'picking_up'::public.order_status)
      OR (OLD.status = 'picking_up'::public.order_status AND NEW.status = 'delivering'::public.order_status)
      OR (OLD.status = 'delivering'::public.order_status AND NEW.status = 'delivered'::public.order_status)
    ) THEN
      RAISE EXCEPTION 'Invalid driver order status transition.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_risk_custody_resolved(
  p_report_id uuid,
  p_note text DEFAULT NULL
)
RETURNS public.risk_report_interventions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  report public.risk_reports%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  v_order public.orders%ROWTYPE;
  previous_state text;
BEGIN
  SELECT role INTO actor_role FROM public.users WHERE id = actor_id;
  IF actor_id IS NULL OR actor_role IS NULL THEN
    RAISE EXCEPTION 'Authenticated user profile is required'
      USING ERRCODE = '42501';
  END IF;
  IF actor_role NOT IN ('support'::public.user_role, 'admin'::public.user_role)
    AND NOT EXISTS (
      SELECT 1 FROM public.risk_report_interventions AS authorized_intervention
      WHERE authorized_intervention.risk_report_id = p_report_id
        AND authorized_intervention.driver_id = actor_id
    ) THEN
    RAISE EXCEPTION 'Only assigned Driver or staff can confirm custody'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO report FROM public.risk_reports
    WHERE id = p_report_id FOR UPDATE;
  SELECT * INTO intervention FROM public.risk_report_interventions
    WHERE risk_report_id = p_report_id FOR UPDATE;
  SELECT * INTO v_order FROM public.orders
    WHERE id = report.order_id FOR UPDATE;

  IF intervention.state NOT IN ('return_required', 'handoff_required') THEN
    RAISE EXCEPTION 'No cargo custody action is pending'
      USING ERRCODE = '23514';
  END IF;
  IF v_order.status NOT IN (
      'picking_up'::public.order_status,
      'delivering'::public.order_status
    ) OR v_order.driver_id IS DISTINCT FROM intervention.driver_id THEN
    RAISE EXCEPTION 'Order custody no longer matches this intervention'
      USING ERRCODE = '23514';
  END IF;
  previous_state := intervention.state;

  IF intervention.state = 'return_required' THEN
    UPDATE public.orders SET
      status = 'cancelled'::public.order_status,
      risk_hold_report_id = NULL,
      status_note = COALESCE(NULLIF(trim(p_note), ''), intervention.instruction),
      cancelled_at = now(),
      updated_at = now()
    WHERE id = v_order.id;
    INSERT INTO public.order_status_logs(
      order_id, status, title, description, logged_by
    ) VALUES (
      v_order.id,
      'cancelled'::public.order_status,
      'Da hoan tra hang',
      COALESCE(NULLIF(trim(p_note), ''), intervention.instruction),
      actor_id
    );
  ELSE
    UPDATE public.orders SET
      status = 'risk_hold'::public.order_status,
      driver_id = NULL,
      risk_hold_report_id = p_report_id,
      status_note = COALESCE(NULLIF(trim(p_note), ''), intervention.instruction),
      updated_at = now()
    WHERE id = v_order.id;
    INSERT INTO public.order_status_logs(
      order_id, status, title, description, logged_by
    ) VALUES (
      v_order.id,
      'risk_hold'::public.order_status,
      'Da ban giao hang',
      COALESCE(NULLIF(trim(p_note), ''), intervention.instruction),
      actor_id
    );
  END IF;

  UPDATE public.risk_report_interventions SET
    state = 'released',
    driver_released_at = now(),
    updated_at = now()
  WHERE risk_report_id = p_report_id
  RETURNING * INTO intervention;
  INSERT INTO public.risk_report_events(
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (
    p_report_id,
    actor_id,
    'intervention_changed',
    report.status,
    report.status,
    jsonb_build_object('state', 'released', 'previous_state', previous_state)
  );
  RETURN intervention;
END;
$$;

CREATE OR REPLACE FUNCTION public.resume_risk_held_order(p_report_id uuid)
RETURNS public.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := private.require_risk_staff();
  report public.risk_reports%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  v_order public.orders%ROWTYPE;
BEGIN
  SELECT * INTO report
  FROM public.risk_reports
  WHERE id = p_report_id
  FOR UPDATE;
  SELECT * INTO intervention
  FROM public.risk_report_interventions
  WHERE risk_report_id = p_report_id
  FOR UPDATE;
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = report.order_id
  FOR UPDATE;

  IF v_order.status <> 'risk_hold'::public.order_status
    OR intervention.state NOT IN ('held_before_pickup', 'released')
    OR v_order.risk_hold_report_id IS DISTINCT FROM p_report_id THEN
    RAISE EXCEPTION 'Order is not ready to resume'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.risk_report_interventions AS other_intervention
    WHERE other_intervention.order_id = v_order.id
      AND other_intervention.risk_report_id <> p_report_id
      AND other_intervention.state IN (
        'held_before_pickup',
        'return_required',
        'handoff_required'
      )
  ) THEN
    RAISE EXCEPTION 'Another risk intervention still blocks this order'
      USING ERRCODE = '23514';
  END IF;

  UPDATE public.orders SET
    status = 'confirmed'::public.order_status,
    driver_id = NULL,
    risk_hold_report_id = NULL,
    status_note = 'CSKH da cho phep tiep tuc phan cong.',
    updated_at = now()
  WHERE id = v_order.id
  RETURNING * INTO v_order;

  UPDATE public.risk_report_interventions SET
    state = 'released',
    driver_id = NULL,
    driver_released_at = COALESCE(driver_released_at, now()),
    updated_at = now()
  WHERE risk_report_id = p_report_id
  RETURNING * INTO intervention;

  IF report.status = 'action_required' THEN
    UPDATE public.risk_reports SET
      status = 'investigating',
      updated_by = actor_id
    WHERE id = p_report_id
    RETURNING * INTO report;
  END IF;

  INSERT INTO public.order_status_logs(
    order_id,
    status,
    title,
    description,
    logged_by
  ) VALUES (
    v_order.id,
    'confirmed'::public.order_status,
    'Don hang tiep tuc',
    'CSKH da cho phep phan cong tai xe moi.',
    actor_id
  );
  RETURN v_order;
END;
$$;

REVOKE ALL ON FUNCTION private.enforce_pending_custody_order_transition()
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.capture_risk_hold_cause()
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.enforce_single_pending_risk_custody()
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.prevent_risk_report_closure_with_pending_custody()
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.record_combined_risk_assignment_event()
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.enforce_driver_order_status_progression()
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.confirm_risk_custody_resolved(uuid, text)
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.resume_risk_held_order(uuid)
  FROM public, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.confirm_risk_custody_resolved(uuid, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.resume_risk_held_order(uuid)
  TO authenticated;

COMMENT ON FUNCTION private.enforce_single_pending_risk_custody() IS
  'Serializes custody decisions by order and rejects conflicting active actions.';

-- Cheap preflight used by the mobile report wizard before it decodes or uploads
-- evidence. The unique index remains the final race-safe duplicate guard.
CREATE OR REPLACE FUNCTION public.has_active_participant_risk_report(
  p_order_id uuid,
  p_category text
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  v_order public.orders%ROWTYPE;
BEGIN
  IF actor_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  SELECT actor.role
  INTO actor_role
  FROM public.users AS actor
  WHERE actor.id = actor_id;

  IF actor_role NOT IN (
    'customer'::public.user_role,
    'driver'::public.user_role
  ) THEN
    RAISE EXCEPTION 'Only Customer or Driver can use this command'
      USING ERRCODE = '42501';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    (actor_role = 'customer'::public.user_role
      AND v_order.customer_id = actor_id)
    OR
    (actor_role = 'driver'::public.user_role
      AND v_order.driver_id = actor_id)
  ) THEN
    RAISE EXCEPTION 'Reporter is not a participant of this order'
      USING ERRCODE = '42501';
  END IF;

  IF p_category NOT IN (
    'delivery_delay',
    'suspicious_address',
    'contact_issue',
    'cargo_issue',
    'payment',
    'safety',
    'other'
  ) THEN
    RAISE EXCEPTION 'Unsupported participant risk category'
      USING ERRCODE = '22023';
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.risk_reports AS report
    WHERE report.order_id = p_order_id
      AND report.category = p_category
      AND report.status NOT IN ('resolved', 'dismissed')
  );
END;
$$;

REVOKE ALL ON FUNCTION public.has_active_participant_risk_report(uuid, text)
  FROM public, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_active_participant_risk_report(uuid, text)
  TO authenticated;

COMMENT ON FUNCTION public.has_active_participant_risk_report(uuid, text) IS
  'Checks an order participant for an active duplicate before evidence upload.';
