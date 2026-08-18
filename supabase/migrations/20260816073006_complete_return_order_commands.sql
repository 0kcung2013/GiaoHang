-- Completion, settlement and legacy custody compatibility commands.

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
  SELECT * INTO return_order FROM public.orders
  WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  SELECT * INTO order_return FROM public.order_returns
  WHERE order_id = p_order_id FOR UPDATE;
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
  FROM public.order_delivery_proofs proof
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

  SELECT * INTO intervention FROM public.risk_report_interventions
  WHERE risk_report_id = order_return.risk_report_id FOR UPDATE;
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

  INSERT INTO public.driver_wallet_transactions(
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

  IF return_order.driver_advance_amount > 0 THEN
    INSERT INTO public.driver_wallet_transactions(
      driver_id, order_id, transaction_type, amount, available_delta,
      idempotency_key, completed_at, metadata
    ) VALUES (
      actor_id, p_order_id, 'cod_release', return_order.driver_advance_amount,
      return_order.driver_advance_amount,
      'order:' || p_order_id::text || ':return_cod_release',
      clock_timestamp(), jsonb_build_object('return_id', order_return.id)
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  INSERT INTO public.order_status_logs(
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, 'returned'::public.order_status,
    'Hoàn hàng thành công',
    'Kiện hàng đã được bàn giao cho ' || normalized_receiver || '.', actor_id
  );
  INSERT INTO public.risk_report_events(
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (
    order_return.risk_report_id, actor_id, 'return_completed',
    'action_required', 'resolved',
    jsonb_build_object(
      'return_id', order_return.id,
      'receiver_name', normalized_receiver,
      'proof_storage_path', return_proof.storage_path
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
    'Hoàn hàng thành công',
    'Thu nhập chặng hoàn đã được ghi nhận.',
    'order_return_completed',
    return_order.id
  );
  RETURN order_return;
END;
$$;

-- The legacy custody RPC remains for handoff only. A return must use the
-- dedicated start/confirm workflow above so it can never become cancelled.
CREATE OR REPLACE FUNCTION public.confirm_risk_custody_resolved(
  p_report_id uuid,
  p_note text DEFAULT NULL
)
RETURNS public.risk_report_interventions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  report public.risk_reports%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  custody_order public.orders%ROWTYPE;
BEGIN
  SELECT role INTO actor_role FROM public.users WHERE id = actor_id;
  SELECT * INTO report FROM public.risk_reports
    WHERE id = p_report_id FOR UPDATE;
  SELECT * INTO intervention FROM public.risk_report_interventions
    WHERE risk_report_id = p_report_id FOR UPDATE;
  IF intervention.state = 'return_required' THEN
    RAISE EXCEPTION 'RETURN_WORKFLOW_REQUIRED' USING ERRCODE = '23514';
  END IF;
  IF actor_id IS NULL OR actor_role NOT IN (
      'support'::public.user_role,
      'admin'::public.user_role
    ) THEN
    RAISE EXCEPTION 'STAFF_REQUIRED' USING ERRCODE = '42501';
  END IF;
  IF intervention.state <> 'handoff_required' THEN
    RAISE EXCEPTION 'NO_HANDOFF_PENDING' USING ERRCODE = '23514';
  END IF;
  SELECT * INTO custody_order FROM public.orders
    WHERE id = report.order_id FOR UPDATE;
  IF custody_order.status NOT IN (
      'picking_up'::public.order_status,
      'delivering'::public.order_status
    ) OR custody_order.driver_id IS DISTINCT FROM intervention.driver_id THEN
    RAISE EXCEPTION 'ORDER_CUSTODY_MISMATCH' USING ERRCODE = '23514';
  END IF;

  UPDATE public.orders SET
    status = 'risk_hold'::public.order_status,
    driver_id = NULL,
    risk_hold_report_id = p_report_id,
    status_note = COALESCE(NULLIF(trim(p_note), ''), intervention.instruction),
    updated_at = clock_timestamp()
  WHERE id = custody_order.id;
  UPDATE public.risk_report_interventions SET
    state = 'released',
    driver_released_at = clock_timestamp(),
    updated_at = clock_timestamp()
  WHERE risk_report_id = p_report_id
  RETURNING * INTO intervention;
  INSERT INTO public.order_status_logs(
    order_id, status, title, description, logged_by
  ) VALUES (
    custody_order.id, 'risk_hold'::public.order_status,
    'Đã bàn giao hàng',
    COALESCE(NULLIF(trim(p_note), ''), intervention.instruction), actor_id
  );
  INSERT INTO public.risk_report_events(
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (
    p_report_id, actor_id, 'intervention_changed', report.status,
    report.status, jsonb_build_object('state', 'released')
  );
  RETURN intervention;
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

REVOKE ALL ON FUNCTION public.start_order_return(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_order_return(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.confirm_order_return(uuid, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_order_return(uuid, text, text)
  TO authenticated;

COMMENT ON TABLE public.order_returns IS
  'One durable return mission per order, visible to related participants and staff.';
COMMENT ON FUNCTION public.support_approve_return(
  uuid, text, text, text, double precision, double precision,
  double precision, double precision, integer, integer, text, text,
  bigint, bigint, text
) IS 'Support-only atomic return approval and quote command.';



