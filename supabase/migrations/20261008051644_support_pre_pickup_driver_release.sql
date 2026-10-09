-- Cancel the driver's assignment, while retaining the customer's order for CSKH.
-- Existing tables, RPC signature, return workflow and grants stay unchanged.
CREATE OR REPLACE FUNCTION public.hold_risk_order_before_pickup(
  p_report_id uuid,
  p_instruction text DEFAULT NULL
)
RETURNS public.risk_report_interventions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  actor_id uuid := private.require_risk_staff();
  report public.risk_reports%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  v_order public.orders%ROWTYPE;
  previous_state text;
  previous_report_status text;
  instruction_text text := COALESCE(NULLIF(trim(p_instruction), ''),
    'CSKH đã hủy đơn cho tài xế trước khi nhận hàng.');
BEGIN
  SELECT * INTO report FROM public.risk_reports
    WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Risk report not found' USING ERRCODE = 'P0002';
  END IF;
  IF report.assigned_to IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'Only the assigned staff member can cancel the driver'
      USING ERRCODE = '42501';
  END IF;
  IF report.status NOT IN ('investigating', 'action_required') THEN
    RAISE EXCEPTION 'Accept the report before holding the order'
      USING ERRCODE = '23514';
  END IF;
  SELECT * INTO intervention FROM public.risk_report_interventions
    WHERE risk_report_id = p_report_id FOR UPDATE;
  IF NOT FOUND OR intervention.order_id IS DISTINCT FROM report.order_id THEN
    RAISE EXCEPTION 'Order intervention not found' USING ERRCODE = '23514';
  END IF;
  -- confirm_driver_pickup uses the same order lock. Recheck custody after locking.
  SELECT * INTO v_order FROM public.orders
    WHERE id = report.order_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0002';
  END IF;

  -- A retry must not emit another release event or extend its timestamp.
  IF intervention.state = 'held_before_pickup'
    AND intervention.driver_released_at IS NOT NULL
    AND v_order.status = 'risk_hold'::public.order_status
    AND v_order.driver_id IS NULL
    AND v_order.risk_hold_report_id = p_report_id THEN
    RETURN intervention;
  END IF;
  IF intervention.state NOT IN ('awaiting_triage', 'handoff_required') THEN
    RAISE EXCEPTION 'Operational decision already exists' USING ERRCODE = '23514';
  END IF;
  IF v_order.status NOT IN ('assigned'::public.order_status, 'picking_up'::public.order_status)
    OR v_order.actual_picked_up_at IS NOT NULL
    OR v_order.driver_id IS NULL THEN
    RAISE EXCEPTION 'Only an uncollected order can release its driver'
      USING ERRCODE = '23514';
  END IF;
  IF intervention.driver_id IS DISTINCT FROM v_order.driver_id THEN
    RAISE EXCEPTION 'Intervention no longer belongs to the assigned driver'
      USING ERRCODE = '23514';
  END IF;
  IF EXISTS (SELECT 1 FROM public.risk_report_interventions other
      WHERE other.order_id = v_order.id AND other.risk_report_id <> p_report_id
        AND other.state IN ('return_required', 'handoff_required')) THEN
    RAISE EXCEPTION 'Another custody decision is pending' USING ERRCODE = '23514';
  END IF;
  previous_state := intervention.state;
  previous_report_status := report.status;

  UPDATE public.orders SET
    status = 'risk_hold'::public.order_status,
    driver_id = NULL,
    risk_hold_report_id = p_report_id,
    status_note = instruction_text,
    updated_at = now()
  WHERE id = v_order.id;
  INSERT INTO public.order_status_logs(order_id, status, title, description, logged_by)
    VALUES (v_order.id, 'risk_hold'::public.order_status,
      'CSKH đã hủy đơn cho tài xế', instruction_text, actor_id);
  -- Retain driver_id here so existing participant RLS can deliver the release.
  UPDATE public.risk_report_interventions SET
    state = 'held_before_pickup',
    driver_id = v_order.driver_id,
    decided_by = actor_id,
    decided_at = now(),
    instruction = instruction_text,
    driver_released_at = now(),
    updated_at = now()
  WHERE risk_report_id = p_report_id RETURNING * INTO intervention;
  IF report.status = 'investigating' THEN
    UPDATE public.risk_reports SET status = 'action_required', updated_by = actor_id
      WHERE id = p_report_id RETURNING * INTO report;
  END IF;
  INSERT INTO public.risk_report_events(
    risk_report_id, actor_id, event_type, from_status, to_status, note, details
  ) VALUES (p_report_id, actor_id, 'intervention_changed',
    previous_report_status, report.status, instruction_text,
    jsonb_build_object('state', intervention.state, 'previous_state', previous_state,
      'driver_released', true, 'operation', 'support_pre_pickup_cancellation'));
  RETURN intervention;
END;
$function$;
