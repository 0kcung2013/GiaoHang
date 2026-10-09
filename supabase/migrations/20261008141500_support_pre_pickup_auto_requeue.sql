-- Approved 2026-10-08: requeue support-cancelled drivers before physical pickup.
-- Reuse existing RPCs; no new tables, fields, policies or Edge Functions.

CREATE OR REPLACE FUNCTION public.resume_risk_held_order(p_report_id uuid)
RETURNS public.orders
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  actor_id uuid := private.require_risk_staff();
  report public.risk_reports%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  v_order public.orders%ROWTYPE;
  previous_report_status text;
  previous_driver_id uuid;
  excluded_drivers jsonb;
  v_now timestamptz;
BEGIN
  SELECT * INTO report FROM public.risk_reports
    WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Risk report not found' USING ERRCODE = 'P0002';
  END IF;
  IF report.assigned_to IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'Only the assigned staff member can resume the order'
      USING ERRCODE = '42501';
  END IF;
  SELECT * INTO intervention FROM public.risk_report_interventions
    WHERE risk_report_id = p_report_id FOR UPDATE;
  IF NOT FOUND OR intervention.order_id IS DISTINCT FROM report.order_id THEN
    RAISE EXCEPTION 'Order intervention not found' USING ERRCODE = '23514';
  END IF;
  SELECT * INTO v_order FROM public.orders
    WHERE id = report.order_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0002';
  END IF;

  -- A lost response/retry must not extend the next search or unassign its driver.
  IF intervention.state = 'released' AND EXISTS (
    SELECT 1 FROM public.risk_report_events event
    WHERE event.risk_report_id = p_report_id
      AND event.details->>'operation' = 'support_driver_reassignment'
      AND event.details->>'order_requeued' = 'true'
  ) THEN
    RETURN v_order;
  END IF;
  IF v_order.status <> 'risk_hold'::public.order_status
    OR v_order.driver_id IS NOT NULL
    OR intervention.state NOT IN ('held_before_pickup', 'released')
    OR intervention.driver_released_at IS NULL
    OR v_order.risk_hold_report_id IS DISTINCT FROM p_report_id THEN
    RAISE EXCEPTION 'Order is not ready to resume' USING ERRCODE = '23514';
  END IF;
  IF intervention.state = 'held_before_pickup'
    AND v_order.actual_picked_up_at IS NOT NULL THEN
    RAISE EXCEPTION 'Collected cargo must use the custody workflow'
      USING ERRCODE = '23514';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.risk_report_interventions other_intervention
    WHERE other_intervention.order_id = v_order.id
      AND other_intervention.risk_report_id <> p_report_id
      AND other_intervention.state IN (
        'held_before_pickup', 'return_required', 'handoff_required'
      )
  ) THEN
    RAISE EXCEPTION 'Another risk intervention still blocks this order'
      USING ERRCODE = '23514';
  END IF;

  v_now := clock_timestamp();
  previous_report_status := report.status;
  previous_driver_id := intervention.driver_id;
  excluded_drivers := COALESCE(v_order.rejected_by, '[]'::jsonb);
  IF jsonb_typeof(excluded_drivers) <> 'array' THEN
    RAISE EXCEPTION 'Order driver exclusions are invalid' USING ERRCODE = '23514';
  END IF;
  IF intervention.driver_id IS NOT NULL
    AND NOT (excluded_drivers ? intervention.driver_id::text) THEN
    excluded_drivers := excluded_drivers
      || jsonb_build_array(intervention.driver_id::text);
  END IF;

  -- Retain the pre-pickup participant so RLS delivers the cancellation notice.
  -- Completed physical handoffs keep the existing participant clearing behavior.
  UPDATE public.risk_report_interventions SET
    state = 'released',
    driver_id = CASE WHEN intervention.state = 'held_before_pickup'
      THEN intervention.driver_id ELSE NULL END,
    driver_released_at = COALESCE(driver_released_at, v_now),
    updated_at = v_now
  WHERE risk_report_id = p_report_id RETURNING * INTO intervention;

  UPDATE public.orders SET
    status = 'pending'::public.order_status,
    driver_id = NULL,
    risk_hold_report_id = NULL,
    offered_driver_id = NULL,
    offer_expires_at = NULL,
    assignment_expires_at = v_now + interval '15 minutes',
    assignment_timed_out_at = NULL,
    rejected_by = excluded_drivers,
    pickup_arrived_at = NULL,
    actual_picked_up_at = NULL,
    estimated_delivery_at = NULL,
    status_note = 'Đang tìm tài xế mới sau khi CSKH hủy nhiệm vụ tài xế cũ.',
    updated_at = v_now
  WHERE id = v_order.id RETURNING * INTO v_order;

  -- Existing closed reports stay closed when recovering a stranded old order.
  IF report.status = 'action_required' THEN
    UPDATE public.risk_reports SET
      status = 'investigating', updated_by = actor_id
    WHERE id = p_report_id RETURNING * INTO report;
  END IF;
  INSERT INTO public.order_status_logs(
    order_id, status, title, description, logged_by
  ) VALUES (
    v_order.id, 'pending'::public.order_status, 'Đang tìm tài xế mới',
    'CSKH đã gỡ tài xế cũ. Lượt tìm tài xế mới có thời hạn 15 phút.', actor_id
  );
  INSERT INTO public.risk_report_events(
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (
    p_report_id, actor_id, 'intervention_changed',
    previous_report_status, report.status,
    jsonb_build_object(
      'state', 'released', 'operation', 'support_driver_reassignment',
      'order_requeued', true, 'released_driver_id', previous_driver_id,
      'assignment_expires_at', v_order.assignment_expires_at
    )
  );
  INSERT INTO public.notifications(user_id,title,body,type,is_read,order_id)
    VALUES(v_order.customer_id,'Đang tìm tài xế mới',
      format('Đơn %s đang tìm tài xế mới sau khi CSKH gỡ tài xế cũ.',
        v_order.tracking_code),'order_update',false,v_order.id);

  PERFORM private.dispatch_next_order_offer(v_order.id, 2000);
  SELECT * INTO v_order FROM public.orders WHERE id = v_order.id;
  RETURN v_order;
END;
$function$;

CREATE OR REPLACE FUNCTION public.hold_risk_order_before_pickup(p_report_id uuid, p_instruction text DEFAULT NULL::text)
 RETURNS risk_report_interventions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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

  -- A completed cancellation stays idempotent, including after reassignment.
  IF intervention.state = 'released'
    AND intervention.driver_released_at IS NOT NULL
    AND EXISTS (SELECT 1 FROM public.risk_report_events event
      WHERE event.risk_report_id = p_report_id
        AND event.details->>'operation' = 'support_driver_reassignment'
        AND event.details->>'order_requeued' = 'true') THEN
    RETURN intervention;
  END IF;

  -- Repair a previously completed pre-pickup release without cancelling twice.
  IF intervention.state = 'held_before_pickup'
    AND intervention.driver_released_at IS NOT NULL
    AND v_order.status = 'risk_hold'::public.order_status
    AND v_order.driver_id IS NULL
    AND v_order.risk_hold_report_id = p_report_id THEN
    PERFORM public.resume_risk_held_order(p_report_id);
    SELECT * INTO intervention FROM public.risk_report_interventions
      WHERE risk_report_id = p_report_id;
    RETURN intervention;
  END IF;
  IF report.status NOT IN ('investigating', 'action_required') THEN
    RAISE EXCEPTION 'Accept the report before holding the order'
      USING ERRCODE = '23514';
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
  -- Resume and dispatch inside this RPC transaction; no committed risk_hold.
  PERFORM public.resume_risk_held_order(p_report_id);
  SELECT * INTO intervention FROM public.risk_report_interventions
    WHERE risk_report_id = p_report_id;
  RETURN intervention;
END;
$function$;
