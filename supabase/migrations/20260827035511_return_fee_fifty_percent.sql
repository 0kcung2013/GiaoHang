-- A returned order pays the Driver the original delivery earning plus a
-- return fee equal to 50% of the original delivery fee. The platform funds
-- the return fee; the Customer is not charged again.

ALTER TABLE public.driver_wallet_transactions
  DROP CONSTRAINT IF EXISTS driver_wallet_transactions_transaction_type_check;
ALTER TABLE public.driver_wallet_transactions
  ADD CONSTRAINT driver_wallet_transactions_transaction_type_check
  CHECK (transaction_type IN (
    'vnpay_topup',
    'cod_hold',
    'cod_release',
    'cod_advance_capture',
    'platform_fee_capture',
    'prepaid_earning',
    'cod_settlement',
    'return_delivery_earning',
    'return_earning'
  ));

COMMENT ON COLUMN public.order_returns.driver_return_earning IS
  'Platform-funded return fee, fixed at 50% of orders.delivery_fee at approval time.';

CREATE OR REPLACE FUNCTION public.support_approve_return(
  p_report_id uuid,
  p_reason_code text,
  p_destination_type text,
  p_destination_address text,
  p_destination_lat double precision,
  p_destination_lng double precision,
  p_route_origin_lat double precision,
  p_route_origin_lng double precision,
  p_route_distance_m integer,
  p_route_duration_s integer,
  p_quote_source text,
  p_fee_payer text,
  p_customer_return_charge bigint,
  p_driver_return_earning bigint,
  p_instruction text DEFAULT NULL
)
RETURNS public.order_returns
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  report public.risk_reports%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  return_order public.orders%ROWTYPE;
  created_return public.order_returns%ROWTYPE;
  expected_return_fee bigint;
  normalized_instruction text := NULLIF(trim(p_instruction), '');
BEGIN
  SELECT role INTO actor_role FROM public.users WHERE id = actor_id;
  IF actor_id IS NULL OR actor_role <> 'support'::public.user_role THEN
    RAISE EXCEPTION 'SUPPORT_REQUIRED' USING ERRCODE = '42501';
  END IF;
  IF p_destination_type NOT IN ('sender', 'processing_center')
    OR char_length(trim(COALESCE(p_destination_address, ''))) < 3
    OR p_destination_lat NOT BETWEEN -90 AND 90
    OR p_destination_lng NOT BETWEEN -180 AND 180
    OR p_route_origin_lat NOT BETWEEN -90 AND 90
    OR p_route_origin_lng NOT BETWEEN -180 AND 180
    OR p_route_distance_m < 0
    OR p_route_duration_s < 0
    OR p_quote_source NOT IN ('osrm', 'fallback')
    OR p_fee_payer <> 'platform'
    OR p_customer_return_charge < 0
    OR p_driver_return_earning < 0 THEN
    RAISE EXCEPTION 'INVALID_RETURN_QUOTE' USING ERRCODE = '22023';
  END IF;
  IF p_customer_return_charge <> 0 THEN
    RAISE EXCEPTION 'RETURN_CUSTOMER_CHARGE_NOT_SUPPORTED'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO report
  FROM public.risk_reports
  WHERE id = p_report_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RISK_REPORT_NOT_FOUND'; END IF;

  SELECT * INTO return_order
  FROM public.orders
  WHERE id = report.order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;

  expected_return_fee := round(
    greatest(COALESCE(return_order.delivery_fee, 0), 0) * 0.5
  )::bigint;
  IF p_driver_return_earning IS DISTINCT FROM expected_return_fee THEN
    RAISE EXCEPTION 'RETURN_FEE_MISMATCH' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO intervention
  FROM public.risk_report_interventions
  WHERE risk_report_id = p_report_id
  FOR UPDATE;

  IF report.assigned_to IS DISTINCT FROM actor_id
    OR report.status NOT IN ('investigating', 'action_required') THEN
    RAISE EXCEPTION 'REPORT_NOT_ASSIGNED_TO_SUPPORT'
      USING ERRCODE = '42501';
  END IF;
  IF intervention.state <> 'awaiting_triage'
    OR return_order.status <> 'delivering'::public.order_status
    OR return_order.driver_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_RETURN_APPROVAL_STATE'
      USING ERRCODE = '23514';
  END IF;

  UPDATE public.risk_report_interventions SET
    state = 'return_required',
    driver_id = return_order.driver_id,
    decided_by = actor_id,
    decided_at = clock_timestamp(),
    instruction = COALESCE(
      normalized_instruction,
      'Quay về điểm trả và bàn giao hàng cho đúng người phụ trách.'
    ),
    updated_at = clock_timestamp()
  WHERE risk_report_id = p_report_id
  RETURNING * INTO intervention;

  INSERT INTO public.order_returns (
    order_id, risk_report_id, driver_id, destination_type,
    destination_address, destination_lat, destination_lng,
    route_origin_lat, route_origin_lng, route_distance_m, route_duration_s,
    quote_source, reason_code, fee_payer, customer_return_charge,
    driver_return_earning, fee_status, instruction, approved_by
  ) VALUES (
    return_order.id, report.id, return_order.driver_id, p_destination_type,
    trim(p_destination_address), p_destination_lat, p_destination_lng,
    p_route_origin_lat, p_route_origin_lng, p_route_distance_m,
    p_route_duration_s, p_quote_source, trim(p_reason_code), p_fee_payer,
    p_customer_return_charge, expected_return_fee,
    'waived',
    COALESCE(
      normalized_instruction,
      'Quay về điểm trả và bàn giao hàng cho đúng người phụ trách.'
    ),
    actor_id
  )
  RETURNING * INTO created_return;

  UPDATE public.orders SET
    status = 'return_approved'::public.order_status,
    status_note = 'CSKH đã duyệt hoàn hàng về điểm trả.',
    updated_at = clock_timestamp()
  WHERE id = return_order.id;

  IF report.status = 'investigating' THEN
    UPDATE public.risk_reports SET
      status = 'action_required',
      updated_by = actor_id,
      updated_at = clock_timestamp()
    WHERE id = report.id;
  END IF;

  INSERT INTO public.order_status_logs(
    order_id, status, title, description, logged_by
  ) VALUES (
    return_order.id,
    'return_approved'::public.order_status,
    'CSKH đã duyệt hoàn hàng',
    'Tài xế chuẩn bị quay về điểm trả: ' || trim(p_destination_address),
    actor_id
  );

  INSERT INTO public.risk_report_events(
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (
    report.id, actor_id, 'return_approved', report.status,
    CASE WHEN report.status = 'investigating'
      THEN 'action_required' ELSE report.status END,
    jsonb_build_object(
      'return_id', created_return.id,
      'fee_payer', p_fee_payer,
      'customer_return_charge', p_customer_return_charge,
      'driver_return_earning', expected_return_fee,
      'return_fee_rate_bps', 5000
    )
  );

  PERFORM private.enqueue_case_notification(
    return_order.customer_id,
    'Đã duyệt hoàn hàng',
    'Tài xế sẽ quay về điểm trả đã được CSKH xác nhận.',
    'order_return_approved',
    return_order.id
  );
  PERFORM private.enqueue_case_notification(
    return_order.driver_id,
    'Chuyến hoàn hàng mới',
    'Phí hoàn hàng bằng 50% cước giao và do GiaoHang chi trả.',
    'order_return_approved',
    return_order.id
  );
  RETURN created_return;
END;
$$;

REVOKE ALL ON FUNCTION public.support_approve_return(
  uuid, text, text, text, double precision, double precision,
  double precision, double precision, integer, integer, text, text,
  bigint, bigint, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.support_approve_return(
  uuid, text, text, text, double precision, double precision,
  double precision, double precision, integer, integer, text, text,
  bigint, bigint, text
) TO authenticated;

-- Active returns adopt the policy immediately. Completed returns are kept as
-- historical financial records and are not paid retroactively.
UPDATE public.order_returns AS active_return
SET
  driver_return_earning = round(
    greatest(COALESCE(return_order.delivery_fee, 0), 0) * 0.5
  )::bigint,
  updated_at = clock_timestamp()
FROM public.orders AS return_order
WHERE return_order.id = active_return.order_id
  AND active_return.status IN ('approved', 'returning');

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
  delivery_earning bigint;
  advance_refunded boolean := false;
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

  delivery_earning := round(greatest(COALESCE(
    return_order.driver_net_earning,
    return_order.delivery_fee,
    0
  ), 0))::bigint;

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
    actor_id,
    p_order_id,
    'return_delivery_earning',
    delivery_earning,
    delivery_earning,
    'order:' || p_order_id::text || ':return_delivery_earning',
    clock_timestamp(),
    jsonb_build_object(
      'return_id', order_return.id,
      'delivery_fee', round(return_order.delivery_fee)::bigint,
      'earning_kind', 'original_delivery_fee_for_returned_order'
    )
  ) ON CONFLICT (idempotency_key) DO NOTHING;

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
      'fee_payer', order_return.fee_payer,
      'return_fee_rate_bps', 5000,
      'delivery_fee', round(return_order.delivery_fee)::bigint
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
    advance_refunded := true;
  END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, 'returned'::public.order_status,
    'Hoàn hàng đã ghi nhận',
    'Kiện hàng đã được bàn giao cho ' || normalized_receiver
      || '. Cước giao và phí hoàn hàng đã được ghi nhận cho tài xế.',
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
      'driver_delivery_earning', delivery_earning,
      'return_fee_amount', order_return.driver_return_earning,
      'driver_total_earning',
        delivery_earning + order_return.driver_return_earning,
      'driver_advance_refunded', advance_refunded
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
    'Cước giao và phí hoàn hàng đã được cộng vào Ví Tài Xế.',
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

CREATE OR REPLACE FUNCTION public.get_driver_wallet_summary()
RETURNS TABLE(
  available_balance bigint,
  held_balance bigint,
  today_income bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_user_id uuid := (SELECT auth.uid());
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.drivers AS driver
    WHERE driver.user_id = v_driver_user_id
  ) THEN
    RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(sum(tx.available_delta) FILTER (
      WHERE tx.status = 'completed'
    ), 0)::bigint,
    COALESCE(sum(tx.held_delta) FILTER (
      WHERE tx.status = 'completed'
    ), 0)::bigint,
    COALESCE(sum(tx.amount) FILTER (
      WHERE tx.status = 'completed'
        AND tx.transaction_type IN (
          'prepaid_earning',
          'cod_settlement',
          'return_delivery_earning',
          'return_earning'
        )
        AND (
          COALESCE(tx.completed_at, tx.created_at)
            AT TIME ZONE 'Asia/Ho_Chi_Minh'
        )::date = (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
    ), 0)::bigint
  FROM public.driver_wallet_transactions AS tx
  WHERE tx.driver_id = v_driver_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.get_driver_wallet_summary()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_driver_wallet_summary()
  TO authenticated;
