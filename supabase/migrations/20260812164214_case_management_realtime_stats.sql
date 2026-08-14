-- Realtime subscriptions, server-side queues, dashboard metrics and SLA jobs.

DO $$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'support_tickets',
    'support_ticket_messages',
    'risk_report_messages',
    'risk_report_events'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = table_name
    ) THEN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        table_name
      );
    END IF;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_support_tickets_page(
  p_limit integer DEFAULT 50,
  p_before_updated_at timestamptz DEFAULT NULL,
  p_before_id uuid DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_assignment text DEFAULT 'all'
)
RETURNS SETOF public.support_tickets
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := private.require_risk_staff();
BEGIN
  IF p_limit NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'Page size must be between 1 and 100'
      USING ERRCODE = '22023';
  END IF;
  IF p_assignment NOT IN ('all', 'mine', 'unassigned') THEN
    RAISE EXCEPTION 'Unsupported assignment filter'
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT ticket.*
  FROM public.support_tickets AS ticket
  WHERE (p_status IS NULL OR ticket.status = p_status)
    AND (
      p_assignment = 'all'
      OR (p_assignment = 'mine' AND ticket.assigned_to = actor_id)
      OR (p_assignment = 'unassigned' AND ticket.assigned_to IS NULL)
    )
    AND (
      p_before_updated_at IS NULL
      OR (ticket.updated_at, ticket.id) <
        (p_before_updated_at, COALESCE(p_before_id, ticket.id))
    )
  ORDER BY ticket.updated_at DESC, ticket.id DESC
  LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_risk_reports_page(
  p_limit integer DEFAULT 50,
  p_before_updated_at timestamptz DEFAULT NULL,
  p_before_id uuid DEFAULT NULL,
  p_scope text DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_assignment text DEFAULT 'all'
)
RETURNS SETOF public.risk_reports
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := private.require_risk_staff();
BEGIN
  IF p_limit NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'Page size must be between 1 and 100'
      USING ERRCODE = '22023';
  END IF;
  IF p_scope IS NOT NULL AND p_scope NOT IN ('order', 'system') THEN
    RAISE EXCEPTION 'Unsupported risk scope' USING ERRCODE = '22023';
  END IF;
  IF p_assignment NOT IN ('all', 'mine', 'unassigned') THEN
    RAISE EXCEPTION 'Unsupported assignment filter'
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT report.*
  FROM public.risk_reports AS report
  WHERE (p_scope IS NULL OR report.scope = p_scope)
    AND (p_status IS NULL OR report.status = p_status)
    AND (
      p_assignment = 'all'
      OR (p_assignment = 'mine' AND report.assigned_to = actor_id)
      OR (p_assignment = 'unassigned' AND report.assigned_to IS NULL)
    )
    AND (
      p_before_updated_at IS NULL
      OR (report.updated_at, report.id) <
        (p_before_updated_at, COALESCE(p_before_id, report.id))
    )
  ORDER BY report.updated_at DESC, report.id DESC
  LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.case_management_dashboard(
  p_since timestamptz DEFAULT (now() - interval '30 days')
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  result jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = actor_id
      AND role = 'admin'::public.user_role
  ) THEN
    RAISE EXCEPTION 'Only Admin can view case management metrics'
      USING ERRCODE = '42501';
  END IF;
  IF p_since < now() - interval '1 year' OR p_since > now() THEN
    RAISE EXCEPTION 'Metric period must be within the last year'
      USING ERRCODE = '22023';
  END IF;

  WITH support_metrics AS (
    SELECT
      count(*) FILTER (WHERE created_at >= p_since) AS total,
      count(*) FILTER (
        WHERE status NOT IN ('resolved', 'closed')
      ) AS active,
      count(*) FILTER (
        WHERE assigned_to IS NULL
          AND status NOT IN ('resolved', 'closed')
      ) AS unassigned,
      count(*) FILTER (
        WHERE first_response_at IS NULL
          AND response_due_at < now()
          AND status NOT IN ('resolved', 'closed')
      ) AS sla_overdue,
      count(*) FILTER (WHERE status = 'waiting_admin') AS waiting_admin,
      round(avg(
        extract(epoch FROM (first_response_at - created_at)) / 60
      ) FILTER (
        WHERE first_response_at IS NOT NULL AND created_at >= p_since
      )::numeric, 1) AS avg_first_response_minutes
    FROM public.support_tickets
  ),
  risk_metrics AS (
    SELECT
      count(*) FILTER (WHERE created_at >= p_since) AS total,
      count(*) FILTER (
        WHERE status NOT IN ('resolved', 'dismissed')
      ) AS active,
      count(*) FILTER (
        WHERE assigned_to IS NULL
          AND status NOT IN ('resolved', 'dismissed')
      ) AS unassigned,
      count(*) FILTER (
        WHERE first_response_at IS NULL
          AND response_due_at < now()
          AND status NOT IN ('resolved', 'dismissed')
      ) AS sla_overdue,
      count(*) FILTER (
        WHERE severity = 'critical'
          AND status NOT IN ('resolved', 'dismissed')
      ) AS critical_active,
      count(*) FILTER (
        WHERE scope = 'system'
          AND status NOT IN ('resolved', 'dismissed')
      ) AS system_active,
      count(*) FILTER (WHERE status = 'waiting_admin') AS waiting_admin,
      round(avg(
        extract(epoch FROM (first_response_at - created_at)) / 60
      ) FILTER (
        WHERE first_response_at IS NOT NULL AND created_at >= p_since
      )::numeric, 1) AS avg_first_response_minutes
    FROM public.risk_reports
  )
  SELECT jsonb_build_object(
    'generated_at', now(),
    'period_started_at', p_since,
    'support', to_jsonb(support_metrics),
    'risk', to_jsonb(risk_metrics)
  )
  INTO result
  FROM support_metrics, risk_metrics;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION private.escalate_overdue_case_management()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  ticket public.support_tickets%ROWTYPE;
  report public.risk_reports%ROWTYPE;
  admin_id uuid;
  escalation_count integer := 0;
BEGIN
  FOR ticket IN
    UPDATE public.support_tickets
    SET escalated_at = now(),
        priority = CASE
          WHEN priority IN ('low', 'normal') THEN 'high'
          ELSE priority
        END
    WHERE first_response_at IS NULL
      AND response_due_at < now()
      AND escalated_at IS NULL
      AND status NOT IN ('resolved', 'closed')
    RETURNING *
  LOOP
    escalation_count := escalation_count + 1;
    FOR admin_id IN
      SELECT id FROM public.users WHERE role = 'admin'::public.user_role
    LOOP
      PERFORM private.enqueue_case_notification(
        admin_id,
        'Yêu cầu hỗ trợ quá hạn phản hồi',
        ticket.subject,
        'support_ticket_sla_overdue',
        ticket.order_id
      );
    END LOOP;
  END LOOP;

  FOR report IN
    UPDATE public.risk_reports
    SET escalated_at = now()
    WHERE first_response_at IS NULL
      AND response_due_at < now()
      AND escalated_at IS NULL
      AND status NOT IN ('resolved', 'dismissed')
    RETURNING *
  LOOP
    escalation_count := escalation_count + 1;
    FOR admin_id IN
      SELECT id FROM public.users WHERE role = 'admin'::public.user_role
    LOOP
      PERFORM private.enqueue_case_notification(
        admin_id,
        'Báo cáo sự cố quá hạn phản hồi',
        report.title,
        'risk_report_sla_overdue',
        report.order_id
      );
    END LOOP;
  END LOOP;

  RETURN escalation_count;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM cron.job
    WHERE jobname = 'escalate-overdue-case-management'
  ) THEN
    PERFORM cron.schedule(
      'escalate-overdue-case-management',
      '*/5 * * * *',
      'select private.escalate_overdue_case_management();'
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.list_support_tickets_page(
  integer, timestamptz, uuid, text, text
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_risk_reports_page(
  integer, timestamptz, uuid, text, text, text
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.case_management_dashboard(timestamptz)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.escalate_overdue_case_management()
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.list_support_tickets_page(
  integer, timestamptz, uuid, text, text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_risk_reports_page(
  integer, timestamptz, uuid, text, text, text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.case_management_dashboard(timestamptz)
  TO authenticated;

COMMENT ON FUNCTION public.case_management_dashboard(timestamptz) IS
  'Admin-only operational totals and first-response SLA metrics.';
COMMENT ON FUNCTION private.escalate_overdue_case_management() IS
  'Marks first-response SLA breaches and notifies every Admin once.';
