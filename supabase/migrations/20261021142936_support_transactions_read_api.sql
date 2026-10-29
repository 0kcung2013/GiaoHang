-- Approved 2026-10-20: staff-only transaction lookup, read-only API.
-- No ledger writes, tables, RLS changes, balance changes or provider calls.
CREATE FUNCTION private.list_support_transactions(
  p_group text DEFAULT 'topups', p_search text DEFAULT '', p_status text DEFAULT 'all',
  p_from timestamptz DEFAULT NULL, p_to timestamptz DEFAULT NULL,
  p_before_created_at timestamptz DEFAULT NULL, p_before_key text DEFAULT NULL,
  p_limit integer DEFAULT 30
)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE
  v_rows jsonb;
  v_more boolean;
  v_search text := lower(btrim(COALESCE(p_search, '')));
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.users actor WHERE actor.id = auth.uid()
      AND actor.role IN ('support','admin')) THEN
    RAISE EXCEPTION 'SUPPORT_REQUIRED' USING ERRCODE = '42501';
  END IF;
  IF p_group IS NULL OR p_group NOT IN ('topups','payments','refunds')
    OR p_status IS NULL OR p_status NOT IN
      ('all','pending','completed','failed','expired','refund_required','refunded','reversed')
    OR length(v_search) > 120 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
    OR (p_from IS NOT NULL AND p_to IS NOT NULL AND p_from >= p_to)
    OR ((p_before_created_at IS NULL) <> (p_before_key IS NULL)) THEN
    RAISE EXCEPTION 'TRANSACTION_FILTER_INVALID' USING ERRCODE = '22023';
  END IF;
  WITH ledger AS (
    SELECT 'driver'::text source, t.id, t.driver_id user_id, t.order_id,
      t.transaction_type kind, t.status, t.amount, t.available_delta, t.held_delta,
      t.created_at, t.completed_at, NULL::timestamptz expires_at,
      t.provider_txn_ref, t.provider_transaction_no, t.provider_response_code,
      NULL::uuid risk_report_id, t.metadata->>'purpose' purpose,
      t.metadata->>'reason' reason, NULL::text payment_state
    FROM public.driver_wallet_transactions t
    WHERE (p_group='topups' AND t.transaction_type='vnpay_topup')
      OR (p_group='refunds' AND t.transaction_type='cod_release')
    UNION ALL
    SELECT 'customer', t.id, t.customer_id, t.order_id, t.transaction_type,
      t.status, t.amount, t.available_delta, 0::bigint,
      t.created_at, t.completed_at, NULL::timestamptz,
      NULL::text, NULL::text, NULL::text, t.risk_report_id,
      NULL::text, t.metadata->>'reason', t.metadata->>'payment_state'
    FROM public.customer_wallet_transactions t
    WHERE (p_group='payments' AND t.transaction_type='delivery_fee_payment')
      OR (p_group='refunds' AND t.transaction_type='delivery_fee_refund')
    UNION ALL
    SELECT 'vnpay', t.id, t.customer_id, t.order_id, 'order_payment',
      CASE WHEN t.status='paid' THEN 'completed' ELSE t.status END,
      t.amount, NULL::bigint, NULL::bigint, t.created_at, t.paid_at, t.expires_at,
      t.provider_txn_ref, t.provider_transaction_no, t.provider_response_code,
      NULL::uuid, NULL::text, NULL::text, NULL::text
    FROM public.order_payment_sessions t
    WHERE p_group='payments' OR (p_group='refunds' AND t.status IN ('refund_required','refunded'))
  ), matched AS (
    SELECT t.*, t.source || ':' || t.id::text record_key,
      owner.full_name user_name, owner.phone user_phone, owner.role::text user_role,
      delivery_order.tracking_code
    FROM ledger t
    JOIN public.users owner ON owner.id=t.user_id
    LEFT JOIN public.orders delivery_order ON delivery_order.id=t.order_id
    WHERE (p_status='all' OR t.status=p_status)
      AND (p_from IS NULL OR t.created_at>=p_from)
      AND (p_to IS NULL OR t.created_at<p_to)
      AND (v_search='' OR strpos(lower(concat_ws(' ', t.id::text,
        t.provider_txn_ref, t.provider_transaction_no, owner.full_name,
        owner.phone, t.user_id::text, delivery_order.tracking_code)),v_search)>0)
      AND (p_before_created_at IS NULL OR
        (t.created_at,t.source || ':' || t.id::text)<(p_before_created_at,p_before_key))
    ORDER BY t.created_at DESC, record_key DESC LIMIT p_limit+1
  ), page AS (
    SELECT * FROM matched ORDER BY created_at DESC, record_key DESC LIMIT p_limit
  )
  SELECT COALESCE((SELECT jsonb_agg(to_jsonb(page) ORDER BY created_at DESC,record_key DESC)
      FROM page),'[]'::jsonb), (SELECT count(*)>p_limit FROM matched)
  INTO v_rows,v_more;
  RETURN jsonb_build_object('rows',v_rows,'has_more',v_more,'server_now',now());
END;
$fn$;
REVOKE ALL ON FUNCTION private.list_support_transactions(text,text,text,timestamptz,timestamptz,timestamptz,text,integer)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.list_support_transactions(text,text,text,timestamptz,timestamptz,timestamptz,text,integer)
  TO authenticated;

CREATE FUNCTION public.list_support_transactions(
  p_group text DEFAULT 'topups', p_search text DEFAULT '', p_status text DEFAULT 'all',
  p_from timestamptz DEFAULT NULL, p_to timestamptz DEFAULT NULL,
  p_before_created_at timestamptz DEFAULT NULL, p_before_key text DEFAULT NULL,
  p_limit integer DEFAULT 30
)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $fn$
  SELECT private.list_support_transactions(p_group,p_search,p_status,p_from,p_to,
    p_before_created_at,p_before_key,p_limit);
$fn$;
REVOKE ALL ON FUNCTION public.list_support_transactions(text,text,text,timestamptz,timestamptz,timestamptz,text,integer)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.list_support_transactions(text,text,text,timestamptz,timestamptz,timestamptz,text,integer)
  TO authenticated;
