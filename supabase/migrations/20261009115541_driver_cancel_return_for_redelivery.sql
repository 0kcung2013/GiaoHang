-- Driver-requested redelivery after a contact-issue return.
-- Reuse existing missions, interventions, reports and audit logs.
ALTER TABLE public.order_returns DROP CONSTRAINT order_returns_status_check;
ALTER TABLE public.order_returns ADD CONSTRAINT order_returns_status_check
  CHECK (status IN ('approved', 'returning', 'returned', 'cancelled'));

CREATE OR REPLACE FUNCTION private.can_driver_cancel_order_return(
  p_order_id uuid, p_actor_id uuid
) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
  SELECT p_actor_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.orders o
    JOIN public.order_returns r ON r.order_id = o.id
    JOIN public.risk_reports report ON report.id = r.risk_report_id
    JOIN public.risk_report_interventions i ON i.risk_report_id = report.id
    JOIN public.users actor ON actor.id = p_actor_id
    WHERE o.id = p_order_id AND o.driver_id = p_actor_id
      AND r.driver_id = p_actor_id AND actor.role = 'driver'
      AND o.status = 'returning' AND r.status = 'returning'
      AND o.actual_picked_up_at IS NOT NULL AND o.actual_delivered_at IS NULL
      AND r.returned_at IS NULL AND r.proof_storage_path IS NULL
      AND report.category = 'contact_issue' AND report.severity IN ('low', 'medium')
      AND report.reported_by = p_actor_id AND report.reporter_role_snapshot = 'driver'
      AND report.status = 'action_required'
      AND i.state = 'return_required' AND i.driver_id = p_actor_id
      AND NOT EXISTS (
        SELECT 1 FROM public.risk_report_interventions other
        WHERE other.order_id = o.id AND other.risk_report_id <> report.id
          AND other.state IN ('return_required', 'handoff_required', 'held_before_pickup')
      )
  );
$function$;
REVOKE ALL ON FUNCTION private.can_driver_cancel_order_return(uuid, uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.can_cancel_order_return(p_order_id uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE actor_id uuid := (SELECT auth.uid());
BEGIN
  IF actor_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE = '42501'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.orders WHERE id=p_order_id AND driver_id=actor_id)
  THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED' USING ERRCODE = '42501'; END IF;
  RETURN private.can_driver_cancel_order_return(p_order_id, actor_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.can_cancel_order_return(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_cancel_order_return(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.enforce_risk_intervention_owner()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  report_assignee uuid;
BEGIN
  IF actor_id IS NULL THEN RETURN NEW; END IF;
  SELECT role INTO actor_role FROM public.users WHERE id=actor_id;
  SELECT assigned_to INTO report_assignee FROM public.risk_reports WHERE id=NEW.risk_report_id;
  IF actor_role IN ('support', 'admin') THEN
    IF report_assignee IS DISTINCT FROM actor_id THEN
      RAISE EXCEPTION 'Only the assigned staff member can change intervention' USING ERRCODE='42501';
    END IF;
    RETURN NEW;
  END IF;
  IF actor_role='driver' AND OLD.driver_id=actor_id
    AND OLD.state IN ('return_required','handoff_required') AND NEW.state='released'
  THEN RETURN NEW; END IF;
  -- Only the atomic cancel command can mark the private mission cancelled.
  IF actor_role='driver' AND OLD.driver_id=actor_id
    AND OLD.state='return_required' AND NEW.state='continue_delivery'
    AND (to_jsonb(NEW)-ARRAY['state','instruction','updated_at']) =
        (to_jsonb(OLD)-ARRAY['state','instruction','updated_at'])
    AND EXISTS (
      SELECT 1 FROM public.order_returns r JOIN public.risk_reports report ON report.id=r.risk_report_id
      WHERE r.order_id=OLD.order_id AND r.risk_report_id=OLD.risk_report_id
        AND r.driver_id=actor_id AND r.status='cancelled'
        AND report.category='contact_issue' AND report.severity IN ('low','medium')
    )
  THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'User cannot change this intervention' USING ERRCODE='42501';
END;
$function$;
REVOKE ALL ON FUNCTION private.enforce_risk_intervention_owner() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.enforce_driver_order_status_progression()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  authorized_custody_transition boolean := false;
  authorized_redelivery_transition boolean := false;
  allowed_fields text[] := ARRAY['status', 'updated_at'];
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

    -- Pickup confirmation commits custody while the vehicle is still parked.
    -- The geofence trigger validates the proof for this timestamp-only update.
    IF OLD.status = 'picking_up'::public.order_status
       AND NEW.status = OLD.status
       AND OLD.actual_picked_up_at IS NULL
       AND NEW.actual_picked_up_at IS NOT NULL
       AND (to_jsonb(NEW) - 'actual_picked_up_at' - 'updated_at') =
           (to_jsonb(OLD) - 'actual_picked_up_at' - 'updated_at') THEN
      RETURN NEW;
    END IF;

    IF OLD.status = 'picking_up'::public.order_status
       AND NEW.status = 'delivering'::public.order_status THEN
      allowed_fields := array_append(allowed_fields, 'actual_picked_up_at');
    ELSIF OLD.status = 'delivering'::public.order_status
          AND NEW.status = 'delivered'::public.order_status THEN
      allowed_fields := array_append(allowed_fields, 'actual_delivered_at');
    END IF;

    IF OLD.status = 'returning'::public.order_status
      AND NEW.status = 'delivering'::public.order_status
      AND NEW.driver_id IS NOT DISTINCT FROM OLD.driver_id THEN
      SELECT EXISTS (
        SELECT 1 FROM public.order_returns cancelled_return
        JOIN public.risk_report_interventions intervention
          ON intervention.risk_report_id = cancelled_return.risk_report_id
        JOIN public.risk_reports report ON report.id = cancelled_return.risk_report_id
        WHERE cancelled_return.order_id = OLD.id
          AND cancelled_return.driver_id = actor_id
          AND cancelled_return.status = 'cancelled'
          AND report.category = 'contact_issue' AND report.severity IN ('low', 'medium')
          AND intervention.state = 'continue_delivery'
      ) INTO authorized_redelivery_transition;
      IF authorized_redelivery_transition THEN
        allowed_fields := array_append(allowed_fields, 'status_note');
      END IF;
    END IF;

    IF (to_jsonb(NEW) - allowed_fields) <>
       (to_jsonb(OLD) - allowed_fields) THEN
      RAISE EXCEPTION 'Drivers may only update order status fields.';
    END IF;

    IF NOT (
      (OLD.status = 'assigned'::public.order_status
        AND NEW.status = 'picking_up'::public.order_status)
      OR (OLD.status = 'picking_up'::public.order_status
        AND NEW.status = 'delivering'::public.order_status)
      OR (OLD.status = 'delivering'::public.order_status
        AND NEW.status = 'delivered'::public.order_status)
      OR authorized_redelivery_transition
    ) THEN
      RAISE EXCEPTION 'Invalid driver order status transition.';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION private.validate_risk_report_write()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      AND OLD.status IN ('investigating', 'action_required')
      AND NEW.status = 'resolved'
      AND EXISTS (
        SELECT 1
        FROM public.order_returns completed_return
        WHERE completed_return.risk_report_id = OLD.id
          AND completed_return.driver_id = actor_id
          AND (completed_return.status = 'returned'
            OR (completed_return.status = 'cancelled'
              AND OLD.category = 'contact_issue'
              AND OLD.severity IN ('low', 'medium')))
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

  IF NEW.status <> 'action_required'
    AND EXISTS (
      SELECT 1
      FROM public.risk_report_interventions intervention
      WHERE intervention.risk_report_id = OLD.id
        AND intervention.state = 'return_required'
    ) THEN
    RAISE EXCEPTION 'RETURN_REPORT_STATUS_LOCKED'
      USING ERRCODE = '23514';
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
$function$
;
CREATE OR REPLACE FUNCTION public.support_approve_return(p_report_id uuid, p_reason_code text, p_destination_type text, p_destination_address text, p_destination_lat double precision, p_destination_lng double precision, p_route_origin_lat double precision, p_route_origin_lng double precision, p_route_distance_m integer, p_route_duration_s integer, p_quote_source text, p_fee_payer text, p_customer_return_charge bigint, p_driver_return_earning bigint, p_instruction text DEFAULT NULL::text)
 RETURNS order_returns
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  report public.risk_reports%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  return_order public.orders%ROWTYPE;
  created_return public.order_returns%ROWTYPE;
  expected_return_fee bigint;
  normalized_instruction text := NULLIF(trim(p_instruction), '');
BEGIN
  SELECT role INTO actor_role FROM public.users WHERE id = actor_id;
  IF actor_id IS NULL OR actor_role <> 'support'::public.user_role THEN
    RAISE EXCEPTION 'SUPPORT_REQUIRED' USING ERRCODE = '42501';
  END IF;
  IF p_destination_type NOT IN ('sender', 'processing_center')
    OR char_length(trim(COALESCE(p_destination_address, ''))) < 3
    OR p_destination_lat NOT BETWEEN -90 AND 90
    OR p_destination_lng NOT BETWEEN -180 AND 180
    OR p_route_origin_lat NOT BETWEEN -90 AND 90
    OR p_route_origin_lng NOT BETWEEN -180 AND 180
    OR p_route_distance_m < 0
    OR p_route_duration_s < 0
    OR p_quote_source NOT IN ('osrm', 'fallback')
    OR p_fee_payer <> 'platform'
    OR p_customer_return_charge < 0
    OR p_driver_return_earning < 0 THEN
    RAISE EXCEPTION 'INVALID_RETURN_QUOTE' USING ERRCODE = '22023';
  END IF;
  IF p_customer_return_charge <> 0 THEN
    RAISE EXCEPTION 'RETURN_CUSTOMER_CHARGE_NOT_SUPPORTED'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO report
  FROM public.risk_reports
  WHERE id = p_report_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'RISK_REPORT_NOT_FOUND'; END IF;

  SELECT * INTO return_order
  FROM public.orders
  WHERE id = report.order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;

  -- All return commands serialize on the order before locking case records.
  SELECT * INTO report FROM public.risk_reports
  WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RISK_REPORT_NOT_FOUND'; END IF;

  expected_return_fee := round(
    greatest(COALESCE(return_order.delivery_fee, 0), 0) * 0.5
  )::bigint;

  SELECT * INTO intervention
  FROM public.risk_report_interventions
  WHERE risk_report_id = p_report_id
  FOR UPDATE;

  IF report.assigned_to IS DISTINCT FROM actor_id
    OR report.status NOT IN ('investigating', 'action_required') THEN
    RAISE EXCEPTION 'REPORT_NOT_ASSIGNED_TO_SUPPORT'
      USING ERRCODE = '42501';
  END IF;
  IF intervention.state <> 'awaiting_triage'
    OR return_order.status <> 'delivering'::public.order_status
    OR return_order.driver_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_RETURN_APPROVAL_STATE'
      USING ERRCODE = '23514';
  END IF;

  UPDATE public.risk_report_interventions SET
    state = 'return_required',
    driver_id = return_order.driver_id,
    decided_by = actor_id,
    decided_at = clock_timestamp(),
    instruction = COALESCE(
      normalized_instruction,
      'Quay về điểm trả và bàn giao hàng cho đúng người phụ trách.'
    ),
    updated_at = clock_timestamp()
  WHERE risk_report_id = p_report_id
  RETURNING * INTO intervention;

  INSERT INTO public.order_returns (
    order_id, risk_report_id, driver_id, destination_type,
    destination_address, destination_lat, destination_lng,
    route_origin_lat, route_origin_lng, route_distance_m, route_duration_s,
    quote_source, reason_code, fee_payer, customer_return_charge,
    driver_return_earning, fee_status, instruction, approved_by
  ) VALUES (
    return_order.id, report.id, return_order.driver_id, p_destination_type,
    trim(p_destination_address), p_destination_lat, p_destination_lng,
    p_route_origin_lat, p_route_origin_lng, p_route_distance_m,
    p_route_duration_s, p_quote_source, trim(p_reason_code), p_fee_payer,
    p_customer_return_charge, expected_return_fee,
    'waived',
    COALESCE(
      normalized_instruction,
      'Quay về điểm trả và bàn giao hàng cho đúng người phụ trách.'
    ),
    actor_id
  )
  ON CONFLICT (order_id) DO UPDATE SET
    risk_report_id = EXCLUDED.risk_report_id,
    driver_id = EXCLUDED.driver_id,
    destination_type = EXCLUDED.destination_type,
    destination_address = EXCLUDED.destination_address,
    destination_lat = EXCLUDED.destination_lat,
    destination_lng = EXCLUDED.destination_lng,
    route_origin_lat = EXCLUDED.route_origin_lat,
    route_origin_lng = EXCLUDED.route_origin_lng,
    route_distance_m = EXCLUDED.route_distance_m,
    route_duration_s = EXCLUDED.route_duration_s,
    quote_source = EXCLUDED.quote_source,
    reason_code = EXCLUDED.reason_code,
    fee_payer = EXCLUDED.fee_payer,
    customer_return_charge = EXCLUDED.customer_return_charge,
    driver_return_earning = EXCLUDED.driver_return_earning,
    fee_status = EXCLUDED.fee_status,
    instruction = EXCLUDED.instruction,
    approved_by = EXCLUDED.approved_by,
    status = 'approved',
    approved_at = clock_timestamp(),
    started_at = NULL,
    arrived_at = NULL,
    returned_at = NULL,
    receiver_name = NULL,
    proof_storage_path = NULL,
    updated_at = clock_timestamp()
  WHERE public.order_returns.status = 'cancelled'
  RETURNING * INTO created_return;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'RETURN_ALREADY_ACTIVE' USING ERRCODE = '23514';
  END IF;

  UPDATE public.orders SET
    status = 'return_approved'::public.order_status,
    status_note = 'CSKH đã duyệt hoàn hàng về điểm trả.',
    updated_at = clock_timestamp()
  WHERE id = return_order.id;

  IF report.status = 'investigating' THEN
    UPDATE public.risk_reports SET
      status = 'action_required',
      updated_by = actor_id,
      updated_at = clock_timestamp()
    WHERE id = report.id;
  END IF;

  INSERT INTO public.order_status_logs(
    order_id, status, title, description, logged_by
  ) VALUES (
    return_order.id,
    'return_approved'::public.order_status,
    'CSKH đã duyệt hoàn hàng',
    'Tài xế chuẩn bị quay về điểm trả: ' || trim(p_destination_address),
    actor_id
  );

  INSERT INTO public.risk_report_events(
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (
    report.id, actor_id, 'return_approved', report.status,
    CASE WHEN report.status = 'investigating'
      THEN 'action_required' ELSE report.status END,
    jsonb_build_object(
      'return_id', created_return.id,
      'fee_payer', p_fee_payer,
      'customer_return_charge', p_customer_return_charge,
      'driver_return_earning', expected_return_fee,
      'return_fee_rate_bps', 5000
    )
  );

  PERFORM private.enqueue_case_notification(
    return_order.customer_id,
    'Đã duyệt hoàn hàng',
    'Tài xế sẽ quay về điểm trả đã được CSKH xác nhận.',
    'order_return_approved',
    return_order.id
  );
  PERFORM private.enqueue_case_notification(
    return_order.driver_id,
    'Chuyến hoàn hàng mới',
    'Phí hoàn hàng bằng 50% cước giao và do GiaoHang chi trả.',
    'order_return_approved',
    return_order.id
  );
  RETURN created_return;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.cancel_order_return(p_order_id uuid, p_reason text)
RETURNS public.order_returns
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  current_order public.orders%ROWTYPE;
  mission public.order_returns%ROWTYPE;
  report public.risk_reports%ROWTYPE;
  normalized_reason text := NULLIF(trim(p_reason), '');
  v_cancelled_at timestamptz := clock_timestamp();
BEGIN
  IF actor_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501'; END IF;
  IF normalized_reason IS NULL OR char_length(normalized_reason) NOT BETWEEN 3 AND 1000
  THEN RAISE EXCEPTION 'RETURN_CANCEL_REASON_REQUIRED' USING ERRCODE='22023'; END IF;

  SELECT * INTO current_order FROM public.orders WHERE id=p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  SELECT * INTO mission FROM public.order_returns WHERE order_id=p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RETURN_NOT_FOUND'; END IF;
  IF current_order.driver_id IS DISTINCT FROM actor_id OR mission.driver_id IS DISTINCT FROM actor_id
  THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED' USING ERRCODE='42501'; END IF;
  IF mission.status='cancelled' AND current_order.status='delivering' THEN RETURN mission; END IF;
  IF mission.status <> 'returning' OR current_order.status <> 'returning'
    OR mission.returned_at IS NOT NULL OR mission.proof_storage_path IS NOT NULL
  THEN RAISE EXCEPTION 'RETURN_CANCEL_NOT_ALLOWED' USING ERRCODE='23514'; END IF;
  SELECT * INTO report FROM public.risk_reports WHERE id=mission.risk_report_id FOR UPDATE;
  PERFORM 1 FROM public.risk_report_interventions WHERE risk_report_id=report.id FOR UPDATE;
  IF NOT private.can_driver_cancel_order_return(p_order_id,actor_id)
  THEN RAISE EXCEPTION 'RETURN_CANCEL_NOT_ALLOWED' USING ERRCODE='23514'; END IF;

  -- Preserve the complete previous mission snapshot in the existing case audit.
  INSERT INTO public.risk_report_events(risk_report_id,actor_id,event_type,from_status,to_status,details)
  VALUES (report.id,actor_id,'intervention_changed',report.status,'resolved',
    jsonb_build_object('action','return_cancelled','return_id',mission.id,
      'reason',normalized_reason,'cancelled_at',v_cancelled_at,
      'from_order_status','returning','to_order_status','delivering',
      'return_snapshot',to_jsonb(mission)));

  UPDATE public.order_returns SET status='cancelled',fee_status='waived',
    updated_at=v_cancelled_at WHERE id=mission.id RETURNING * INTO mission;
  UPDATE public.risk_report_interventions SET state='continue_delivery',
    instruction=normalized_reason,updated_at=v_cancelled_at WHERE risk_report_id=report.id;
  UPDATE public.orders SET status='delivering',status_note=normalized_reason,
    updated_at=v_cancelled_at WHERE id=p_order_id;
  UPDATE public.risk_reports SET status='resolved',resolution=normalized_reason,
    resolved_at=v_cancelled_at,updated_by=actor_id,updated_at=v_cancelled_at WHERE id=report.id;

  INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
  VALUES (p_order_id,'delivering','Hủy hoàn hàng để giao lại',normalized_reason,actor_id);
  RETURN mission;
END;
$function$;
REVOKE ALL ON FUNCTION public.cancel_order_return(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_order_return(uuid,text) TO authenticated;
NOTIFY pgrst, 'reload schema';

