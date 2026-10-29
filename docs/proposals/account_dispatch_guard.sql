-- Được người dùng duyệt sửa ngày 2026-10-24; bản nguồn cho migration account_dispatch_guard.
-- Tách vô hiệu hóa tài khoản khỏi bộ đếm từ chối, không sửa khóa nhận đơn.
-- Khóa theo thứ tự order -> driver advisory -> public.users -> auth.users.
CREATE FUNCTION private.driver_account_access_gate(p_user_id uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE native_until timestamptz;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('driver-assignment:' || p_user_id::text,0));
  PERFORM 1 FROM public.users u WHERE u.id=p_user_id AND u.role='driver' FOR KEY SHARE;
  IF NOT FOUND THEN RETURN false; END IF;
  SELECT a.banned_until INTO native_until FROM auth.users a WHERE a.id=p_user_id FOR SHARE;
  RETURN FOUND AND NOT COALESCE(native_until>clock_timestamp(),false);
END;
$fn$;

CREATE FUNCTION private.account_disabled_at(p_user_id uuid,p_at timestamptz) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT COALESCE((SELECT e.action<>'release' AND (e.disabled_until IS NULL OR e.disabled_until>p_at)
   FROM public.account_control_events e WHERE e.user_id=p_user_id AND e.created_at<=p_at
   ORDER BY e.event_seq DESC LIMIT 1),false);
$fn$;
REVOKE ALL ON FUNCTION private.driver_account_access_gate(uuid),private.account_disabled_at(uuid,timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION private.driver_account_access_gate(uuid),private.account_disabled_at(uuid,timestamptz) TO service_role;

CREATE OR REPLACE FUNCTION public.commit_road_driver_offer(p_order_id uuid, p_candidates jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_order public.orders%ROWTYPE; v_driver public.drivers%ROWTYPE; v_quote jsonb;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR v_order.offered_driver_id IS NOT NULL OR NOT EXISTS
    (SELECT 1 FROM private.road_driver_candidates(p_order_id)) THEN RETURN NULL; END IF;
  IF jsonb_typeof(p_candidates) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'INVALID_ROAD_QUOTES'; END IF;
  FOR v_quote IN SELECT q FROM jsonb_array_elements(p_candidates) q
    ORDER BY (q->>'distance_meters')::double precision,
      (q->>'duration_seconds')::double precision,q->>'user_id'
  LOOP
    PERFORM pg_advisory_xact_lock(hashtextextended('driver-assignment:' || (v_quote->>'user_id'),0));
    IF NOT private.driver_account_access_gate((v_quote->>'user_id')::uuid) THEN CONTINUE; END IF;
    SELECT d.* INTO v_driver FROM public.drivers d
      JOIN private.road_driver_candidates(p_order_id) c ON c.user_id = d.user_id
      WHERE d.user_id = (v_quote->>'user_id')::uuid FOR UPDATE OF d;
    IF NOT FOUND OR v_driver.is_available IS DISTINCT FROM true
      OR v_driver.approval_status <> 'approved'
      OR v_driver.acceptance_locked_until > clock_timestamp()
      OR v_driver.location_updated_at < clock_timestamp() - interval '3 minutes'
      OR NOT private.valid_pickup_road_quote(v_quote,v_driver,v_order,0,2000) THEN CONTINUE; END IF;
    BEGIN
      UPDATE public.orders SET offered_driver_id = v_driver.user_id,
        offer_expires_at = LEAST(clock_timestamp() + interval '45 seconds',assignment_expires_at),
        status_note = NULL WHERE id = p_order_id AND driver_id IS NULL AND offered_driver_id IS NULL
        AND assignment_timed_out_at IS NULL AND assignment_expires_at > clock_timestamp()
        AND status IN ('pending','confirmed');
      IF FOUND THEN
        INSERT INTO public.notifications(user_id,title,body,type,is_read,order_id)
          VALUES(v_driver.user_id,'Đơn giao hàng mới',
            format('Đơn %s đang chờ bạn nhận. Điểm lấy: %s',v_order.tracking_code,v_order.pickup_address),
            'order_update',false,p_order_id);
        INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
          VALUES(p_order_id,v_order.status,'Đã gửi lời mời tài xế',
            format('Lời mời 45 giây; khoảng cách theo tuyến đường OSRM: %s m.',
              round((v_quote->>'distance_meters')::numeric)),NULL);
        RETURN v_driver.user_id;
      END IF;
    EXCEPTION WHEN unique_violation THEN CONTINUE;
    END;
  END LOOP;
  RETURN NULL;
END;
$function$;

CREATE OR REPLACE FUNCTION private.record_driver_offer_refusal(p_order_id uuid, p_driver_user_id uuid, p_status order_status, p_occurred_at timestamp with time zone, p_expired boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_now timestamptz;
  v_locked_until timestamptz;
  v_count integer;
BEGIN
  -- Callers already hold the order row. Match acceptance's assignment gate,
  -- then lock the driver before checking audit/threshold; retries are harmless.
  PERFORM pg_advisory_xact_lock(
    hashtextextended('driver-assignment:' || p_driver_user_id::text, 0)
  );
  SELECT acceptance_locked_until INTO v_locked_until
  FROM public.drivers WHERE user_id = p_driver_user_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  v_now := clock_timestamp();
  IF p_occurred_at IS NULL OR p_occurred_at > v_now THEN RETURN; END IF;
  IF p_expired THEN
    PERFORM private.driver_account_access_gate(p_driver_user_id);
    IF private.account_disabled_at(p_driver_user_id,p_occurred_at) THEN RETURN; END IF;
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.order_status_logs
    WHERE order_id = p_order_id AND logged_by = p_driver_user_id
      AND title = 'Tài xế từ chối lời mời'
  ) THEN RETURN; END IF;

  INSERT INTO public.order_status_logs(
    order_id, status, title, description, logged_by, created_at
  ) VALUES (
    p_order_id, p_status, 'Tài xế từ chối lời mời',
    CASE WHEN p_expired
      THEN 'Tài xế không phản hồi trước khi lời mời hết hạn. Tính một lượt từ chối; hệ thống chuyển lời mời.'
      ELSE 'Tài xế chuyển lời mời đến tài xế phù hợp tiếp theo. Tính một lượt từ chối.'
    END, p_driver_user_id, p_occurred_at
  );

  -- Preserve an existing cooldown, including the separate late-delivery rule.
  -- Expiry is still audited, but cannot extend or shorten a running lock.
  IF v_locked_until > v_now THEN RETURN; END IF;
  SELECT count(*)::integer INTO v_count
  FROM private.driver_transfer_window(p_driver_user_id, v_now);
  IF v_count < 4 THEN RETURN; END IF;

  v_locked_until := v_now + interval '30 minutes';
  UPDATE public.drivers SET acceptance_locked_until = v_locked_until,
    updated_at = v_now WHERE user_id = p_driver_user_id;
  INSERT INTO public.order_status_logs(
    order_id, status, title, description, logged_by, created_at
  )
  SELECT recent.order_id, recent.status, 'Đã tính đơn vào khóa chuyển đơn',
    format('4 đơn từ chối (chuyển hoặc hết thời gian nhận) trong 30 phút; khóa nhận đơn mới đến %s. Không tính lại đơn này.',
      v_locked_until), p_driver_user_id, v_now
  FROM private.driver_transfer_window(p_driver_user_id, v_now) recent
  ORDER BY recent.transferred_at, recent.order_id LIMIT 4;
  INSERT INTO public.notifications(
    user_id, title, body, type, is_read, order_id, created_at
  ) VALUES (
    p_driver_user_id, 'Tạm khóa nhận đơn 30 phút',
    'Bạn đã từ chối 4 đơn trong 30 phút gần nhất (chuyển đơn hoặc hết thời gian nhận). Hết 30 phút bạn có thể nhận đơn mới.',
    'system', false, p_order_id, v_now
  );
END;
$function$;

CREATE OR REPLACE FUNCTION private.road_driver_candidates(p_order_id uuid)
 RETURNS TABLE(user_id uuid, current_lat double precision, current_lng double precision)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT d.user_id, d.current_lat, d.current_lng
  FROM public.orders o CROSS JOIN public.drivers d
  WHERE o.id = p_order_id
    AND o.driver_id IS NULL AND o.status IN ('pending','confirmed')
    AND o.assignment_timed_out_at IS NULL AND o.assignment_expires_at > now()
    AND o.payment_status IN ('paid','not_required')
    AND COALESCE(o.note,'') <> 'FREEPICK_DEMO_PERSISTENT'
    AND (o.offered_driver_id IS NULL OR o.offer_expires_at <= now())
    AND EXISTS(SELECT 1 FROM auth.users a WHERE a.id=d.user_id
      AND (a.banned_until IS NULL OR a.banned_until<=statement_timestamp()))
    AND d.is_available AND d.approval_status = 'approved'
    AND (d.acceptance_locked_until IS NULL OR d.acceptance_locked_until <= now())
    AND d.current_lat IS NOT NULL AND d.current_lng IS NOT NULL
    AND d.location_updated_at >= now() - interval '3 minutes'
    AND NOT (COALESCE(o.rejected_by,'[]'::jsonb) ? d.user_id::text)
    AND COALESCE((SELECT sum(w.available_delta) FROM public.driver_wallet_transactions w
      WHERE w.driver_id = d.user_id AND w.status = 'completed'),0) >= o.driver_advance_amount
    AND NOT EXISTS (SELECT 1 FROM public.orders a WHERE a.driver_id = d.user_id
      AND a.status IN ('assigned','picking_up','delivering','return_approved','returning'))
    AND NOT EXISTS (SELECT 1 FROM public.orders a WHERE a.id <> o.id
      AND a.offered_driver_id = d.user_id AND a.driver_id IS NULL
      AND a.assignment_timed_out_at IS NULL AND a.status IN ('pending','confirmed')
      AND a.offer_expires_at > now())
    -- Geographic distance only limits API work. Include a 200 m snapping margin.
    AND public.ST_DWithin(public.ST_SetSRID(public.ST_MakePoint(d.current_lng,d.current_lat),4326)::public.geography,
      public.ST_SetSRID(public.ST_MakePoint(o.pickup_lng,o.pickup_lat),4326)::public.geography,2200)
  ORDER BY d.user_id;
$function$;

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
  IF NOT private.driver_account_access_gate(p_driver_id) THEN
    RAISE EXCEPTION 'ACCOUNT_DISABLED' USING ERRCODE='42501';
  END IF;
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
$function$;
