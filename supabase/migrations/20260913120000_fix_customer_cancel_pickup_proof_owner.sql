-- A pickup proof blocks customer cancellation only when it belongs to the
-- driver currently assigned to the order. Proofs left by a previous driver
-- must not make a reassigned order look already picked up.

CREATE OR REPLACE FUNCTION public.cancel_customer_order(
  p_order_id uuid,
  p_customer_id uuid,
  p_status_note text DEFAULT NULL
)
RETURNS TABLE(order_id uuid, driver_id uuid, tracking_code text, new_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_customer_user_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_normalized_note text := NULLIF(btrim(p_status_note), '');
  v_release_amount bigint;
BEGIN
  IF v_customer_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users customer_user
    WHERE customer_user.id = v_customer_user_id
      AND customer_user.role = 'customer'::public.user_role
  ) THEN RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED'; END IF;
  IF p_customer_id IS DISTINCT FROM v_customer_user_id
    THEN RAISE EXCEPTION 'CUSTOMER_ID_MISMATCH'; END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.customer_id IS DISTINCT FROM v_customer_user_id
    THEN RAISE EXCEPTION 'ORDER_NOT_OWNED'; END IF;
  IF v_order.status NOT IN (
    'pending'::public.order_status, 'confirmed'::public.order_status,
    'assigned'::public.order_status, 'picking_up'::public.order_status
  ) THEN RAISE EXCEPTION 'ORDER_NOT_CANCELLABLE'; END IF;

  -- `picking_up` remains cancellable until the assigned driver records the
  -- pickup handoff. A proof from a previous driver is not a handoff for the
  -- current assignment.
  IF v_order.status = 'picking_up'::public.order_status AND EXISTS (
    SELECT 1 FROM public.order_delivery_proofs proof
    WHERE proof.order_id = p_order_id
      AND proof.driver_id = v_order.driver_id
      AND proof.stage = 'pickup'
  ) THEN RAISE EXCEPTION 'ORDER_ALREADY_PICKED_UP'; END IF;

  IF v_order.driver_id IS NOT NULL THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_order.driver_id::text, 0)
    );
    SELECT COALESCE(sum(tx.held_delta), 0)::bigint INTO v_release_amount
    FROM public.driver_wallet_transactions tx
    WHERE tx.driver_id = v_order.driver_id
      AND tx.order_id = v_order.id AND tx.status = 'completed';
    IF v_release_amount > 0 THEN
      INSERT INTO public.driver_wallet_transactions (
        driver_id, order_id, transaction_type, amount,
        available_delta, held_delta, idempotency_key, completed_at
      ) VALUES (
        v_order.driver_id, v_order.id, 'cod_release', v_release_amount,
        v_release_amount, -v_release_amount,
        'order:' || v_order.id::text || ':cod_release', clock_timestamp()
      );
    END IF;
  END IF;

  UPDATE public.orders
  SET status = 'cancelled'::public.order_status,
    status_note = v_normalized_note,
    payment_status = CASE
      WHEN delivery_fee_payer = 'sender' AND payment_status = 'paid'
        THEN 'refund_required'
      ELSE payment_status END,
    cancelled_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE id = p_order_id RETURNING * INTO v_order;

  IF v_order.payment_status = 'refund_required' THEN
    UPDATE public.order_payment_sessions session
    SET status = 'refund_required', updated_at = clock_timestamp()
    WHERE session.order_id = v_order.id AND session.status = 'paid';
  END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    v_order.id, 'cancelled'::public.order_status, 'Đơn hàng đã hủy',
    CASE WHEN v_normalized_note IS NULL
      THEN 'Khách hàng đã hủy đơn trước khi tài xế nhận hàng.'
      ELSE 'Khách hàng đã hủy đơn trước khi tài xế nhận hàng. Lý do: '
        || v_normalized_note END,
    v_customer_user_id
  );
  RETURN QUERY SELECT v_order.id, v_order.driver_id,
    v_order.tracking_code, v_order.status::text;
END;
$function$;
