-- Reviewable backend proposal. No new tables, columns, RLS or payment mutations.
-- Apply as a migration only after separate approval under AGENTS.md.
CREATE OR REPLACE FUNCTION private.lock_customer_classification()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $fn$
BEGIN
  IF OLD.customer_type IS NOT NULL AND
    ROW(NEW.customer_type,NEW.business_name,NEW.business_address,NEW.business_tax_code)
      IS DISTINCT FROM
    ROW(OLD.customer_type,OLD.business_name,OLD.business_address,OLD.business_tax_code) THEN
    RAISE EXCEPTION 'CUSTOMER_CLASSIFICATION_LOCKED' USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END;
$fn$;
REVOKE ALL ON FUNCTION private.lock_customer_classification() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER users_lock_customer_classification BEFORE UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION private.lock_customer_classification();

-- Keep the original directory RPC intact for older clients.
CREATE FUNCTION private.list_staff_accounts_v2(
  p_search text DEFAULT '',p_role text DEFAULT NULL,p_disabled_only boolean DEFAULT false,
  p_offset integer DEFAULT 0,p_limit integer DEFAULT 30,p_customer_type text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE actor uuid:=private.account_control_staff(); v_actor_role text; result jsonb;
  search_text text:=lower(btrim(COALESCE(p_search,'')));
BEGIN
  SELECT role::text INTO v_actor_role FROM public.users WHERE id=actor;
  IF char_length(search_text)>120 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
    OR p_offset IS NULL OR p_offset<0 OR p_disabled_only IS NULL
    OR(p_role IS NOT NULL AND p_role NOT IN('customer','driver','support','admin'))
    OR(p_customer_type IS NOT NULL AND p_customer_type NOT IN('individual','business','unclassified')) THEN
    RAISE EXCEPTION 'ACCOUNT_FILTER_INVALID' USING ERRCODE='22023';
  END IF;
  WITH entries AS (
    SELECT u.id,u.full_name,u.email,u.phone,u.role::text,u.created_at,
      u.customer_type,u.business_name,u.business_address,u.business_tax_code,e.id event_id,
      COALESCE(a.banned_until>statement_timestamp(),false) disabled,
      CASE WHEN a.banned_until>statement_timestamp() THEN
        CASE WHEN e.id IS NOT NULL AND e.action<>'release' THEN e.disabled_until
          ELSE a.banned_until END END disabled_until,
      e.reason,staff.full_name actor_name,e.created_at decided_at,
      (SELECT count(*) FROM public.orders o WHERE(o.customer_id=u.id OR o.driver_id=u.id)
        AND o.status IN('pending','confirmed','assigned','picking_up','delivering','risk_hold','return_approved','returning')) active_orders
    FROM public.users u JOIN auth.users a ON a.id=u.id
    LEFT JOIN LATERAL(SELECT * FROM public.account_control_events ce WHERE ce.user_id=u.id
      ORDER BY ce.event_seq DESC LIMIT 1)e ON true
    LEFT JOIN public.users staff ON staff.id=e.actor_id
    WHERE(v_actor_role='admin' OR u.role IN('customer','driver'))
      AND(p_role IS NULL OR u.role::text=p_role)
      AND(p_customer_type IS NULL OR(u.role='customer' AND
        (u.customer_type=p_customer_type OR(p_customer_type='unclassified' AND u.customer_type IS NULL))))
      AND(NOT p_disabled_only OR a.banned_until>statement_timestamp())
      AND(search_text='' OR strpos(lower(concat_ws(' ',u.full_name,u.email,u.phone,u.id::text,
        u.business_name,u.business_tax_code)),search_text)>0)
    ORDER BY u.created_at DESC,u.id LIMIT p_limit+1 OFFSET p_offset
  ), page AS(SELECT * FROM entries ORDER BY created_at DESC,id LIMIT p_limit)
  SELECT jsonb_build_object('rows',COALESCE((SELECT jsonb_agg(to_jsonb(page) ORDER BY created_at DESC,id) FROM page),'[]'::jsonb),
    'has_more',(SELECT count(*)>p_limit FROM entries),'server_now',statement_timestamp()) INTO result;
  RETURN result;
END;
$fn$;
CREATE FUNCTION public.list_staff_accounts_v2(
  p_search text DEFAULT '',p_role text DEFAULT NULL,p_disabled_only boolean DEFAULT false,
  p_offset integer DEFAULT 0,p_limit integer DEFAULT 30,p_customer_type text DEFAULT NULL
) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $fn$
  SELECT private.list_staff_accounts_v2(p_search,p_role,p_disabled_only,p_offset,p_limit,p_customer_type);
$fn$;
REVOKE ALL ON FUNCTION private.list_staff_accounts_v2(text,text,boolean,integer,integer,text),
  public.list_staff_accounts_v2(text,text,boolean,integer,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.list_staff_accounts_v2(text,text,boolean,integer,integer,text),
  public.list_staff_accounts_v2(text,text,boolean,integer,integer,text) TO authenticated;

-- A single database snapshot for display and export. Vietnam calendar boundaries
-- are passed as UTC instants; exclusive end. Reject oversized reports, never truncate.
CREATE FUNCTION private.get_customer_business_report(p_customer_id uuid,p_start timestamptz,p_end timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
DECLARE actor uuid:=auth.uid(); profile jsonb; result jsonb;
BEGIN
  IF actor IS NULL OR NOT private.account_enabled(actor) THEN
    RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.users u WHERE u.id=actor AND
    (u.role IN('support','admin') OR(u.role='customer' AND actor=p_customer_id))) THEN
    RAISE EXCEPTION 'BUSINESS_REPORT_FORBIDDEN' USING ERRCODE='42501';
  END IF;
  IF p_start IS NULL OR p_end IS NULL OR p_start>=p_end OR p_end-p_start>interval '366 days' THEN
    RAISE EXCEPTION 'BUSINESS_REPORT_RANGE_INVALID' USING ERRCODE='22023';
  END IF;
  SELECT jsonb_build_object('id',id,'business_name',business_name,'business_address',business_address,
    'business_tax_code',business_tax_code) INTO profile FROM public.users
    WHERE id=p_customer_id AND role='customer' AND customer_type='business';
  IF profile IS NULL THEN RAISE EXCEPTION 'BUSINESS_PROFILE_REQUIRED' USING ERRCODE='42501'; END IF;
  WITH orders_in_period AS (
    SELECT o.id,o.tracking_code,o.status::text,o.delivery_fee_payer,o.payment_status,
      o.cod_collection_amount,o.delivery_fee,o.customer_platform_fee_amount,
      CASE o.status WHEN 'delivered' THEN o.actual_delivered_at
        WHEN 'returned' THEN r.returned_at WHEN 'cancelled' THEN o.cancelled_at END event_at,
      COALESCE(r.customer_return_charge,0) return_charge,r.fee_status return_fee_status
    FROM public.orders o LEFT JOIN public.order_returns r ON r.order_id=o.id AND r.status='returned'
    WHERE o.customer_id=p_customer_id AND
      (CASE o.status WHEN 'delivered' THEN o.actual_delivered_at
        WHEN 'returned' THEN r.returned_at WHEN 'cancelled' THEN o.cancelled_at END)>=p_start
      AND(CASE o.status WHEN 'delivered' THEN o.actual_delivered_at
        WHEN 'returned' THEN r.returned_at WHEN 'cancelled' THEN o.cancelled_at END)<p_end
    ORDER BY event_at,id LIMIT 5001
  ), movements AS (
    SELECT 'wallet:'||t.id::text id,t.order_id,o.tracking_code,
      t.transaction_type kind,t.available_delta amount,t.completed_at event_at,
      t.metadata->>'payment_state' payment_state
    FROM public.customer_wallet_transactions t LEFT JOIN public.orders o ON o.id=t.order_id
    WHERE t.customer_id=p_customer_id AND t.status='completed'
      AND t.completed_at>=p_start AND t.completed_at<p_end
    UNION ALL
    SELECT 'vnpay:'||s.id::text,s.order_id,o.tracking_code,'vnpay_payment',-s.amount,s.paid_at,s.status
    FROM public.order_payment_sessions s LEFT JOIN public.orders o ON o.id=s.order_id
    WHERE s.customer_id=p_customer_id AND s.provider='vnpay' AND s.paid_at IS NOT NULL
      AND s.status IN('paid','refunded','refund_required') AND s.paid_at>=p_start AND s.paid_at<p_end
  ), movement_page AS(SELECT * FROM movements ORDER BY event_at,id LIMIT 5001)
  SELECT jsonb_build_object('profile',profile,'start',p_start,'end',p_end,'generated_at',statement_timestamp(),
    'orders',COALESCE((SELECT jsonb_agg(to_jsonb(o) ORDER BY event_at,id) FROM orders_in_period o),'[]'::jsonb),
    'movements',COALESCE((SELECT jsonb_agg(to_jsonb(m) ORDER BY event_at,id) FROM movement_page m),'[]'::jsonb)) INTO result;
  IF jsonb_array_length(result->'orders')>5000 OR jsonb_array_length(result->'movements')>5000 THEN
    RAISE EXCEPTION 'BUSINESS_REPORT_TOO_LARGE' USING ERRCODE='54000';
  END IF;
  RETURN result;
END;
$fn$;
CREATE FUNCTION public.get_customer_business_report(p_customer_id uuid,p_start timestamptz,p_end timestamptz)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $fn$
  SELECT private.get_customer_business_report(p_customer_id,p_start,p_end);
$fn$;
REVOKE ALL ON FUNCTION private.get_customer_business_report(uuid,timestamptz,timestamptz),
  public.get_customer_business_report(uuid,timestamptz,timestamptz) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.get_customer_business_report(uuid,timestamptz,timestamptz),
  public.get_customer_business_report(uuid,timestamptz,timestamptz) TO authenticated;
