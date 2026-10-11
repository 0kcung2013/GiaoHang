-- A single current prediction on the existing order, never GPS history.
-- estimated_delivery_at remains the server-owned operational deadline.
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_eta jsonb;
COMMENT ON COLUMN public.orders.delivery_eta IS
  'Current staged ETA at 25 km/h with historical LightGBM correction; independent of delivery deadline. No GPS coordinates/history.';

CREATE OR REPLACE FUNCTION private.guard_order_delivery_eta()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.delivery_eta IS NOT NULL THEN RAISE EXCEPTION 'ETA_SERVER_OWNED'; END IF;
    RETURN NEW;
  END IF;
  IF current_user IN ('anon','authenticated')
    AND NEW.delivery_eta IS DISTINCT FROM OLD.delivery_eta THEN
    RAISE EXCEPTION 'ETA_SERVER_OWNED' USING ERRCODE = '42501';
  END IF;
  IF NEW.driver_id IS DISTINCT FROM OLD.driver_id
    OR (NEW.status = 'assigned' AND OLD.status IN ('pending','confirmed')) THEN
    NEW.delivery_eta := CASE WHEN NEW.driver_id IS NULL THEN NULL ELSE
      jsonb_build_object('driver_id',NEW.driver_id,'assigned_at',clock_timestamp()) END;
  ELSIF NEW.status IS DISTINCT FROM OLD.status
    OR NEW.actual_picked_up_at IS DISTINCT FROM OLD.actual_picked_up_at
    OR NEW.pickup_arrived_at IS DISTINCT FROM OLD.pickup_arrived_at THEN
    NEW.delivery_eta := NEW.delivery_eta - 'predicted_at' - 'computed_at';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_order_delivery_eta() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER orders_guard_staged_eta BEFORE INSERT OR UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION private.guard_order_delivery_eta();

-- Only the assigned driver can end their preparation phase. Idempotent on retry.
CREATE OR REPLACE FUNCTION public.mark_driver_eta_departure(p_order_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_order public.orders%ROWTYPE; v_anchor timestamptz;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id FOR UPDATE;
  IF NOT FOUND OR auth.uid() IS NULL OR v_order.driver_id IS DISTINCT FROM auth.uid()
    OR v_order.status NOT IN ('assigned','picking_up') THEN
    RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED' USING ERRCODE='42501';
  END IF;
  IF v_order.delivery_eta->>'departed_at' IS NOT NULL THEN RETURN; END IF;
  v_anchor := (v_order.delivery_eta->>'assigned_at')::timestamptz;
  IF v_anchor IS NULL THEN
    SELECT max(created_at) INTO v_anchor FROM public.order_status_logs
      WHERE order_id=p_order_id AND logged_by=v_order.driver_id
      AND status='assigned' AND title='Đã có tài xế nhận đơn';
  END IF;
  UPDATE public.orders SET delivery_eta = (COALESCE(delivery_eta,'{}'::jsonb)
    - 'computed_at' - 'predicted_at')
    || jsonb_build_object('driver_id',driver_id,'assigned_at',v_anchor,
      'departed_at',clock_timestamp()) WHERE id=p_order_id;
END;
$$;
REVOKE ALL ON FUNCTION public.mark_driver_eta_departure(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_driver_eta_departure(uuid) TO authenticated;

-- Edge verifies ownership; this service-only command rejects stale computations.
CREATE OR REPLACE FUNCTION public.commit_order_delivery_eta(
  p_order_id uuid, p_driver_id uuid, p_status text,
  p_pickup_arrived_at timestamptz, p_actual_picked_up_at timestamptz,
  p_delivery_arrived_at timestamptz, p_snapshot jsonb
)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE v_order public.orders%ROWTYPE; v_arrived_at timestamptz;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.driver_id IS DISTINCT FROM p_driver_id OR v_order.status::text <> p_status
    OR v_order.pickup_arrived_at IS DISTINCT FROM p_pickup_arrived_at
    OR v_order.actual_picked_up_at IS DISTINCT FROM p_actual_picked_up_at THEN
    RAISE EXCEPTION 'ETA_CONTEXT_CHANGED';
  END IF;
  IF p_status NOT IN ('assigned','picking_up','delivering')
    OR p_snapshot->>'driver_id' IS DISTINCT FROM p_driver_id::text
    OR p_snapshot->>'computed_at' IS NULL
    OR (p_snapshot->>'computed_at')::timestamptz > clock_timestamp() + interval '30 seconds'
    OR (p_snapshot->>'computed_at')::timestamptz < clock_timestamp() - interval '2 minutes'
    OR COALESCE((p_snapshot->>'remaining_minutes')::numeric,-1) < 0 THEN
    RAISE EXCEPTION 'INVALID_ETA_SNAPSHOT';
  END IF;
  IF (v_order.delivery_eta->>'computed_at')::timestamptz >=
    (p_snapshot->>'computed_at')::timestamptz THEN RETURN v_order.delivery_eta; END IF;
  -- A departure confirmed during route calculation must not be overwritten.
  IF v_order.delivery_eta->>'departed_at' IS DISTINCT FROM p_snapshot->>'departed_at' THEN
    RAISE EXCEPTION 'ETA_CONTEXT_CHANGED';
  END IF;
  IF v_order.delivery_eta->>'assigned_at' IS NOT NULL
    AND (v_order.delivery_eta->>'assigned_at')::timestamptz IS DISTINCT FROM
      (p_snapshot->>'assigned_at')::timestamptz THEN
    RAISE EXCEPTION 'ETA_CONTEXT_CHANGED';
  END IF;
  SELECT max(created_at) INTO v_arrived_at FROM public.order_status_logs
    WHERE order_id=p_order_id AND logged_by=p_driver_id
      AND title='Tài xế đã đến điểm giao'
      AND created_at >= (p_snapshot->>'assigned_at')::timestamptz;
  IF v_arrived_at IS DISTINCT FROM p_delivery_arrived_at THEN
    RAISE EXCEPTION 'ETA_CONTEXT_CHANGED';
  END IF;
  UPDATE public.orders SET delivery_eta=p_snapshot WHERE id=p_order_id;
  RETURN p_snapshot;
END;
$$;
REVOKE ALL ON FUNCTION public.commit_order_delivery_eta(uuid,uuid,text,timestamptz,timestamptz,timestamptz,jsonb)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.commit_order_delivery_eta(uuid,uuid,text,timestamptz,timestamptz,timestamptz,jsonb)
TO service_role;
