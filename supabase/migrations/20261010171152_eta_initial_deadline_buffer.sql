-- User-approved policy: initial fixed ETA + 25 minutes. No new tables/columns.
CREATE OR REPLACE FUNCTION public.accept_driver_order_with_deadline(p_order_id uuid, p_driver_id uuid, p_route_duration_s integer, p_free_pick boolean DEFAULT false, p_quote_source text DEFAULT 'osrm'::text, p_existing_only boolean DEFAULT false)
 RETURNS TABLE(order_id uuid, customer_id uuid, tracking_code text, estimated_delivery_at timestamp with time zone)
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_order public.orders%ROWTYPE;
  v_claims text := current_setting('request.jwt.claims', true);
BEGIN
  IF p_driver_id IS NULL OR p_route_duration_s IS NULL
    OR p_route_duration_s < 0 OR p_route_duration_s > 86400
    OR p_quote_source IS NULL OR p_quote_source NOT IN ('osrm','distance_fallback') THEN
    RAISE EXCEPTION 'INVALID_DELIVERY_QUOTE';
  END IF;
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  -- A retry after a lost response must neither accept twice nor extend the deadline.
  IF v_order.driver_id = p_driver_id
    AND v_order.status IN ('assigned','picking_up','delivering')
    THEN
    RETURN QUERY SELECT v_order.id,v_order.customer_id,v_order.tracking_code,
      v_order.estimated_delivery_at;
    RETURN;
  END IF;
  IF v_order.driver_id IS NOT NULL AND NOT (
    v_order.driver_id = p_driver_id AND v_order.status IN ('assigned','picking_up','delivering')
  ) THEN
    RAISE EXCEPTION 'ORDER_NOT_AVAILABLE';
  END IF;
  IF p_existing_only AND v_order.driver_id IS NULL THEN
    RAISE EXCEPTION 'ORDER_NOT_AVAILABLE';
  END IF;
  -- Identity has already been verified with Auth.getUser in the Edge Function.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub',p_driver_id,'role','authenticated')::text,true);
  IF v_order.driver_id IS NULL THEN
    IF p_free_pick THEN
      PERFORM public.claim_free_pick_order(p_order_id);
    ELSE
      PERFORM public.accept_order(p_order_id);
    END IF;
  END IF;
  PERFORM set_config('request.jwt.claims',COALESCE(v_claims,''),true);
  -- Deadline is committed atomically with the first fixed ETA, never from an OSRM quote.
  SELECT * INTO v_order FROM public.orders WHERE id=p_order_id;
  RETURN QUERY SELECT v_order.id,v_order.customer_id,v_order.tracking_code,
    v_order.estimated_delivery_at;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.commit_order_delivery_eta(p_order_id uuid, p_driver_id uuid, p_status text, p_pickup_arrived_at timestamp with time zone, p_actual_picked_up_at timestamp with time zone, p_delivery_arrived_at timestamp with time zone, p_snapshot jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
  UPDATE public.orders SET delivery_eta=v_snapshot,
    estimated_delivery_at=(v_snapshot->>'initial_predicted_at')::timestamptz + interval '25 minutes'
  WHERE id=p_order_id;
  INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
  VALUES(p_order_id,v_order.status,'Đã xác lập hạn giao',
    'Hạn giao = ETA ban đầu + 25 phút; giữ nguyên khi khởi hành sớm.',p_driver_id);
  RETURN v_snapshot;
END;
$function$
;

-- Clear a previous assignment's deadline along with its ETA.
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
    NEW.estimated_delivery_at := NULL;
  END IF;
  RETURN NEW;
END;
$$;

-- One-time conversion of active orders only; preserve completed-order history.
WITH changed AS (
  UPDATE public.orders SET estimated_delivery_at =
    (delivery_eta->>'initial_predicted_at')::timestamptz + interval '25 minutes'
  WHERE status IN ('assigned','picking_up','delivering')
    AND delivery_eta->>'calculation_mode'='assignment_once_v1'
    AND delivery_eta->>'driver_id'=driver_id::text
    AND delivery_eta->>'initial_predicted_at' IS NOT NULL
    AND estimated_delivery_at IS DISTINCT FROM
      (delivery_eta->>'initial_predicted_at')::timestamptz + interval '25 minutes'
  RETURNING id,status,driver_id
)
INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
SELECT id,status,'Đã xác lập hạn giao',
  'Chuyển chính sách: Hạn giao = ETA ban đầu + 25 phút.',driver_id FROM changed;

COMMENT ON COLUMN public.orders.estimated_delivery_at IS
  'Server-owned deadline: initial fixed assignment ETA plus 25 minutes. Unchanged by early departure.';

-- No old-formula deadline while waiting for the first forecast.
UPDATE public.orders SET estimated_delivery_at=NULL
WHERE status IN ('assigned','picking_up','delivering')
  AND (delivery_eta->>'calculation_mode' IS DISTINCT FROM 'assignment_once_v1'
    OR delivery_eta->>'initial_predicted_at' IS NULL);
