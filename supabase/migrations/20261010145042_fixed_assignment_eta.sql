-- Reuse orders.delivery_eta. No new table or column; retain the operational deadline.
COMMENT ON COLUMN public.orders.delivery_eta IS
  'ETA computed once per assignment, with one five-minute early-departure adjustment. Historical LightGBM, no GPS history; independent of delivery deadline.';

CREATE OR REPLACE FUNCTION private.apply_fixed_eta_departure(p_snapshot jsonb, p_departed_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE v_saved integer:=0; v_assigned timestamptz;
BEGIN
  IF p_snapshot->>'calculation_mode' IS DISTINCT FROM 'assignment_once_v1'
    OR p_snapshot->>'initial_predicted_at' IS NULL THEN
    RETURN p_snapshot || jsonb_build_object('departed_at',p_departed_at);
  END IF;
  v_assigned:=(p_snapshot->>'assigned_at')::timestamptz;
  IF p_departed_at >= v_assigned AND p_departed_at < v_assigned + interval '5 minutes' THEN
    v_saved:=5;
  END IF;
  RETURN p_snapshot || jsonb_build_object(
    'departed_at',p_departed_at,'preparation_removed_minutes',v_saved,
    'preparation_minutes',5-v_saved,
    'remaining_minutes',(p_snapshot->>'initial_total_minutes')::numeric-v_saved,
    'predicted_at',(p_snapshot->>'initial_predicted_at')::timestamptz - v_saved*interval '1 minute');
END;
$$;
REVOKE ALL ON FUNCTION private.apply_fixed_eta_departure(jsonb,timestamptz) FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;
GRANT EXECUTE ON FUNCTION private.apply_fixed_eta_departure(jsonb,timestamptz) TO service_role;

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
  END IF;
  -- Arrival and pickup/delivery status changes must preserve the fixed forecast.
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_driver_eta_departure(p_order_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_order public.orders%ROWTYPE; v_anchor timestamptz; v_departed timestamptz:=clock_timestamp();
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
  IF v_anchor IS NULL THEN RAISE EXCEPTION 'ETA_ASSIGNMENT_TIME_MISSING'; END IF;
  UPDATE public.orders SET delivery_eta = private.apply_fixed_eta_departure(
    COALESCE(delivery_eta,'{}'::jsonb) || jsonb_build_object('driver_id',driver_id,'assigned_at',v_anchor),
    v_departed) WHERE id=p_order_id;
END;
$$;
REVOKE ALL ON FUNCTION public.mark_driver_eta_departure(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_driver_eta_departure(uuid) TO authenticated;

-- Keep the existing RPC signature. Completed travel/handling phases no longer
-- invalidate a calculation; an assignment change or terminal order still does.
CREATE OR REPLACE FUNCTION public.commit_order_delivery_eta(
  p_order_id uuid, p_driver_id uuid, p_status text,
  p_pickup_arrived_at timestamptz, p_actual_picked_up_at timestamptz,
  p_delivery_arrived_at timestamptz, p_snapshot jsonb
)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE v_order public.orders%ROWTYPE; v_snapshot jsonb;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF v_order.driver_id IS DISTINCT FROM p_driver_id
    OR v_order.status::text NOT IN ('assigned','picking_up','delivering')
    OR p_status NOT IN ('assigned','picking_up','delivering')
    OR (v_order.delivery_eta->>'assigned_at')::timestamptz IS DISTINCT FROM
      (p_snapshot->>'assigned_at')::timestamptz THEN
    RAISE EXCEPTION 'ETA_CONTEXT_CHANGED';
  END IF;
  -- First committed forecast wins, even if later calculations finish out of order.
  IF v_order.delivery_eta->>'calculation_mode'='assignment_once_v1'
    AND v_order.delivery_eta->>'computed_at' IS NOT NULL THEN
    RETURN v_order.delivery_eta;
  END IF;
  IF p_snapshot->>'calculation_mode' IS DISTINCT FROM 'assignment_once_v1'
    OR p_snapshot->>'driver_id' IS DISTINCT FROM p_driver_id::text
    OR p_snapshot->>'phase' IS DISTINCT FROM 'fixed'
    OR p_snapshot->>'computed_at' IS NULL
    OR p_snapshot->>'initial_predicted_at' IS NULL
    OR p_snapshot->>'assigned_at' IS NULL
    OR (p_snapshot->>'computed_at')::timestamptz > clock_timestamp() + interval '30 seconds'
    OR (p_snapshot->>'computed_at')::timestamptz < clock_timestamp() - interval '2 minutes'
    OR COALESCE((p_snapshot->>'initial_total_minutes')::numeric,-1) < 10 THEN
    RAISE EXCEPTION 'INVALID_ETA_SNAPSHOT';
  END IF;
  -- GPS departure can arrive while OSRM is running. Apply it to the original
  -- result without calculating new routes or allowing the response to erase it.
  v_snapshot:=private.apply_fixed_eta_departure(p_snapshot,
    (v_order.delivery_eta->>'departed_at')::timestamptz);
  UPDATE public.orders SET delivery_eta=v_snapshot WHERE id=p_order_id;
  RETURN v_snapshot;
END;
$$;
REVOKE ALL ON FUNCTION public.commit_order_delivery_eta(uuid,uuid,text,timestamptz,timestamptz,timestamptz,jsonb)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.commit_order_delivery_eta(uuid,uuid,text,timestamptz,timestamptz,timestamptz,jsonb)
TO service_role;
