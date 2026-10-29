-- Đã duyệt và áp dụng ngày 2026-10-21: migration 20261021153619_incident_controls_simplification.
-- CSKH xử lý sự cố không phân cấp mức độ. Giữ cột/enum cũ để đọc lịch sử.
-- Không thay dữ liệu đơn, số dư, custody hoặc bằng chứng.

CREATE OR REPLACE FUNCTION private.can_driver_cancel_order_return(p_order_id uuid, p_actor_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
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
      AND report.category = 'contact_issue'
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

CREATE OR REPLACE FUNCTION public.convert_support_ticket_to_risk(p_ticket_id uuid, p_category text, p_severity text, p_title text, p_description text, p_component text DEFAULT NULL::text)
 RETURNS risk_reports
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      'medium',
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
      status = 'in_progress'
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
$function$;

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
          AND report.category = 'contact_issue'
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
$function$;

CREATE OR REPLACE FUNCTION private.enforce_risk_intervention_owner()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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
        AND report.category='contact_issue'
    )
  THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'User cannot change this intervention' USING ERRCODE='42501';
END;
$function$;

CREATE OR REPLACE FUNCTION public.transition_risk_report(p_report_id uuid, p_status text, p_resolution text DEFAULT NULL::text)
 RETURNS risk_reports
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor_id uuid := private.require_risk_staff();
  report public.risk_reports%ROWTYPE;
  normalized_resolution text := NULLIF(trim(p_resolution), '');
  admin_id uuid;
BEGIN
  IF p_status='waiting_admin' THEN
    p_status:='investigating';
  END IF;
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
        WHEN 'waiting_admin' THEN 'CSKH đang xử lý sự cố.'
        WHEN 'resolved' THEN COALESCE(report.resolution, 'Sự cố đã được xử lý.')
        WHEN 'dismissed' THEN COALESCE(report.resolution, 'Báo cáo đã được kết thúc.')
        ELSE 'CSKH đang tiếp tục xác minh báo cáo.'
      END,
      'risk_report_status',
      report.order_id, NULL, report.id
    );
  END IF;

  RETURN report;
END;
$function$;

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
    NEW.severity := 'medium';
    IF NEW.status='waiting_admin' THEN
      NEW.status:=CASE WHEN NEW.assigned_to IS NULL THEN 'open' ELSE 'investigating' END;
    END IF;
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
      IF NEW.status <> 'open'
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
              AND OLD.category = 'contact_issue'))
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
$function$;

CREATE OR REPLACE FUNCTION public.transition_support_ticket(p_ticket_id uuid, p_status text, p_resolution text DEFAULT NULL::text)
 RETURNS support_tickets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor_id uuid := private.require_risk_staff();
  ticket public.support_tickets%ROWTYPE;
  normalized_resolution text := NULLIF(trim(p_resolution), '');
  admin_id uuid;
BEGIN
  IF p_status='waiting_admin' THEN
    p_status:='in_progress';
  END IF;
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

  INSERT INTO public.case_messages(ticket_id,sender_id,sender_role_snapshot,visibility,body)
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
      WHEN 'waiting_admin' THEN 'CSKH đang xử lý yêu cầu.'
      WHEN 'resolved' THEN COALESCE(ticket.resolution, 'Yêu cầu đã kết thúc.')
      WHEN 'closed' THEN COALESCE(ticket.resolution, 'Yêu cầu đã được đóng.')
      ELSE 'CSKH đang tiếp tục xử lý yêu cầu.'
    END,
    'support_ticket_status',
    ticket.order_id, ticket.id
  );

  RETURN ticket;
END;
$function$;
