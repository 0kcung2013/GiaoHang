-- Đã được người dùng duyệt riêng ngày 2026-10-21. Chờ áp dụng.
-- Một nhật ký độc lập cho vô hiệu hóa tài khoản; không liên quan khóa nhận đơn.
CREATE TABLE public.account_control_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_seq bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  request_id uuid NOT NULL UNIQUE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  action text NOT NULL CHECK (action IN ('disable','adjust','release')),
  disabled_until timestamptz,
  reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 10 AND 1000),
  actor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  actor_role text NOT NULL CHECK (actor_role IN ('support','admin')),
  previous_event_id uuid REFERENCES public.account_control_events(id),
  previous_disabled_until timestamptz,
  risk_report_id uuid REFERENCES public.risk_reports(id) ON DELETE RESTRICT,
  ticket_id uuid REFERENCES public.support_tickets(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (action<>'release' OR disabled_until IS NULL)
);
CREATE INDEX account_control_events_user_latest ON public.account_control_events(user_id,event_seq DESC);
ALTER TABLE public.account_control_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.account_control_events FROM PUBLIC,anon,authenticated;
REVOKE ALL ON SEQUENCE public.account_control_events_event_seq_seq FROM PUBLIC,anon,authenticated;

CREATE FUNCTION private.account_control_immutable() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $fn$
BEGIN RAISE EXCEPTION 'ACCOUNT_CONTROL_APPEND_ONLY' USING ERRCODE='42501'; END;
$fn$;
CREATE TRIGGER account_control_append_only BEFORE UPDATE OR DELETE ON public.account_control_events
FOR EACH ROW EXECUTE FUNCTION private.account_control_immutable();

CREATE FUNCTION private.account_enabled(p_user_id uuid DEFAULT auth.uid()) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
  SELECT NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=p_user_id
    AND u.banned_until>statement_timestamp())
    AND (NOT EXISTS(SELECT 1 FROM public.account_control_events e WHERE e.user_id=p_user_id)
      OR EXISTS(SELECT 1 FROM auth.sessions s WHERE s.user_id=p_user_id
        AND s.id=NULLIF(auth.jwt()->>'session_id','')::uuid));
$fn$;
REVOKE ALL ON FUNCTION private.account_enabled(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.account_enabled(uuid) TO authenticated;

CREATE FUNCTION private.account_control_staff() RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE actor uuid:=auth.uid();
BEGIN
  IF actor IS NULL OR NOT private.account_enabled(actor) OR NOT EXISTS(
    SELECT 1 FROM public.users u WHERE u.id=actor AND u.role IN('support','admin')) THEN
    RAISE EXCEPTION 'STAFF_REQUIRED' USING ERRCODE='42501';
  END IF;
  RETURN actor;
END;
$fn$;

CREATE FUNCTION private.set_account_control(
  p_user_id uuid,p_action text,p_reason text,p_request_id uuid,
  p_duration_minutes integer DEFAULT NULL,p_expected_event_id uuid DEFAULT NULL,
  p_risk_report_id uuid DEFAULT NULL,p_ticket_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE
  actor uuid:=private.account_control_staff(); actor_role text;
  subject_role text; previous public.account_control_events%ROWTYPE;
  receipt public.account_control_events%ROWTYPE; native_until timestamptz;
  next_until timestamptz; normalized_reason text:=btrim(COALESCE(p_reason,''));
  server_time timestamptz;
BEGIN
  SELECT role::text INTO actor_role FROM public.users WHERE id=actor;
  IF p_user_id IS NULL OR p_user_id=actor OR p_request_id IS NULL
    OR p_action IS NULL OR p_action NOT IN('disable','adjust','release')
    OR char_length(normalized_reason) NOT BETWEEN 10 AND 1000
    OR (p_duration_minutes IS NOT NULL AND p_duration_minutes NOT IN(30,60,1440,4320,10080,43200))
    OR (p_action='release' AND p_duration_minutes IS NOT NULL) THEN
    RAISE EXCEPTION 'ACCOUNT_CONTROL_INVALID' USING ERRCODE='22023';
  END IF;
  -- One account row serializes two staff decisions, including a first decision.
  SELECT role::text INTO subject_role FROM public.users WHERE id=p_user_id FOR UPDATE;
  IF subject_role IS NULL OR subject_role NOT IN('customer','driver') THEN
    RAISE EXCEPTION 'ACCOUNT_TARGET_NOT_ALLOWED' USING ERRCODE='42501';
  END IF;
  SELECT banned_until INTO native_until FROM auth.users WHERE id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ACCOUNT_AUTH_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  server_time:=clock_timestamp();
  SELECT * INTO receipt FROM public.account_control_events WHERE request_id=p_request_id;
  IF FOUND THEN
    IF receipt.user_id<>p_user_id OR receipt.actor_id<>actor OR receipt.action<>p_action
      OR receipt.reason<>normalized_reason
      OR receipt.previous_event_id IS DISTINCT FROM p_expected_event_id
      OR receipt.risk_report_id IS DISTINCT FROM p_risk_report_id
      OR receipt.ticket_id IS DISTINCT FROM p_ticket_id
      OR (p_action<>'release' AND (
        (p_duration_minutes IS NULL)<>(receipt.disabled_until IS NULL)
        OR (p_duration_minutes IS NOT NULL AND receipt.disabled_until IS DISTINCT FROM
          receipt.created_at+make_interval(mins=>p_duration_minutes)))) THEN
      RAISE EXCEPTION 'ACCOUNT_REQUEST_REUSED' USING ERRCODE='22023';
    END IF;
    RETURN jsonb_build_object('event_id',receipt.id,'user_id',receipt.user_id,'request_id',receipt.request_id,'action',receipt.action,
      'disabled_until',receipt.disabled_until,'already_applied',true,'server_now',clock_timestamp());
  END IF;
  SELECT * INTO previous FROM public.account_control_events
    WHERE user_id=p_user_id ORDER BY event_seq DESC LIMIT 1;
  IF previous.id IS DISTINCT FROM p_expected_event_id THEN
    RAISE EXCEPTION 'ACCOUNT_CONTROL_CHANGED' USING ERRCODE='40001';
  END IF;
  IF p_action IN('adjust','release') AND actor_role<>'admin' THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_action='disable' AND native_until>server_time THEN
    RAISE EXCEPTION 'ACCOUNT_ALREADY_DISABLED' USING ERRCODE='23514';
  END IF;
  IF p_action IN('adjust','release') AND NOT COALESCE(native_until>server_time,false) THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_DISABLED' USING ERRCODE='23514';
  END IF;
  IF p_risk_report_id IS NOT NULL AND NOT EXISTS(
    SELECT 1 FROM public.risk_reports r LEFT JOIN public.orders o ON o.id=r.order_id
    WHERE r.id=p_risk_report_id AND (r.reported_by=p_user_id OR o.customer_id=p_user_id OR o.driver_id=p_user_id)
  ) THEN RAISE EXCEPTION 'ACCOUNT_CASE_NOT_RELATED' USING ERRCODE='22023'; END IF;
  IF p_ticket_id IS NOT NULL AND NOT EXISTS(
    SELECT 1 FROM public.support_tickets t LEFT JOIN public.orders o ON o.id=t.order_id
    WHERE t.id=p_ticket_id AND (t.requester_id=p_user_id OR o.customer_id=p_user_id OR o.driver_id=p_user_id)
  ) THEN RAISE EXCEPTION 'ACCOUNT_CASE_NOT_RELATED' USING ERRCODE='22023'; END IF;
  IF p_action<>'release' AND p_duration_minutes IS NOT NULL THEN
    next_until:=server_time+make_interval(mins=>p_duration_minutes);
  END IF;
  INSERT INTO public.account_control_events(request_id,user_id,action,disabled_until,reason,
    actor_id,actor_role,previous_event_id,previous_disabled_until,risk_report_id,ticket_id,created_at)
  VALUES(p_request_id,p_user_id,p_action,next_until,normalized_reason,actor,actor_role,
    previous.id,native_until,p_risk_report_id,p_ticket_id,server_time) RETURNING * INTO receipt;
  UPDATE auth.users SET banned_until=CASE WHEN p_action='release' THEN NULL
    ELSE COALESCE(next_until,'9999-12-31 00:00:00+00'::timestamptz) END WHERE id=p_user_id;
  IF p_action<>'release' THEN
    -- Native Auth rejects this user. Revocation also blocks pre-existing JWTs at /auth/v1/user.
    DELETE FROM auth.sessions WHERE user_id=p_user_id;
    UPDATE public.users SET active_session_id=NULL,active_session_updated_at=server_time WHERE id=p_user_id;
  END IF;
  RETURN jsonb_build_object('event_id',receipt.id,'user_id',receipt.user_id,'request_id',receipt.request_id,'action',receipt.action,
    'disabled_until',receipt.disabled_until,'already_applied',false,'server_now',clock_timestamp());
END;
$fn$;

CREATE FUNCTION public.set_account_control(
  p_user_id uuid,p_action text,p_reason text,p_request_id uuid,
  p_duration_minutes integer DEFAULT NULL,p_expected_event_id uuid DEFAULT NULL,
  p_risk_report_id uuid DEFAULT NULL,p_ticket_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $fn$
  SELECT private.set_account_control(p_user_id,p_action,p_reason,p_request_id,p_duration_minutes,
    p_expected_event_id,p_risk_report_id,p_ticket_id);
$fn$;

CREATE FUNCTION private.list_staff_accounts(
  p_search text DEFAULT '',p_role text DEFAULT NULL,p_disabled_only boolean DEFAULT false,
  p_offset integer DEFAULT 0,p_limit integer DEFAULT 30
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE actor uuid:=private.account_control_staff(); v_actor_role text; result jsonb;
  search_text text:=lower(btrim(COALESCE(p_search,'')));
BEGIN
  SELECT role::text INTO v_actor_role FROM public.users WHERE id=actor;
  IF char_length(search_text)>120 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
    OR p_offset IS NULL OR p_offset<0 OR p_disabled_only IS NULL
    OR(p_role IS NOT NULL AND p_role NOT IN('customer','driver','support','admin')) THEN
    RAISE EXCEPTION 'ACCOUNT_FILTER_INVALID' USING ERRCODE='22023';
  END IF;
  WITH entries AS (
    SELECT u.id,u.full_name,u.email,u.phone,u.role::text,u.created_at,e.id event_id,
      COALESCE(a.banned_until>statement_timestamp(),false) disabled,
      CASE WHEN a.banned_until>statement_timestamp() THEN
        CASE WHEN e.id IS NOT NULL AND e.action<>'release' THEN e.disabled_until
          ELSE a.banned_until END END disabled_until,
      e.reason,e.actor_id,e.actor_role,staff.full_name actor_name,e.created_at decided_at,
      (SELECT count(*) FROM public.orders o WHERE(o.customer_id=u.id OR o.driver_id=u.id)
        AND o.status IN('pending','confirmed','assigned','picking_up','delivering','risk_hold','return_approved','returning')) active_orders
    FROM public.users u JOIN auth.users a ON a.id=u.id
    LEFT JOIN LATERAL(SELECT * FROM public.account_control_events ce WHERE ce.user_id=u.id
      ORDER BY ce.event_seq DESC LIMIT 1)e ON true
    LEFT JOIN public.users staff ON staff.id=e.actor_id
    WHERE(v_actor_role='admin' OR u.role IN('customer','driver'))
      AND(p_role IS NULL OR u.role::text=p_role)
      AND(NOT p_disabled_only OR a.banned_until>statement_timestamp())
      AND(search_text='' OR strpos(lower(concat_ws(' ',u.full_name,u.email,u.phone,u.id::text)),search_text)>0)
    ORDER BY u.created_at DESC,u.id LIMIT p_limit+1 OFFSET p_offset
  ), page AS(SELECT * FROM entries ORDER BY created_at DESC,id LIMIT p_limit)
  SELECT jsonb_build_object('rows',COALESCE((SELECT jsonb_agg(to_jsonb(page) ORDER BY created_at DESC,id) FROM page),'[]'::jsonb),
    'has_more',(SELECT count(*)>p_limit FROM entries),'server_now',statement_timestamp()) INTO result;
  RETURN result;
END;
$fn$;
CREATE FUNCTION public.list_staff_accounts(
  p_search text DEFAULT '',p_role text DEFAULT NULL,p_disabled_only boolean DEFAULT false,
  p_offset integer DEFAULT 0,p_limit integer DEFAULT 30
) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $fn$
  SELECT private.list_staff_accounts(p_search,p_role,p_disabled_only,p_offset,p_limit);
$fn$;

CREATE FUNCTION private.account_control_history(p_user_id uuid,p_before_seq bigint DEFAULT NULL,p_limit integer DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE actor uuid:=private.account_control_staff(); result jsonb;
BEGIN
  IF p_user_id IS NULL OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
    OR(p_before_seq IS NOT NULL AND p_before_seq<1) THEN
    RAISE EXCEPTION 'ACCOUNT_FILTER_INVALID' USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.users u WHERE u.id=p_user_id
    AND(u.role IN('customer','driver') OR EXISTS(SELECT 1 FROM public.users a WHERE a.id=actor AND a.role='admin'))) THEN
    RAISE EXCEPTION 'ACCOUNT_TARGET_NOT_ALLOWED' USING ERRCODE='42501';
  END IF;
  WITH entries AS(SELECT e.id,e.event_seq,e.action,e.disabled_until,e.reason,e.actor_id,
    e.actor_role,a.full_name actor_name,e.previous_event_id,e.risk_report_id,e.ticket_id,e.created_at
    FROM public.account_control_events e JOIN public.users a ON a.id=e.actor_id
    WHERE e.user_id=p_user_id AND(p_before_seq IS NULL OR e.event_seq<p_before_seq)
    ORDER BY e.event_seq DESC LIMIT p_limit+1),
  page AS(SELECT * FROM entries ORDER BY event_seq DESC LIMIT p_limit)
  SELECT jsonb_build_object('rows',COALESCE((SELECT jsonb_agg(to_jsonb(page) ORDER BY event_seq DESC) FROM page),'[]'::jsonb),
    'has_more',(SELECT count(*)>p_limit FROM entries),'server_now',statement_timestamp()) INTO result;
  RETURN result;
END;
$fn$;
CREATE FUNCTION public.account_control_history(p_user_id uuid,p_before_seq bigint DEFAULT NULL,p_limit integer DEFAULT 30)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $fn$
 SELECT private.account_control_history(p_user_id,p_before_seq,p_limit);
$fn$;

CREATE FUNCTION private.disabled_account_count() RETURNS bigint
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
  PERFORM private.account_control_staff();
  RETURN(SELECT count(*) FROM public.users u JOIN auth.users a ON a.id=u.id
    WHERE u.role IN('customer','driver') AND a.banned_until>statement_timestamp());
END;
$fn$;
CREATE FUNCTION public.disabled_account_count() RETURNS bigint
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $fn$
 SELECT private.disabled_account_count();
$fn$;

-- All existing business RLS remains. A restrictive predicate adds account-state enforcement.
DO $policies$
DECLARE target text;
BEGIN
  FOREACH target IN ARRAY ARRAY['orders','order_items','order_status_logs','order_messages','order_message_reads',
    'risk_reports','risk_report_events','risk_report_evidence','risk_report_interventions','order_returns',
    'support_tickets','case_messages','reviews','notifications','drivers','driver_profile_change_requests',
    'order_delivery_proofs','customer_wallet_transactions','driver_wallet_transactions','order_payment_sessions',
    'saved_addresses','recent_addresses'] LOOP
    EXECUTE format('CREATE POLICY account_enabled_required ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING((SELECT private.account_enabled())) WITH CHECK((SELECT private.account_enabled()))',target);
  END LOOP;
END;
$policies$;
-- Own-profile SELECT remains available to receive the existing logout signal over Realtime.
CREATE POLICY account_enabled_write_required ON public.users AS RESTRICTIVE FOR UPDATE TO authenticated
  USING((SELECT private.account_enabled())) WITH CHECK((SELECT private.account_enabled()));
CREATE POLICY account_enabled_storage_required ON storage.objects AS RESTRICTIVE FOR ALL TO authenticated
  USING((SELECT private.account_enabled())) WITH CHECK((SELECT private.account_enabled()));

CREATE FUNCTION public.require_enabled_account() RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE actor uuid:=auth.uid(); session uuid;
BEGIN
  IF actor IS NULL THEN RETURN; END IF;
  IF EXISTS(SELECT 1 FROM auth.users u WHERE u.id=actor AND u.banned_until>statement_timestamp()) THEN
    RAISE EXCEPTION 'ACCOUNT_DISABLED' USING ERRCODE='42501';
  END IF;
  -- A revoked pre-ban token cannot be reused after a timed ban expires or is lifted.
  IF EXISTS(SELECT 1 FROM public.account_control_events e WHERE e.user_id=actor) THEN
    session:=NULLIF(auth.jwt()->>'session_id','')::uuid;
    IF session IS NULL OR NOT EXISTS(SELECT 1 FROM auth.sessions s WHERE s.id=session AND s.user_id=actor) THEN
      RAISE EXCEPTION 'ACCOUNT_SESSION_REVOKED' USING ERRCODE='42501';
    END IF;
  END IF;
END;
$fn$;
ALTER ROLE authenticator SET pgrst.db_pre_request='public.require_enabled_account';
NOTIFY pgrst,'reload config';

DO $grants$
DECLARE f record;
BEGIN
  FOR f IN SELECT p.oid::regprocedure signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname IN('private','public') AND p.proname IN('account_control_staff','set_account_control',
      'list_staff_accounts','account_control_history','disabled_account_count','require_enabled_account') LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon',f.signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.signature);
  END LOOP;
END;
$grants$;
