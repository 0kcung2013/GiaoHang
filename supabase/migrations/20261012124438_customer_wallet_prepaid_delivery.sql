-- Reuse the customer ledger and existing prepaid driver settlement.
-- No new tables, columns, RLS policies or payment provider are needed.
ALTER TABLE public.customer_wallet_transactions
  DROP CONSTRAINT customer_wallet_transactions_transaction_type_check;
ALTER TABLE public.customer_wallet_transactions
  ADD CONSTRAINT customer_wallet_transactions_transaction_type_check CHECK (
    transaction_type IN ('delivery_credit', 'failed_delivery_credit', 'risk_credit',
      'adjustment_credit', 'adjustment_debit', 'delivery_fee_payment', 'delivery_fee_refund')
  );

CREATE OR REPLACE FUNCTION public.create_customer_order_with_wallet(
  p_order_payload jsonb, p_request_id uuid
)
RETURNS public.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_customer_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_existing public.customer_wallet_transactions%ROWTYPE;
  v_payload jsonb;
  v_key text;
  v_amount bigint;
  v_balance bigint;
BEGIN
  IF v_customer_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_customer_id AND role = 'customer') THEN
    RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED';
  END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'WALLET_REQUEST_ID_REQUIRED'; END IF;
  IF p_order_payload IS NULL OR jsonb_typeof(p_order_payload) <> 'object' THEN
    RAISE EXCEPTION 'ORDER_PAYLOAD_INVALID';
  END IF;
  IF p_order_payload->>'delivery_fee_payer' IS DISTINCT FROM 'sender'
    OR COALESCE((p_order_payload->>'cod_collection_amount')::numeric, 0) <> 0 THEN
    RAISE EXCEPTION 'WALLET_PAYMENT_NOT_REQUIRED';
  END IF;
  v_payload := (p_order_payload - ARRAY['customer_id', 'payment_method', 'payment_status',
      'paid_at', 'paid_goods_deposit_version']) || jsonb_build_object(
    'delivery_fee_payer', 'sender', 'cod_collection_amount', 0, 'paid_goods_deposit_version', 1);
  v_key := 'customer:' || v_customer_id::text || ':delivery-payment:' || p_request_id::text;

  -- All customer debits use this namespace. A lost response reuses the same key.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('customer-wallet:' || v_customer_id::text, 0));
  SELECT * INTO v_existing FROM public.customer_wallet_transactions WHERE idempotency_key = v_key;
  IF FOUND THEN
    IF v_existing.metadata->'order_payload' IS DISTINCT FROM v_payload THEN
      RAISE EXCEPTION 'WALLET_REQUEST_PAYLOAD_MISMATCH';
    END IF;
    -- Do not lock this row while holding the wallet lock: cancellation locks order first.
    SELECT * INTO STRICT v_order FROM public.orders WHERE id = v_existing.order_id;
    RETURN v_order;
  END IF;
  v_amount := round((v_payload->>'delivery_fee')::numeric)::bigint;
  IF v_amount IS NULL OR v_amount < 5000 OR v_amount > 10000000 THEN
    RAISE EXCEPTION 'ORDER_PRICE_INVALID';
  END IF;
  SELECT COALESCE(sum(available_delta), 0)::bigint INTO v_balance
  FROM public.customer_wallet_transactions WHERE customer_id = v_customer_id AND status = 'completed';
  IF v_balance < v_amount THEN RAISE EXCEPTION 'CUSTOMER_WALLET_INSUFFICIENT_BALANCE'; END IF;

  -- The trusted helper retains goods deposit, ETA, cargo and dispatch contracts.
  SELECT * INTO v_order FROM private.create_customer_order_from_payload(
    v_customer_id, v_payload, 'paid', clock_timestamp());
  INSERT INTO public.customer_wallet_transactions(customer_id, order_id, transaction_type,
    amount, available_delta, idempotency_key, metadata)
  VALUES(v_customer_id, v_order.id, 'delivery_fee_payment', v_amount, -v_amount, v_key,
    jsonb_build_object('order_payload', v_payload, 'tracking_code', v_order.tracking_code,
      'payment_state', 'reserved'));
  UPDATE public.orders SET payment_method = 'wallet' WHERE id = v_order.id RETURNING * INTO v_order;
  UPDATE public.order_status_logs SET description =
    'Phí giao hàng đã được trừ từ Ví Khách Hàng. Đơn đang chờ tài xế nhận.'
  WHERE order_id = v_order.id AND status = 'pending' AND title = 'Đã tạo đơn';
  RETURN v_order;
END;
$function$;
REVOKE ALL ON FUNCTION public.create_customer_order_with_wallet(jsonb, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_customer_order_with_wallet(jsonb, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.manage_customer_wallet_order_payment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  v_payment public.customer_wallet_transactions%ROWTYPE;
  v_balance bigint;
  v_refund_key text;
BEGIN
  -- A client cannot relabel VNPAY as wallet or change wallet money/workflow.
  IF current_user NOT IN ('postgres', 'service_role', 'supabase_admin') THEN
    IF TG_OP = 'INSERT' AND NEW.payment_method = 'wallet' THEN
      RAISE EXCEPTION 'WALLET_PAYMENT_COMMAND_REQUIRED';
    ELSIF TG_OP = 'UPDATE' THEN
      IF NEW.payment_method IS DISTINCT FROM OLD.payment_method THEN
        RAISE EXCEPTION 'ORDER_PAYMENT_FIELDS_SERVER_MANAGED';
      END IF;
      IF OLD.payment_method = 'wallet' AND ROW(NEW.customer_id, NEW.delivery_fee,
        NEW.total_price, NEW.goods_value, NEW.cod_collection_amount, NEW.driver_advance_amount,
        NEW.driver_net_earning, NEW.receiver_collection_amount, NEW.platform_fee_amount,
        NEW.platform_fee_rate_bps, NEW.delivery_fee_payer, NEW.payment_mode, NEW.payment_status,
        NEW.paid_at, NEW.status, NEW.driver_id, NEW.actual_picked_up_at, NEW.actual_delivered_at,
        NEW.assignment_timed_out_at, NEW.assignment_expires_at)
        IS DISTINCT FROM ROW(OLD.customer_id, OLD.delivery_fee,
        OLD.total_price, OLD.goods_value, OLD.cod_collection_amount, OLD.driver_advance_amount,
        OLD.driver_net_earning, OLD.receiver_collection_amount, OLD.platform_fee_amount,
        OLD.platform_fee_rate_bps, OLD.delivery_fee_payer, OLD.payment_mode, OLD.payment_status,
        OLD.paid_at, OLD.status, OLD.driver_id, OLD.actual_picked_up_at, OLD.actual_delivered_at,
        OLD.assignment_timed_out_at, OLD.assignment_expires_at) THEN
        RAISE EXCEPTION 'WALLET_PAYMENT_COMMAND_REQUIRED';
      END IF;
    END IF;
  END IF;
  IF TG_OP <> 'UPDATE' OR OLD.payment_method IS DISTINCT FROM 'wallet' THEN RETURN NEW; END IF;
  IF NEW.payment_method <> 'wallet' OR NEW.customer_id IS DISTINCT FROM OLD.customer_id
    OR NEW.delivery_fee IS DISTINCT FROM OLD.delivery_fee THEN
    RAISE EXCEPTION 'WALLET_PAYMENT_SNAPSHOT_IMMUTABLE';
  END IF;

  IF ROW(NEW.status, NEW.assignment_timed_out_at)
    IS NOT DISTINCT FROM ROW(OLD.status, OLD.assignment_timed_out_at) THEN RETURN NEW; END IF;

  SELECT * INTO v_payment FROM public.customer_wallet_transactions
  WHERE order_id = OLD.id AND customer_id = OLD.customer_id
    AND transaction_type = 'delivery_fee_payment' AND status = 'completed'
  ORDER BY created_at DESC, id DESC LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'WALLET_PAYMENT_NOT_FOUND'; END IF;

  IF NEW.actual_picked_up_at IS NULL AND (
    NEW.status = 'cancelled' OR (NEW.driver_id IS NULL AND NEW.status IN ('pending', 'confirmed')
      AND NEW.assignment_timed_out_at IS NOT NULL)
  ) AND v_payment.metadata->>'payment_state' = 'reserved' THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('customer-wallet:' || OLD.customer_id::text, 0));
    v_refund_key := v_payment.idempotency_key || ':refund';
    INSERT INTO public.customer_wallet_transactions(customer_id, order_id, transaction_type,
      amount, available_delta, idempotency_key, metadata)
    VALUES(OLD.customer_id, OLD.id, 'delivery_fee_refund', v_payment.amount, v_payment.amount,
      v_refund_key, jsonb_build_object('payment_id', v_payment.id, 'tracking_code', NEW.tracking_code,
        'reason', CASE WHEN NEW.status = 'cancelled' THEN 'cancelled' ELSE 'assignment_timeout' END))
    ON CONFLICT (idempotency_key) DO NOTHING;
    UPDATE public.customer_wallet_transactions SET metadata = metadata ||
      jsonb_build_object('payment_state', 'refunded') WHERE id = v_payment.id;
    NEW.payment_status := 'refunded';
    INSERT INTO public.order_status_logs(order_id, status, title, description, logged_by)
    VALUES(OLD.id, NEW.status, 'Đã hoàn phí giao vào ví',
      'Phí giao hàng đã được hoàn về Ví Khách Hàng.', NULL);
  ELSIF OLD.assignment_timed_out_at IS NOT NULL AND NEW.assignment_timed_out_at IS NULL
    AND NEW.status IN ('pending', 'confirmed') AND OLD.payment_status = 'refunded' THEN
    -- Searching again is an explicit customer action; recharge atomically or fail.
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('customer-wallet:' || OLD.customer_id::text, 0));
    SELECT COALESCE(sum(available_delta), 0)::bigint INTO v_balance
    FROM public.customer_wallet_transactions WHERE customer_id = OLD.customer_id AND status = 'completed';
    IF v_balance < v_payment.amount THEN RAISE EXCEPTION 'CUSTOMER_WALLET_INSUFFICIENT_BALANCE'; END IF;
    INSERT INTO public.customer_wallet_transactions(customer_id, order_id, transaction_type,
      amount, available_delta, idempotency_key, metadata)
    VALUES(OLD.customer_id, OLD.id, 'delivery_fee_payment', v_payment.amount, -v_payment.amount,
      'order:' || OLD.id::text || ':delivery-payment:' || gen_random_uuid()::text,
      jsonb_build_object('tracking_code', NEW.tracking_code, 'payment_state', 'reserved',
        'reason', 'assignment_retry'));
    NEW.payment_status := 'paid';
    NEW.paid_at := clock_timestamp();
  ELSIF NEW.status IN ('delivered', 'returned') AND NEW.status IS DISTINCT FROM OLD.status THEN
    UPDATE public.customer_wallet_transactions SET metadata = metadata ||
      jsonb_build_object('payment_state', 'settled') WHERE id = v_payment.id;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.manage_customer_wallet_order_payment() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER orders_wallet_payment_lifecycle
BEFORE INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION private.manage_customer_wallet_order_payment();

-- Returning the customer's own principal must not inflate COD receipts.
CREATE OR REPLACE FUNCTION public.get_customer_wallet_summary()
RETURNS TABLE(available_balance bigint, total_received bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_customer_id uuid := auth.uid();
BEGIN
  IF v_customer_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_customer_id AND role = 'customer') THEN
    RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED';
  END IF;
  RETURN QUERY SELECT
    COALESCE(sum(tx.available_delta) FILTER (WHERE tx.status = 'completed'), 0)::bigint,
    COALESCE(sum(tx.amount) FILTER (WHERE tx.status = 'completed' AND tx.available_delta > 0
      AND tx.transaction_type <> 'delivery_fee_refund'), 0)::bigint
  FROM public.customer_wallet_transactions tx WHERE tx.customer_id = v_customer_id;
END;
$function$;
