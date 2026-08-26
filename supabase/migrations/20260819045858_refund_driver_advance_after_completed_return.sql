-- A completed physical return gives the parcel back to the sender, so the
-- Driver receives the advance principal back in addition to the return fee.
-- A false delivered confirmation remains the Driver responsibility because
-- it uses the delivered settlement path and never enters this return command.

CREATE OR REPLACE FUNCTION public.confirm_order_return(
  p_order_id uuid,
  p_receiver_name text,
  p_note text DEFAULT NULL
)
RETURNS public.order_returns
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  return_order public.orders%ROWTYPE;
  order_return public.order_returns%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  return_proof public.order_delivery_proofs%ROWTYPE;
  distance_m double precision;
  normalized_receiver text := trim(COALESCE(p_receiver_name, ''));
  normalized_note text := NULLIF(trim(p_note), '');
BEGIN
  IF actor_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF char_length(normalized_receiver) NOT BETWEEN 2 AND 80 THEN
    RAISE EXCEPTION 'RETURN_RECEIVER_REQUIRED' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO return_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;

  SELECT * INTO order_return
  FROM public.order_returns
  WHERE order_id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RETURN_NOT_FOUND'; END IF;

  IF return_order.driver_id IS DISTINCT FROM actor_id
    OR order_return.driver_id IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED' USING ERRCODE = '42501';
  END IF;
  IF return_order.status = 'returned'::public.order_status
    AND order_return.status = 'returned' THEN
    RETURN order_return;
  END IF;
  IF return_order.status <> 'returning'::public.order_status
    OR order_return.status <> 'returning' THEN
    RAISE EXCEPTION 'INVALID_RETURN_COMPLETE_STATE'
      USING ERRCODE = '23514';
  END IF;

  SELECT * INTO return_proof
  FROM public.order_delivery_proofs AS proof
  WHERE proof.order_id = p_order_id
    AND proof.driver_id = actor_id
    AND proof.stage = 'return'
  FOR UPDATE;
  IF NOT FOUND OR return_proof.captured_lat IS NULL
    OR return_proof.captured_lng IS NULL THEN
    RAISE EXCEPTION 'RETURN_PROOF_REQUIRED' USING ERRCODE = '23514';
  END IF;

  distance_m := 6371000 * acos(least(1.0, greatest(-1.0,
    cos(radians(order_return.destination_lat))
      * cos(radians(return_proof.captured_lat))
      * cos(radians(return_proof.captured_lng)
        - radians(order_return.destination_lng))
    + sin(radians(order_return.destination_lat))
      * sin(radians(return_proof.captured_lat))
  )));
  IF distance_m > 150 THEN
    RAISE EXCEPTION 'RETURN_OUTSIDE_GEOFENCE' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO intervention
  FROM public.risk_report_interventions
  WHERE risk_report_id = order_return.risk_report_id
  FOR UPDATE;
  IF intervention.state <> 'return_required' THEN
    RAISE EXCEPTION 'RETURN_INTERVENTION_MISMATCH' USING ERRCODE = '23514';
  END IF;

  UPDATE public.orders SET
    status = 'returned'::public.order_status,
    risk_hold_report_id = NULL,
    status_note = COALESCE(normalized_note, 'Đã hoàn hàng về điểm trả.'),
    updated_at = clock_timestamp()
  WHERE id = p_order_id;

  UPDATE public.order_returns SET
    status = 'returned',
    fee_status = 'settled',
    receiver_name = normalized_receiver,
    proof_storage_path = return_proof.storage_path,
    arrived_at = COALESCE(arrived_at, return_proof.captured_at),
    returned_at = COALESCE(returned_at, clock_timestamp()),
    updated_at = clock_timestamp()
  WHERE id = order_return.id
  RETURNING * INTO order_return;

  UPDATE public.risk_report_interventions SET
    state = 'released',
    driver_released_at = clock_timestamp(),
    updated_at = clock_timestamp()
  WHERE risk_report_id = order_return.risk_report_id;

  UPDATE public.risk_reports SET
    status = 'resolved',
    resolution = COALESCE(normalized_note, 'Đã hoàn hàng về điểm trả.'),
    resolved_at = clock_timestamp(),
    updated_by = actor_id,
    updated_at = clock_timestamp()
  WHERE id = order_return.risk_report_id;

  INSERT INTO public.driver_wallet_transactions (
    driver_id, order_id, transaction_type, amount, available_delta,
    idempotency_key, completed_at, metadata
  ) VALUES (
    actor_id, p_order_id, 'return_earning',
    order_return.driver_return_earning,
    order_return.driver_return_earning,
    'order:' || p_order_id::text || ':return_earning',
    clock_timestamp(),
    jsonb_build_object(
      'return_id', order_return.id,
      'distance_m', order_return.route_distance_m,
      'fee_payer', order_return.fee_payer
    )
  ) ON CONFLICT (idempotency_key) DO NOTHING;

  IF return_order.driver_advance_amount > 0 AND EXISTS (
    SELECT 1
    FROM public.driver_wallet_transactions AS capture
    WHERE capture.order_id = p_order_id
      AND capture.driver_id = actor_id
      AND capture.transaction_type = 'cod_advance_capture'
      AND capture.status = 'completed'
  ) THEN
    INSERT INTO public.driver_wallet_transactions (
      driver_id, order_id, transaction_type, amount, available_delta,
      idempotency_key, completed_at, metadata
    ) VALUES (
      actor_id,
      p_order_id,
      'cod_release',
      return_order.driver_advance_amount,
      return_order.driver_advance_amount,
      'order:' || p_order_id::text || ':return_cod_release',
      clock_timestamp(),
      jsonb_build_object(
        'return_id', order_return.id,
        'reason', 'completed_physical_return'
      )
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, 'returned'::public.order_status,
    'Hoàn hàng đã ghi nhận',
    'Kiện hàng đã được bàn giao cho ' || normalized_receiver
      || '. Khoản ứng đã được hoàn lại cho tài xế.',
    actor_id
  );

  INSERT INTO public.risk_report_events (
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (
    order_return.risk_report_id, actor_id, 'return_completed',
    'action_required', 'resolved',
    jsonb_build_object(
      'return_id', order_return.id,
      'receiver_name', normalized_receiver,
      'proof_storage_path', return_proof.storage_path,
      'driver_advance_refunded', true
    )
  );

  PERFORM private.enqueue_case_notification(
    return_order.customer_id,
    'Đã hoàn hàng',
    'Kiện hàng đã được bàn giao lại thành công.',
    'order_return_completed',
    return_order.id
  );
  PERFORM private.enqueue_case_notification(
    actor_id,
    'Hoàn hàng đã ghi nhận',
    'Tiền ứng và thu nhập chặng hoàn đã được cộng vào Ví Tài Xế.',
    'order_return_completed',
    return_order.id
  );
  RETURN order_return;
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_order_return(uuid, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_order_return(uuid, text, text)
  TO authenticated;

-- Repair returns completed while the temporary "Driver responsible for every
-- failure" policy was active. The unique idempotency keys make this safe to
-- re-run and avoid touching legacy returns that were already released.
INSERT INTO public.driver_wallet_transactions (
  driver_id,
  order_id,
  transaction_type,
  amount,
  available_delta,
  idempotency_key,
  completed_at,
  metadata
)
SELECT
  returned_order.driver_id,
  returned_order.id,
  'cod_release',
  returned_order.driver_advance_amount,
  returned_order.driver_advance_amount,
  'order:' || returned_order.id::text || ':return_cod_release',
  clock_timestamp(),
  jsonb_build_object(
    'reason', 'completed_physical_return_policy_correction',
    'migration', 'refund_driver_advance_after_completed_return'
  )
FROM public.orders AS returned_order
WHERE returned_order.status = 'returned'::public.order_status
  AND returned_order.driver_id IS NOT NULL
  AND returned_order.driver_advance_amount > 0
  AND EXISTS (
    SELECT 1
    FROM public.driver_wallet_transactions AS capture
    WHERE capture.order_id = returned_order.id
      AND capture.driver_id = returned_order.driver_id
      AND capture.transaction_type = 'cod_advance_capture'
      AND capture.status = 'completed'
      AND capture.available_delta < 0
  )
ON CONFLICT (idempotency_key) DO NOTHING;

INSERT INTO public.customer_wallet_transactions (
  customer_id,
  order_id,
  risk_report_id,
  transaction_type,
  amount,
  available_delta,
  idempotency_key,
  metadata
)
SELECT
  incorrect_credit.customer_id,
  incorrect_credit.order_id,
  incorrect_credit.risk_report_id,
  'adjustment_debit',
  incorrect_credit.amount,
  -incorrect_credit.amount,
  'order:' || incorrect_credit.order_id::text
    || ':reverse_customer_failed_credit',
  jsonb_build_object(
    'reverses_transaction_id', incorrect_credit.id,
    'reason', 'parcel_returned_to_sender',
    'migration', 'refund_driver_advance_after_completed_return'
  )
FROM public.customer_wallet_transactions AS incorrect_credit
WHERE incorrect_credit.transaction_type = 'failed_delivery_credit'
  AND incorrect_credit.status = 'completed'
  AND EXISTS (
    SELECT 1
    FROM public.orders AS returned_order
    JOIN public.driver_wallet_transactions AS capture
      ON capture.order_id = returned_order.id
     AND capture.driver_id = returned_order.driver_id
     AND capture.transaction_type = 'cod_advance_capture'
     AND capture.status = 'completed'
     AND capture.available_delta < 0
    WHERE returned_order.id = incorrect_credit.order_id
      AND returned_order.status = 'returned'::public.order_status
  )
ON CONFLICT (idempotency_key) DO NOTHING;
