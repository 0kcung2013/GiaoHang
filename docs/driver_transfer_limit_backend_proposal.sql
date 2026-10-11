-- Approved review snapshot. Already applied as migration
-- supabase/migrations/20261009153139_driver_offer_transfer_acceptance_lock.sql.
-- Use that migration as the deployment source; do not reapply this document.
-- Rule: 4 distinct successfully transferred offers within the last 30 minutes
-- cause a 30-minute acceptance cooldown. Reuse existing audit and driver fields.

CREATE INDEX IF NOT EXISTS order_status_logs_transfer_window_idx
  ON public.order_status_logs(logged_by, created_at, order_id)
  WHERE title = 'Tài xế từ chối lời mời';
CREATE UNIQUE INDEX IF NOT EXISTS order_status_logs_transfer_consumed_once_idx
  ON public.order_status_logs(logged_by, order_id)
  WHERE title = 'Đã tính đơn vào khóa chuyển đơn';

-- Preserve the existing delivery-policy guard and protect transfer audit too.
CREATE OR REPLACE FUNCTION private.guard_delivery_policy_audit()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF current_user IN ('anon', 'authenticated') THEN
    IF TG_OP <> 'INSERT' AND OLD.title IN (
      'Đã xác lập hạn giao', 'Giao muộn đã ghi nhận',
      'Đã tính đơn vào khóa giao muộn', 'Tài xế từ chối lời mời',
      'Đã tính đơn vào khóa chuyển đơn'
    ) THEN RAISE EXCEPTION 'DELIVERY_POLICY_AUDIT_SERVER_OWNED'; END IF;
    IF TG_OP <> 'DELETE' AND NEW.title IN (
      'Đã xác lập hạn giao', 'Giao muộn đã ghi nhận',
      'Đã tính đơn vào khóa giao muộn', 'Tài xế từ chối lời mời',
      'Đã tính đơn vào khóa chuyển đơn'
    ) THEN RAISE EXCEPTION 'DELIVERY_POLICY_AUDIT_SERVER_OWNED'; END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.driver_transfer_window(
  p_driver_user_id uuid, p_now timestamptz
)
RETURNS TABLE(order_id uuid, transferred_at timestamptz, status public.order_status)
LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT event.order_id, max(event.created_at),
    (array_agg(event.status ORDER BY event.created_at DESC, event.id DESC))[1]
  FROM public.order_status_logs event
  WHERE event.logged_by = p_driver_user_id
    AND event.title = 'Tài xế từ chối lời mời'
    AND event.created_at > p_now - interval '30 minutes'
    AND event.created_at <= p_now
    AND NOT EXISTS (
      SELECT 1 FROM public.order_status_logs used
      WHERE used.logged_by = p_driver_user_id AND used.order_id = event.order_id
        AND used.title = 'Đã tính đơn vào khóa chuyển đơn'
    )
  GROUP BY event.order_id;
$$;
REVOKE ALL ON FUNCTION private.driver_transfer_window(uuid, timestamptz)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_driver_acceptance_state()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
  v_deadline timestamptz;
  v_count integer;
  v_next_expiry timestamptz;
  v_reason text;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_actor AND role = 'driver')
    THEN RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED'; END IF;
  SELECT acceptance_locked_until INTO v_deadline
  FROM public.drivers WHERE user_id = v_actor;
  IF NOT FOUND THEN RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND'; END IF;

  SELECT count(*)::integer, min(transferred_at) + interval '30 minutes'
  INTO v_count, v_next_expiry FROM private.driver_transfer_window(v_actor, v_now);
  IF v_deadline > v_now AND EXISTS (
    SELECT 1 FROM public.order_status_logs
    WHERE logged_by = v_actor AND title = 'Đã tính đơn vào khóa chuyển đơn'
      AND created_at + interval '30 minutes' = v_deadline
  ) THEN v_reason := 'offer_transfers'; END IF;

  RETURN jsonb_build_object(
    'server_now', v_now, 'locked_until', v_deadline, 'lock_reason', v_reason,
    'transfer_count', v_count, 'transfer_next_expiry_at', v_next_expiry
  );
END;
$$;
REVOKE ALL ON FUNCTION public.get_driver_acceptance_state() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_driver_acceptance_state() TO authenticated;

-- Keep the existing arguments/uuid return contract and dispatch implementation.
CREATE OR REPLACE FUNCTION public.reject_order(p_order_id uuid, p_driver_user_id text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_excluded jsonb;
  v_now timestamptz;
  v_locked_until timestamptz;
  v_count integer;
BEGIN
  IF v_actor IS NULL OR v_actor::text IS DISTINCT FROM p_driver_user_id
    THEN RAISE EXCEPTION 'NOT_ALLOWED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_actor AND role = 'driver')
    THEN RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.drivers WHERE user_id = v_actor)
    THEN RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND'; END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR v_order.driver_id IS NOT NULL OR v_order.status NOT IN (
    'pending'::public.order_status, 'confirmed'::public.order_status
  ) THEN RAISE EXCEPTION 'ORDER_NOT_AVAILABLE'; END IF;
  IF v_order.assignment_timed_out_at IS NOT NULL THEN RETURN NULL; END IF;

  -- Same order -> assignment lock -> driver order as the acceptance/dispatch RPCs.
  -- A concurrent accept cannot pass the cooldown check while the fourth transfer
  -- is committing. Serializing by driver also prevents duplicate threshold locks.
  PERFORM pg_advisory_xact_lock(hashtextextended('driver-assignment:' || v_actor::text, 0));
  SELECT acceptance_locked_until INTO v_locked_until
  FROM public.drivers WHERE user_id = v_actor FOR UPDATE;
  v_now := clock_timestamp();
  IF v_order.assignment_expires_at <= v_now THEN
    PERFORM private.dispatch_next_order_offer(p_order_id, 5000);
    RETURN NULL;
  END IF;
  IF v_order.offered_driver_id IS DISTINCT FROM v_actor
    THEN RAISE EXCEPTION 'ORDER_NOT_OFFERED_TO_DRIVER'; END IF;
  IF v_order.offer_expires_at IS NULL OR v_order.offer_expires_at <= v_now THEN
    RETURN private.dispatch_next_order_offer(p_order_id, 5000);
  END IF;
  IF v_locked_until > v_now THEN RAISE EXCEPTION 'DRIVER_ACCEPTANCE_LOCKED'; END IF;

  v_excluded := COALESCE(v_order.rejected_by, '[]'::jsonb);
  IF NOT (v_excluded ? v_actor::text) THEN
    v_excluded := v_excluded || jsonb_build_array(v_actor::text);
  END IF;
  UPDATE public.orders SET rejected_by = v_excluded,
    offered_driver_id = NULL, offer_expires_at = NULL WHERE id = p_order_id;
  INSERT INTO public.order_status_logs(
    order_id, status, title, description, logged_by, created_at
  ) VALUES (
    p_order_id, v_order.status, 'Tài xế từ chối lời mời',
    'Hệ thống chuyển lời mời đến tài xế phù hợp tiếp theo.', v_actor, v_now
  );

  SELECT count(*)::integer INTO v_count
  FROM private.driver_transfer_window(v_actor, v_now);
  IF v_count >= 4 THEN
    v_locked_until := v_now + interval '30 minutes';
    UPDATE public.drivers SET acceptance_locked_until = v_locked_until,
      updated_at = v_now WHERE user_id = v_actor;
    INSERT INTO public.order_status_logs(
      order_id, status, title, description, logged_by, created_at
    )
    SELECT recent.order_id, recent.status, 'Đã tính đơn vào khóa chuyển đơn',
      format('4 đơn chuyển trong 30 phút; khóa nhận đơn mới đến %s. Không tính lại đơn này.',
        v_locked_until), v_actor, v_now
    FROM private.driver_transfer_window(v_actor, v_now) recent
    ORDER BY recent.transferred_at, recent.order_id LIMIT 4;
    INSERT INTO public.notifications(user_id, title, body, type, is_read, order_id, created_at)
    VALUES (v_actor, 'Tạm khóa nhận đơn 30 phút',
      'Bạn đã chuyển 4 đơn trong 30 phút gần nhất. Hết 30 phút bạn có thể nhận đơn mới.',
      'system', false, p_order_id, v_now);
  END IF;

  RETURN private.dispatch_next_order_offer(p_order_id, 5000);
END;
$$;
REVOKE ALL ON FUNCTION public.reject_order(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reject_order(uuid, text) TO authenticated;
