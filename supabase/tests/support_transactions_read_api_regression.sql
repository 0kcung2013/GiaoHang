-- Run as postgres after the staff read API migration. No business writes.
BEGIN READ ONLY;
DO $test$
DECLARE
  actors jsonb;
  actor jsonb;
  tab text;
  result jsonb;
  seen jsonb;
  item jsonb;
  cursor_time timestamptz;
  cursor_key text;
  expected bigint;
  total bigint;
  staff_checked integer := 0;
  public_signature text := 'public.list_support_transactions(text,text,text,timestamptz,timestamptz,timestamptz,text,integer)';
BEGIN
  IF has_function_privilege('anon',public_signature,'EXECUTE') THEN
    RAISE EXCEPTION 'Anon unexpectedly has transaction API access';
  END IF;
  SELECT jsonb_agg(jsonb_build_object('id',id,'role',role)) INTO actors
    FROM public.users WHERE role IN ('support','admin','customer','driver');
  IF actors IS NULL THEN RAISE EXCEPTION 'No actors for transaction API regression'; END IF;
  FOR actor IN SELECT value FROM jsonb_array_elements(actors) LOOP
    PERFORM set_config('request.jwt.claims',jsonb_build_object(
      'sub',actor->>'id','role','authenticated')::text,true);
    IF actor->>'role' NOT IN ('support','admin') THEN
      SET LOCAL ROLE authenticated;
      BEGIN
        PERFORM public.list_support_transactions();
        RAISE EXCEPTION 'Non-staff transaction access succeeded';
      EXCEPTION WHEN insufficient_privilege THEN NULL;
      END;
      RESET ROLE;
      CONTINUE;
    END IF;
    staff_checked := staff_checked+1;
    FOREACH tab IN ARRAY ARRAY['topups','payments','refunds'] LOOP
      IF tab='topups' THEN
        SELECT count(*) INTO expected FROM public.driver_wallet_transactions WHERE transaction_type='vnpay_topup';
      ELSIF tab='payments' THEN
        SELECT (SELECT count(*) FROM public.order_payment_sessions)+
          (SELECT count(*) FROM public.customer_wallet_transactions WHERE transaction_type='delivery_fee_payment') INTO expected;
      ELSE
        SELECT (SELECT count(*) FROM public.driver_wallet_transactions WHERE transaction_type='cod_release')+
          (SELECT count(*) FROM public.customer_wallet_transactions WHERE transaction_type='delivery_fee_refund')+
          (SELECT count(*) FROM public.order_payment_sessions WHERE status IN ('refund_required','refunded')) INTO expected;
      END IF;
      total:=0; cursor_time:=NULL; cursor_key:=NULL; seen:='{}'::jsonb;
      SET LOCAL ROLE authenticated;
      LOOP
        -- Small page size exercises live pagination even on a modest ledger.
        result:=public.list_support_transactions(p_group=>tab,p_limit=>2,
          p_before_created_at=>cursor_time,p_before_key=>cursor_key);
        FOR item IN SELECT value FROM jsonb_array_elements(result->'rows') LOOP
          IF seen ? (item->>'record_key') THEN RAISE EXCEPTION 'Duplicate transaction cursor'; END IF;
          IF item ? 'metadata' OR item ? 'order_payload' THEN RAISE EXCEPTION 'Unneeded payload exposed'; END IF;
          seen:=seen||jsonb_build_object(item->>'record_key',true);
          total:=total+1;
        END LOOP;
        EXIT WHEN NOT (result->>'has_more')::boolean;
        IF jsonb_array_length(result->'rows')=0 THEN RAISE EXCEPTION 'Empty cursor page'; END IF;
        cursor_time:=(result->'rows'->-1->>'created_at')::timestamptz;
        cursor_key:=result->'rows'->-1->>'record_key';
      END LOOP;
      RESET ROLE;
      IF total<>expected THEN RAISE EXCEPTION 'Transaction count mismatch for %: %/%',tab,total,expected; END IF;
    END LOOP;
  END LOOP;
  IF staff_checked<2 THEN RAISE EXCEPTION 'Need support and admin coverage'; END IF;
END;
$test$;
ROLLBACK;
SELECT 'support transaction API regression passed' AS result;
