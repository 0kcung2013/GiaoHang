-- Keep the existing RPC signature while older Operations Web deployments are
-- still active. The client-provided earning is accepted for compatibility but
-- never used for settlement; Postgres remains the pricing authority.

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
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.support_approve_return(
  uuid, text, text, text, double precision, double precision,
  double precision, double precision, integer, integer, text, text,
  bigint, bigint, text
) FROM anon;
GRANT EXECUTE ON FUNCTION public.support_approve_return(
  uuid, text, text, text, double precision, double precision,
  double precision, double precision, integer, integer, text, text,
  bigint, bigint, text
) TO authenticated;
