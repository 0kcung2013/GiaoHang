-- Run after the deadline migration in a test/staging project.
-- Uses an existing active order; all writes are rolled back.
BEGIN;
SET LOCAL ROLE service_role;
DO $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_first timestamptz;
  v_again timestamptz;
  v_started timestamptz;
  v_logs bigint;
BEGIN
  SELECT * INTO v_order FROM public.orders
  WHERE driver_id IS NOT NULL AND status IN ('assigned','picking_up','delivering')
    AND estimated_delivery_at IS NULL LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Test requires an active order without a deadline'; END IF;
  v_started := clock_timestamp();
  SELECT estimated_delivery_at INTO v_first FROM public.accept_driver_order_with_deadline(
    v_order.id,v_order.driver_id,300,false,'osrm',true);
  IF v_first < v_started + interval '25 minutes'
    OR v_first > clock_timestamp() + interval '25 minutes' THEN
    RAISE EXCEPTION 'Minimum deadline budget failed';
  END IF;
  SELECT count(*) INTO v_logs FROM public.order_status_logs WHERE order_id=v_order.id;
  SELECT estimated_delivery_at INTO v_again FROM public.accept_driver_order_with_deadline(
    v_order.id,v_order.driver_id,3600,false,'osrm',true);
  IF v_again IS DISTINCT FROM v_first OR
    (SELECT count(*) FROM public.order_status_logs WHERE order_id=v_order.id) <> v_logs THEN
    RAISE EXCEPTION 'Retry extended the deadline or duplicated its log';
  END IF;
  BEGIN
    PERFORM public.accept_driver_order_with_deadline(v_order.id,v_order.driver_id,-1,false,'osrm',true);
    RAISE EXCEPTION 'Invalid quote unexpectedly accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'INVALID_DELIVERY_QUOTE' THEN RAISE; END IF;
  END;
  UPDATE public.orders SET estimated_delivery_at=NULL WHERE id=v_order.id;
  v_started := clock_timestamp();
  SELECT estimated_delivery_at INTO v_first FROM public.accept_driver_order_with_deadline(
    v_order.id,v_order.driver_id,1500,false,'distance_fallback',true);
  IF v_first < v_started + interval '48 minutes'
    OR v_first > clock_timestamp() + interval '48 minutes' THEN
    RAISE EXCEPTION 'Route plus buffer budget failed';
  END IF;
  IF has_function_privilege('authenticated',
    'public.accept_driver_order_with_deadline(uuid,uuid,integer,boolean,text,boolean)','execute') THEN
    RAISE EXCEPTION 'Untrusted clients can write quotes';
  END IF;
END;
$$;
ROLLBACK;
