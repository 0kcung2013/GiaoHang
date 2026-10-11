-- Staff-only read API for contacts of orders and their linked report.
-- Staff can read only contacts linked to the requested orders/report.
CREATE OR REPLACE FUNCTION public.get_support_order_contacts(
  p_order_ids uuid[],
  p_report_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_orders jsonb;
  v_reporter jsonb;
  v_report_order_id uuid;
BEGIN
  PERFORM private.require_risk_staff();
  IF p_order_ids IS NULL OR cardinality(p_order_ids) NOT BETWEEN 1 AND 200
     OR array_position(p_order_ids, NULL) IS NOT NULL THEN
    RAISE EXCEPTION 'ORDER_CONTACT_SCOPE_INVALID' USING ERRCODE = '22023';
  END IF;

  IF p_report_id IS NOT NULL THEN
    SELECT report.order_id, jsonb_build_object(
      'full_name', reporter.full_name, 'phone', reporter.phone,
      'email', reporter.email, 'avatar_url', reporter.avatar_url,
      'role', reporter.role::text
    ) INTO v_report_order_id, v_reporter
    FROM public.risk_reports AS report
    LEFT JOIN public.users AS reporter ON reporter.id = report.reported_by
    WHERE report.id = p_report_id;
    IF NOT FOUND OR v_report_order_id IS NULL
       OR NOT (v_report_order_id = ANY(p_order_ids)) THEN
      RAISE EXCEPTION 'RISK_REPORT_ORDER_MISMATCH' USING ERRCODE = '22023';
    END IF;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'order_id', delivery_order.id,
    'customer_id', delivery_order.customer_id, 'driver_id', delivery_order.driver_id,
    'customer', CASE WHEN sender.id IS NOT NULL THEN jsonb_build_object(
      'full_name', sender.full_name, 'phone', sender.phone,
      'email', sender.email, 'avatar_url', sender.avatar_url
    ) END,
    'driver', CASE WHEN driver.id IS NOT NULL THEN jsonb_build_object(
      'full_name', driver.full_name, 'phone', driver.phone,
      'email', driver.email, 'avatar_url', driver.avatar_url
    ) END
  )), '[]'::jsonb) INTO v_orders
  FROM public.orders AS delivery_order
  LEFT JOIN public.users AS sender ON sender.id = delivery_order.customer_id
  LEFT JOIN public.users AS driver ON driver.id = delivery_order.driver_id
  WHERE delivery_order.id = ANY(p_order_ids);

  RETURN jsonb_build_object('orders', v_orders, 'reporter', v_reporter);
END;
$$;

REVOKE ALL ON FUNCTION public.get_support_order_contacts(uuid[],uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_support_order_contacts(uuid[],uuid) TO authenticated;
