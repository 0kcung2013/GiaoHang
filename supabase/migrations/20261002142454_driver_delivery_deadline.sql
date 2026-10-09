-- Reuse orders and order_status_logs. No new tables or columns.
-- Only the authenticated Edge Function may supply server-computed route time.
CREATE OR REPLACE FUNCTION public.accept_driver_order_with_deadline(
  p_order_id uuid, p_driver_id uuid, p_route_duration_s integer,
  p_free_pick boolean DEFAULT false, p_quote_source text DEFAULT 'osrm',
  p_existing_only boolean DEFAULT false
)
RETURNS TABLE(order_id uuid, customer_id uuid, tracking_code text,
  estimated_delivery_at timestamptz)
LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_claims text := current_setting('request.jwt.claims', true);
  v_accepted_at timestamptz;
  v_budget_minutes integer;
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
    AND v_order.estimated_delivery_at IS NOT NULL THEN
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
  v_accepted_at := clock_timestamp();
  v_budget_minutes := GREATEST(25,ceil(p_route_duration_s / 60.0 * 1.3 + 15)::integer);
  UPDATE public.orders SET estimated_delivery_at =
    v_accepted_at + make_interval(mins => v_budget_minutes)
  WHERE id=p_order_id RETURNING * INTO v_order;
  INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
  VALUES(p_order_id,v_order.status,'Đã xác lập hạn giao',
    format('Ngân sách %s phút; nguồn %s; thời gian tuyến %s giây. Không dùng tự động kết luận vi phạm.',
      v_budget_minutes,p_quote_source,p_route_duration_s),p_driver_id);
  RETURN QUERY SELECT v_order.id,v_order.customer_id,v_order.tracking_code,
    v_order.estimated_delivery_at;
END;
$$;
REVOKE ALL ON FUNCTION public.accept_driver_order_with_deadline(uuid,uuid,integer,boolean,text,boolean)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.accept_driver_order_with_deadline(uuid,uuid,integer,boolean,text,boolean)
  TO service_role;

CREATE OR REPLACE FUNCTION private.guard_delivery_deadline()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF current_user IN ('anon','authenticated')
    AND NEW.estimated_delivery_at IS DISTINCT FROM OLD.estimated_delivery_at THEN
    RAISE EXCEPTION 'DELIVERY_DEADLINE_SERVER_OWNED';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_delivery_deadline() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER orders_guard_delivery_deadline BEFORE UPDATE OF estimated_delivery_at
  ON public.orders FOR EACH ROW EXECUTE FUNCTION private.guard_delivery_deadline();
