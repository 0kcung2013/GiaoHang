-- Operational decisions for participant-created risk reports.
-- Accepting a report starts investigation only; it never pauses the order.

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
    'note_added'
  ));

CREATE TABLE public.risk_report_interventions (
  risk_report_id uuid PRIMARY KEY
    REFERENCES public.risk_reports(id) ON DELETE CASCADE,
  order_id uuid NOT NULL
    REFERENCES public.orders(id) ON DELETE RESTRICT,
  state text NOT NULL DEFAULT 'awaiting_triage'
    CHECK (state IN (
      'awaiting_triage',
      'held_before_pickup',
      'continue_delivery',
      'return_required',
      'handoff_required',
      'released'
    )),
  driver_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  decision_due_at timestamptz NOT NULL,
  decided_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  decided_at timestamptz,
  instruction text CHECK (
    instruction IS NULL OR char_length(trim(instruction)) <= 4000
  ),
  driver_released_at timestamptz,
  escalated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT risk_intervention_instruction_check CHECK (
    state NOT IN ('return_required', 'handoff_required')
    OR char_length(trim(COALESCE(instruction, ''))) >= 3
  )
);

CREATE TABLE public.risk_report_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  risk_report_id uuid NOT NULL
    REFERENCES public.risk_reports(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  body text NOT NULL CHECK (char_length(trim(body)) BETWEEN 3 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX risk_interventions_queue_idx
  ON public.risk_report_interventions(state, escalated_at, decision_due_at);
CREATE INDEX risk_interventions_order_idx
  ON public.risk_report_interventions(order_id);
CREATE INDEX risk_report_notes_report_idx
  ON public.risk_report_notes(risk_report_id, created_at DESC);

ALTER TABLE public.risk_report_interventions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_report_notes ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.risk_report_interventions
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON public.risk_report_notes
  FROM public, anon, authenticated, service_role;
GRANT SELECT ON public.risk_report_interventions TO authenticated;
GRANT SELECT ON public.risk_report_notes TO authenticated;

CREATE POLICY risk_interventions_staff_select
ON public.risk_report_interventions
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users AS actor
    WHERE actor.id = (SELECT auth.uid())
      AND actor.role IN ('support'::public.user_role, 'admin'::public.user_role)
  )
);

CREATE POLICY risk_interventions_participant_select
ON public.risk_report_interventions
FOR SELECT TO authenticated
USING (
  driver_id = (SELECT auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.orders AS participant_order
    WHERE participant_order.id = risk_report_interventions.order_id
      AND participant_order.customer_id = (SELECT auth.uid())
  )
);

CREATE POLICY risk_notes_staff_select
ON public.risk_report_notes
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users AS actor
    WHERE actor.id = (SELECT auth.uid())
      AND actor.role IN ('support'::public.user_role, 'admin'::public.user_role)
  )
);

DROP POLICY IF EXISTS risk_events_participant_select
  ON public.risk_report_events;
CREATE POLICY risk_events_participant_select
ON public.risk_report_events
FOR SELECT TO authenticated
USING (
  event_type <> 'note_added'
  AND EXISTS (
    SELECT 1 FROM public.risk_reports AS report
    WHERE report.id = risk_report_events.risk_report_id
      AND report.reported_by = (SELECT auth.uid())
  )
);

CREATE OR REPLACE FUNCTION private.require_risk_staff()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
BEGIN
  IF actor_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.users AS actor
    WHERE actor.id = actor_id
      AND actor.role IN ('support'::public.user_role, 'admin'::public.user_role)
  ) THEN
    RAISE EXCEPTION 'Only Support or Admin can perform this action'
      USING ERRCODE = '42501';
  END IF;
  RETURN actor_id;
END;
$$;

CREATE OR REPLACE FUNCTION private.create_risk_intervention()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.reporter_role_snapshot IN ('customer', 'driver') THEN
    INSERT INTO public.risk_report_interventions (
      risk_report_id, order_id, driver_id, decision_due_at
    )
    SELECT NEW.id, NEW.order_id, participant_order.driver_id,
      COALESCE(NEW.triage_due_at, now() + interval '10 minutes')
    FROM public.orders AS participant_order
    WHERE participant_order.id = NEW.order_id
    ON CONFLICT (risk_report_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER risk_reports_create_intervention
AFTER INSERT ON public.risk_reports
FOR EACH ROW EXECUTE FUNCTION private.create_risk_intervention();

INSERT INTO public.risk_report_interventions (
  risk_report_id, order_id, driver_id, decision_due_at
)
SELECT report.id, report.order_id, risk_order.driver_id,
  COALESCE(report.triage_due_at, report.created_at + interval '10 minutes')
FROM public.risk_reports AS report
JOIN public.orders AS risk_order ON risk_order.id = report.order_id
WHERE report.reporter_role_snapshot IN ('customer', 'driver')
ON CONFLICT (risk_report_id) DO NOTHING;

CREATE OR REPLACE FUNCTION private.escalate_overdue_risk_triage()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  affected_rows integer;
BEGIN
  UPDATE public.risk_report_interventions
  SET escalated_at = now(), updated_at = now()
  WHERE state = 'awaiting_triage'
    AND decision_due_at <= now()
    AND escalated_at IS NULL;
  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  RETURN affected_rows;
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
  SELECT * INTO report FROM public.risk_reports
  WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Risk report not found' USING ERRCODE = 'P0002'; END IF;
  IF report.status <> 'open' THEN RAISE EXCEPTION 'Risk report is not open' USING ERRCODE = '23514'; END IF;
  IF report.assigned_to IS NOT NULL AND report.assigned_to <> actor_id THEN
    RAISE EXCEPTION 'Risk report is assigned to another staff member' USING ERRCODE = '42501';
  END IF;
  UPDATE public.risk_reports
  SET assigned_to = actor_id, status = 'investigating', updated_by = actor_id
  WHERE id = p_report_id RETURNING * INTO report;
  RETURN report;
END;
$$;

CREATE OR REPLACE FUNCTION public.hold_risk_order_before_pickup(
  p_report_id uuid,
  p_instruction text DEFAULT NULL
)
RETURNS public.risk_report_interventions
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
  SELECT * INTO report FROM public.risk_reports WHERE id = p_report_id FOR UPDATE;
  SELECT * INTO intervention FROM public.risk_report_interventions
    WHERE risk_report_id = p_report_id FOR UPDATE;
  SELECT * INTO v_order FROM public.orders WHERE id = report.order_id FOR UPDATE;
  IF report.status NOT IN ('investigating', 'action_required') THEN
    RAISE EXCEPTION 'Accept the report before holding the order' USING ERRCODE = '23514';
  END IF;
  IF intervention.state <> 'awaiting_triage' THEN
    RAISE EXCEPTION 'Operational decision already exists' USING ERRCODE = '23514';
  END IF;
  IF v_order.status <> 'assigned'::public.order_status THEN
    RAISE EXCEPTION 'Only an assigned pre-pickup order can be held' USING ERRCODE = '23514';
  END IF;

  UPDATE public.orders SET
    status = 'risk_hold'::public.order_status,
    driver_id = NULL,
    status_note = COALESCE(NULLIF(trim(p_instruction), ''), 'CSKH tam giu don de xu ly su co.'),
    updated_at = now()
  WHERE id = v_order.id;

  INSERT INTO public.order_status_logs(order_id, status, title, description, logged_by)
  VALUES (v_order.id, 'risk_hold'::public.order_status, 'Don hang tam giu',
    COALESCE(NULLIF(trim(p_instruction), ''), 'CSKH dang xu ly bao cao su co.'), actor_id);

  UPDATE public.risk_report_interventions SET
    state = 'held_before_pickup',
    driver_id = v_order.driver_id,
    decided_by = actor_id,
    decided_at = now(),
    instruction = NULLIF(trim(p_instruction), ''),
    driver_released_at = now(),
    updated_at = now()
  WHERE risk_report_id = p_report_id RETURNING * INTO intervention;

  IF report.status = 'investigating' THEN
    UPDATE public.risk_reports SET status = 'action_required', updated_by = actor_id
    WHERE id = p_report_id RETURNING * INTO report;
  END IF;
  INSERT INTO public.risk_report_events(
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (p_report_id, actor_id, 'intervention_changed', report.status, report.status,
    jsonb_build_object('state', intervention.state, 'driver_released', true));
  RETURN intervention;
END;
$$;

CREATE OR REPLACE FUNCTION public.decide_risk_delivery_operation(
  p_report_id uuid,
  p_decision text,
  p_instruction text DEFAULT NULL
)
RETURNS public.risk_report_interventions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := private.require_risk_staff();
  report public.risk_reports%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  v_order public.orders%ROWTYPE;
  normalized_instruction text := NULLIF(trim(p_instruction), '');
BEGIN
  SELECT * INTO report FROM public.risk_reports WHERE id = p_report_id FOR UPDATE;
  SELECT * INTO intervention FROM public.risk_report_interventions
    WHERE risk_report_id = p_report_id FOR UPDATE;
  SELECT * INTO v_order FROM public.orders WHERE id = report.order_id FOR UPDATE;
  IF report.status NOT IN ('investigating', 'action_required')
    OR intervention.state <> 'awaiting_triage' THEN
    RAISE EXCEPTION 'Report is not awaiting an operational decision' USING ERRCODE = '23514';
  END IF;
  IF v_order.status NOT IN ('picking_up'::public.order_status, 'delivering'::public.order_status) THEN
    RAISE EXCEPTION 'Cargo has not been picked up' USING ERRCODE = '23514';
  END IF;
  IF p_decision NOT IN ('continue_delivery', 'return_required', 'handoff_required') THEN
    RAISE EXCEPTION 'Unsupported operational decision' USING ERRCODE = '22023';
  END IF;
  IF p_decision IN ('return_required', 'handoff_required')
    AND char_length(COALESCE(normalized_instruction, '')) < 3 THEN
    RAISE EXCEPTION 'Return or handoff instructions are required' USING ERRCODE = '22023';
  END IF;

  UPDATE public.risk_report_interventions SET
    state = p_decision,
    driver_id = v_order.driver_id,
    decided_by = actor_id,
    decided_at = now(),
    instruction = normalized_instruction,
    updated_at = now()
  WHERE risk_report_id = p_report_id RETURNING * INTO intervention;
  IF p_decision IN ('return_required', 'handoff_required')
    AND report.status = 'investigating' THEN
    UPDATE public.risk_reports SET status = 'action_required', updated_by = actor_id
    WHERE id = p_report_id RETURNING * INTO report;
  END IF;
  INSERT INTO public.risk_report_events(
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (p_report_id, actor_id, 'intervention_changed', report.status, report.status,
    jsonb_build_object('state', p_decision));
  RETURN intervention;
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
  IF actor_role NOT IN ('support'::public.user_role, 'admin'::public.user_role)
    AND NOT EXISTS (
      SELECT 1 FROM public.risk_report_interventions AS intervention
      WHERE intervention.risk_report_id = p_report_id
        AND intervention.driver_id = actor_id
    ) THEN
    RAISE EXCEPTION 'Only assigned Driver or staff can confirm custody' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO report FROM public.risk_reports WHERE id = p_report_id FOR UPDATE;
  SELECT * INTO intervention FROM public.risk_report_interventions
    WHERE risk_report_id = p_report_id FOR UPDATE;
  SELECT * INTO v_order FROM public.orders WHERE id = report.order_id FOR UPDATE;
  IF intervention.state NOT IN ('return_required', 'handoff_required') THEN
    RAISE EXCEPTION 'No cargo custody action is pending' USING ERRCODE = '23514';
  END IF;
  previous_state := intervention.state;

  IF intervention.state = 'return_required' THEN
    UPDATE public.orders SET
      status = 'cancelled'::public.order_status,
      status_note = COALESCE(NULLIF(trim(p_note), ''), intervention.instruction),
      cancelled_at = now(),
      updated_at = now()
    WHERE id = v_order.id;
    INSERT INTO public.order_status_logs(order_id, status, title, description, logged_by)
    VALUES (v_order.id, 'cancelled'::public.order_status, 'Da hoan tra hang',
      COALESCE(NULLIF(trim(p_note), ''), intervention.instruction), actor_id);
  ELSE
    UPDATE public.orders SET
      status = 'risk_hold'::public.order_status,
      driver_id = NULL,
      status_note = COALESCE(NULLIF(trim(p_note), ''), intervention.instruction),
      updated_at = now()
    WHERE id = v_order.id;
    INSERT INTO public.order_status_logs(order_id, status, title, description, logged_by)
    VALUES (v_order.id, 'risk_hold'::public.order_status, 'Da ban giao hang',
      COALESCE(NULLIF(trim(p_note), ''), intervention.instruction), actor_id);
  END IF;

  UPDATE public.risk_report_interventions SET
    state = 'released',
    driver_released_at = now(),
    updated_at = now()
  WHERE risk_report_id = p_report_id RETURNING * INTO intervention;
  INSERT INTO public.risk_report_events(
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (p_report_id, actor_id, 'intervention_changed', report.status, report.status,
    jsonb_build_object('state', 'released', 'previous_state', previous_state));
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
  SELECT * INTO report FROM public.risk_reports WHERE id = p_report_id FOR UPDATE;
  SELECT * INTO intervention FROM public.risk_report_interventions
    WHERE risk_report_id = p_report_id FOR UPDATE;
  SELECT * INTO v_order FROM public.orders WHERE id = report.order_id FOR UPDATE;
  IF v_order.status <> 'risk_hold'::public.order_status
    OR intervention.state NOT IN ('held_before_pickup', 'released') THEN
    RAISE EXCEPTION 'Order is not ready to resume' USING ERRCODE = '23514';
  END IF;
  UPDATE public.orders SET
    status = 'confirmed'::public.order_status,
    driver_id = NULL,
    status_note = 'CSKH da cho phep tiep tuc phan cong.',
    updated_at = now()
  WHERE id = v_order.id RETURNING * INTO v_order;
  UPDATE public.risk_report_interventions SET
    state = 'released', driver_released_at = COALESCE(driver_released_at, now()), updated_at = now()
  WHERE risk_report_id = p_report_id RETURNING * INTO intervention;
  IF report.status = 'action_required' THEN
    UPDATE public.risk_reports SET status = 'investigating', updated_by = actor_id
    WHERE id = p_report_id RETURNING * INTO report;
  END IF;
  INSERT INTO public.order_status_logs(order_id, status, title, description, logged_by)
  VALUES (v_order.id, 'confirmed'::public.order_status, 'Don hang tiep tuc',
    'CSKH da cho phep phan cong tai xe moi.', actor_id);
  RETURN v_order;
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
    RAISE EXCEPTION 'Note must contain between 3 and 4000 characters' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO report FROM public.risk_reports WHERE id = p_report_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Risk report not found' USING ERRCODE = 'P0002'; END IF;
  INSERT INTO public.risk_report_notes(risk_report_id, author_id, body)
  VALUES (p_report_id, actor_id, normalized_body) RETURNING * INTO created_note;
  INSERT INTO public.risk_report_events(
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (p_report_id, actor_id, 'note_added', report.status, report.status,
    jsonb_build_object('note_id', created_note.id));
  RETURN created_note;
END;
$$;

REVOKE ALL ON FUNCTION private.require_risk_staff()
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.create_risk_intervention()
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.escalate_overdue_risk_triage()
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.accept_risk_report(uuid)
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.hold_risk_order_before_pickup(uuid, text)
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.decide_risk_delivery_operation(uuid, text, text)
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.confirm_risk_custody_resolved(uuid, text)
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.resume_risk_held_order(uuid)
  FROM public, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.add_risk_report_note(uuid, text)
  FROM public, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.accept_risk_report(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.hold_risk_order_before_pickup(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decide_risk_delivery_operation(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_risk_custody_resolved(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resume_risk_held_order(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_risk_report_note(uuid, text) TO authenticated;

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
SELECT cron.schedule(
  'escalate-overdue-risk-triage',
  '* * * * *',
  'select private.escalate_overdue_risk_triage();'
);

COMMENT ON TABLE public.risk_report_interventions IS
  'Operational decision and driver-release state for participant risk reports.';
COMMENT ON TABLE public.risk_report_notes IS
  'Immutable internal Support/Admin notes that are hidden from participants.';
