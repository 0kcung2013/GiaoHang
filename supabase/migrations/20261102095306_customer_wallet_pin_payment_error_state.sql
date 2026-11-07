-- Keep successful PIN verification even if a business validation rejects debit.
-- The nested block rolls back all financial writes, without restoring a stale
-- wrong-PIN count from before the successful verification.
CREATE OR REPLACE FUNCTION private.create_customer_order_with_wallet(
  p_order_payload jsonb, p_request_id uuid, p_pin text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
DECLARE actor uuid := private.customer_wallet_pin_actor(); check_result jsonb;
  existing public.customer_wallet_transactions; result_order public.orders;
BEGIN
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'WALLET_REQUEST_ID_REQUIRED'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('customer-wallet:' || actor::text, 0));
  SELECT * INTO existing FROM public.customer_wallet_transactions
    WHERE customer_id = actor AND idempotency_key = 'customer:' || actor::text || ':delivery-payment:' || p_request_id::text;
  IF NOT FOUND THEN
    check_result := private.check_customer_wallet_pin(actor, p_pin);
    IF NOT (check_result->>'ok')::boolean THEN RETURN check_result; END IF;
  END IF;
  BEGIN
    SELECT * INTO result_order FROM private.create_customer_order_with_wallet_unchecked(p_order_payload, p_request_id);
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '22023' OR SQLERRM = 'CUSTOMER_WALLET_INSUFFICIENT_BALANCE' THEN
      RETURN jsonb_build_object('ok', false, 'error_kind', 'payment', 'code', SQLERRM, 'sqlstate', SQLSTATE);
    END IF;
    RAISE;
  END;
  RETURN jsonb_build_object('ok', true, 'order', to_jsonb(result_order));
END;
$fn$;
