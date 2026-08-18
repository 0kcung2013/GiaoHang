DROP FUNCTION public.create_customer_order_payment_session(jsonb, text);

CREATE FUNCTION public.create_customer_order_payment_session(
  p_customer_id uuid,
  p_order_payload jsonb,
  p_txn_ref text
)
RETURNS TABLE(
  session_id uuid,
  txn_ref text,
  amount bigint,
  status text,
  expires_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_session public.order_payment_sessions%ROWTYPE;
  v_amount bigint;
  v_fee_payer text;
  v_cod_amount bigint;
  v_goods_value bigint;
BEGIN
  IF p_customer_id IS NULL THEN RAISE EXCEPTION 'CUSTOMER_ID_REQUIRED'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users app_user
    WHERE app_user.id = p_customer_id
      AND app_user.role = 'customer'::public.user_role
  ) THEN RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED'; END IF;
  IF p_order_payload IS NULL OR jsonb_typeof(p_order_payload) <> 'object' THEN
    RAISE EXCEPTION 'ORDER_PAYLOAD_INVALID';
  END IF;
  IF NULLIF(btrim(p_txn_ref), '') IS NULL THEN
    RAISE EXCEPTION 'PAYMENT_TXN_REF_REQUIRED';
  END IF;

  BEGIN
    v_amount := round((p_order_payload->>'delivery_fee')::numeric)::bigint;
    v_cod_amount := round(COALESCE(
      NULLIF(p_order_payload->>'cod_collection_amount', '')::numeric, 0
    ))::bigint;
    v_goods_value := round(COALESCE(
      NULLIF(p_order_payload->>'goods_value', '')::numeric, 0
    ))::bigint;
    PERFORM (p_order_payload->>'pickup_lat')::double precision;
    PERFORM (p_order_payload->>'pickup_lng')::double precision;
    PERFORM (p_order_payload->>'delivery_lat')::double precision;
    PERFORM (p_order_payload->>'delivery_lng')::double precision;
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RAISE EXCEPTION 'ORDER_PAYLOAD_INVALID';
  END;

  v_fee_payer := lower(COALESCE(
    NULLIF(btrim(p_order_payload->>'delivery_fee_payer'), ''), 'recipient'
  ));
  IF v_fee_payer <> 'sender' THEN RAISE EXCEPTION 'VNPAY_PAYMENT_NOT_REQUIRED'; END IF;
  IF NULLIF(btrim(p_order_payload->>'pickup_address'), '') IS NULL
     OR NULLIF(btrim(p_order_payload->>'delivery_address'), '') IS NULL THEN
    RAISE EXCEPTION 'ORDER_ADDRESS_REQUIRED';
  END IF;
  IF NULLIF(btrim(p_order_payload->>'pickup_lat'), '') IS NULL
     OR NULLIF(btrim(p_order_payload->>'pickup_lng'), '') IS NULL
     OR NULLIF(btrim(p_order_payload->>'delivery_lat'), '') IS NULL
     OR NULLIF(btrim(p_order_payload->>'delivery_lng'), '') IS NULL THEN
    RAISE EXCEPTION 'ORDER_COORDINATES_REQUIRED';
  END IF;
  IF v_amount IS NULL
     OR v_amount < 5000 OR v_amount > 10000000
     OR v_cod_amount < 0 OR v_cod_amount > 10000000
     OR v_goods_value < 0 OR v_goods_value > 100000000 THEN
    RAISE EXCEPTION 'ORDER_PRICE_INVALID';
  END IF;

  INSERT INTO public.order_payment_sessions (
    customer_id, provider_txn_ref, amount, status,
    order_payload, expires_at
  ) VALUES (
    p_customer_id, btrim(p_txn_ref), v_amount, 'pending',
    p_order_payload || jsonb_build_object('delivery_fee_payer', 'sender'),
    clock_timestamp() + interval '15 minutes'
  ) RETURNING * INTO v_session;

  RETURN QUERY SELECT v_session.id, v_session.provider_txn_ref,
    v_session.amount, v_session.status, v_session.expires_at;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_customer_order_payment_session(
  uuid, jsonb, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_customer_order_payment_session(
  uuid, jsonb, text
) TO service_role;
