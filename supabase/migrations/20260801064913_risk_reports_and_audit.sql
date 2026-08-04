-- Báo cáo rủi ro gắn với đơn hàng, dành riêng cho Support và Admin.
-- Không cho client xóa; mọi thay đổi được ghi audit trong cùng transaction.

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;

CREATE TABLE public.risk_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE RESTRICT,
  reported_by uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  assigned_to uuid REFERENCES public.users(id) ON DELETE SET NULL,
  updated_by uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  source text NOT NULL DEFAULT 'manual'
    CHECK (source IN ('manual', 'system')),
  category text NOT NULL
    CHECK (category IN (
      'delivery_delay',
      'suspicious_address',
      'repeated_cancellation',
      'payment',
      'safety',
      'system',
      'other'
    )),
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN (
      'open',
      'investigating',
      'action_required',
      'resolved',
      'dismissed'
    )),
  title text NOT NULL CHECK (char_length(trim(title)) BETWEEN 3 AND 160),
  description text NOT NULL
    CHECK (char_length(trim(description)) BETWEEN 10 AND 4000),
  resolution text
    CHECK (resolution IS NULL OR char_length(trim(resolution)) <= 4000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE TABLE public.risk_report_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  risk_report_id uuid NOT NULL
    REFERENCES public.risk_reports(id) ON DELETE CASCADE,
  actor_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  event_type text NOT NULL
    CHECK (event_type IN ('created', 'updated', 'assigned', 'status_changed')),
  from_status text,
  to_status text NOT NULL,
  note text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX risk_reports_queue_idx
  ON public.risk_reports(status, severity, updated_at DESC);
CREATE INDEX risk_reports_order_idx
  ON public.risk_reports(order_id, created_at DESC);
CREATE INDEX risk_reports_assignee_idx
  ON public.risk_reports(assigned_to, status, updated_at DESC);
CREATE UNIQUE INDEX risk_reports_active_order_category_uidx
  ON public.risk_reports(order_id, category)
  WHERE status NOT IN ('resolved', 'dismissed');
CREATE INDEX risk_report_events_report_idx
  ON public.risk_report_events(risk_report_id, created_at DESC);

ALTER TABLE public.risk_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_report_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.risk_reports FROM anon;
REVOKE ALL ON public.risk_report_events FROM anon;
REVOKE ALL ON public.risk_report_events FROM authenticated;
GRANT SELECT, INSERT, UPDATE ON public.risk_reports TO authenticated;
GRANT SELECT ON public.risk_report_events TO authenticated;

CREATE POLICY risk_reports_staff_select
ON public.risk_reports
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
);

CREATE POLICY risk_reports_staff_insert
ON public.risk_reports
FOR INSERT
TO authenticated
WITH CHECK (
  reported_by = (SELECT auth.uid())
  AND updated_by = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.users AS actor
    WHERE actor.id = (SELECT auth.uid())
      AND actor.role IN (
        'support'::public.user_role,
        'admin'::public.user_role
      )
  )
);

CREATE POLICY risk_reports_staff_update
ON public.risk_reports
FOR UPDATE
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
)
WITH CHECK (
  updated_by = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.users AS actor
    WHERE actor.id = (SELECT auth.uid())
      AND actor.role IN (
        'support'::public.user_role,
        'admin'::public.user_role
      )
  )
);

CREATE POLICY risk_report_events_staff_select
ON public.risk_report_events
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
);

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
BEGIN
  SELECT role INTO actor_role
  FROM public.users
  WHERE id = actor_id;

  IF actor_role IS NULL OR actor_role NOT IN (
    'support'::public.user_role,
    'admin'::public.user_role
  ) THEN
    RAISE EXCEPTION 'Only Support or Admin can manage risk reports'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.assigned_to IS NOT NULL THEN
    SELECT role INTO assignee_role
    FROM public.users
    WHERE id = NEW.assigned_to;

    IF assignee_role IS NULL OR assignee_role NOT IN (
      'support'::public.user_role,
      'admin'::public.user_role
    ) THEN
      RAISE EXCEPTION 'Risk report assignee must be Support or Admin'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.reported_by := actor_id;
    NEW.updated_by := actor_id;
    NEW.created_at := now();
    NEW.updated_at := now();
    RETURN NEW;
  END IF;

  IF NEW.order_id IS DISTINCT FROM OLD.order_id
    OR NEW.reported_by IS DISTINCT FROM OLD.reported_by
    OR NEW.source IS DISTINCT FROM OLD.source THEN
    RAISE EXCEPTION 'Order, reporter and source cannot be changed'
      USING ERRCODE = '23514';
  END IF;

  IF OLD.severity = 'critical'
    AND NEW.severity IS DISTINCT FROM OLD.severity
    AND actor_role <> 'admin'::public.user_role THEN
    RAISE EXCEPTION 'Only Admin can change critical severity'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT (
      (OLD.status = 'open' AND NEW.status IN ('investigating', 'dismissed'))
      OR (OLD.status = 'investigating'
        AND NEW.status IN ('action_required', 'resolved', 'dismissed'))
      OR (OLD.status = 'action_required'
        AND NEW.status IN ('investigating', 'resolved', 'dismissed'))
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

CREATE OR REPLACE FUNCTION private.record_risk_report_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  event_name text;
  event_details jsonb;
BEGIN
  IF TG_OP = 'INSERT' THEN
    event_name := 'created';
    event_details := jsonb_build_object(
      'category', NEW.category,
      'severity', NEW.severity,
      'assigned_to', NEW.assigned_to
    );
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    event_name := 'status_changed';
    event_details := jsonb_build_object(
      'severity', NEW.severity,
      'assigned_to', NEW.assigned_to
    );
  ELSIF NEW.assigned_to IS DISTINCT FROM OLD.assigned_to THEN
    event_name := 'assigned';
    event_details := jsonb_build_object(
      'from', OLD.assigned_to,
      'to', NEW.assigned_to
    );
  ELSE
    event_name := 'updated';
    event_details := jsonb_build_object(
      'category', NEW.category,
      'severity', NEW.severity
    );
  END IF;

  INSERT INTO public.risk_report_events (
    risk_report_id,
    actor_id,
    event_type,
    from_status,
    to_status,
    note,
    details
  ) VALUES (
    NEW.id,
    (SELECT auth.uid()),
    event_name,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE OLD.status END,
    NEW.status,
    CASE
      WHEN NEW.status IN ('resolved', 'dismissed') THEN NEW.resolution
      ELSE NULL
    END,
    event_details
  );

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.validate_risk_report_write() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.record_risk_report_event() FROM PUBLIC;

CREATE TRIGGER risk_reports_validate_write
BEFORE INSERT OR UPDATE ON public.risk_reports
FOR EACH ROW EXECUTE FUNCTION private.validate_risk_report_write();

CREATE TRIGGER risk_reports_record_event
AFTER INSERT OR UPDATE ON public.risk_reports
FOR EACH ROW EXECUTE FUNCTION private.record_risk_report_event();

COMMENT ON TABLE public.risk_reports IS
  'Order-linked operational risk reports managed by Support and Admin.';
COMMENT ON TABLE public.risk_report_events IS
  'Immutable audit history for risk report changes.';
