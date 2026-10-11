-- Proposal for the user's 2026-10-11 rule: an unanswered, expired invitation
-- counts as one refusal, together with manual transfers. No tables/columns/RLS
-- or Edge Functions change. Backend SQL separately approved on 2026-10-11.

CREATE OR REPLACE FUNCTION private.record_driver_offer_refusal(
  p_order_id uuid,
  p_driver_user_id uuid,
  p_status public.order_status,
  p_occurred_at timestamptz,
  p_expired boolean
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
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
$$;
REVOKE ALL ON FUNCTION private.record_driver_offer_refusal(
  uuid, uuid, public.order_status, timestamptz, boolean
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.clear_order_offer_on_inactive_state()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  -- Observe OLD before clearing/replacing it. This covers cron/redispatch,
  -- the final offer at the 15-minute assignment timeout, and a FreePick claim
  -- replacing an expired offer. Early cancellation/acceptance is not a refusal.
  IF OLD.offered_driver_id IS NOT NULL
    AND OLD.driver_id IS NULL
    AND OLD.assignment_timed_out_at IS NULL
    AND OLD.status IN ('pending', 'confirmed')
    AND OLD.offer_expires_at IS NOT NULL
    AND OLD.offer_expires_at <= clock_timestamp()
    AND (
      NEW.offered_driver_id IS DISTINCT FROM OLD.offered_driver_id
      OR NEW.offer_expires_at IS DISTINCT FROM OLD.offer_expires_at
      OR NEW.driver_id IS NOT NULL
      OR NEW.assignment_timed_out_at IS NOT NULL
      OR NEW.status NOT IN ('pending', 'confirmed')
    ) THEN
    PERFORM private.record_driver_offer_refusal(
      OLD.id, OLD.offered_driver_id, OLD.status, OLD.offer_expires_at, true
    );
  END IF;

  IF NEW.driver_id IS NOT NULL
    OR NEW.assignment_timed_out_at IS NOT NULL
    OR NEW.status NOT IN ('pending', 'confirmed') THEN
    NEW.offered_driver_id := NULL;
    NEW.offer_expires_at := NULL;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.clear_order_offer_on_inactive_state()
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.reject_order(
  p_order_id uuid, p_driver_user_id text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_excluded jsonb;
  v_now timestamptz;
  v_locked_until timestamptz;
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
  IF v_order.offered_driver_id IS DISTINCT FROM v_actor
    THEN RAISE EXCEPTION 'ORDER_NOT_OFFERED_TO_DRIVER'; END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended('driver-assignment:' || v_actor::text, 0)
  );
  SELECT acceptance_locked_until INTO v_locked_until
  FROM public.drivers WHERE user_id = v_actor FOR UPDATE;
  v_now := clock_timestamp();
  IF v_order.assignment_expires_at <= v_now THEN
    PERFORM private.dispatch_next_order_offer(p_order_id, 5000);
    RETURN NULL;
  END IF;
  IF v_order.offer_expires_at IS NULL OR v_order.offer_expires_at <= v_now THEN
    -- The offer-clearing trigger records an expired invitation once. A late
    -- manual request cannot add a second event or attribute it to another driver.
    RETURN private.dispatch_next_order_offer(p_order_id, 5000);
  END IF;
  IF v_locked_until > v_now THEN RAISE EXCEPTION 'DRIVER_ACCEPTANCE_LOCKED'; END IF;

  v_excluded := COALESCE(v_order.rejected_by, '[]'::jsonb);
  IF NOT (v_excluded ? v_actor::text) THEN
    v_excluded := v_excluded || jsonb_build_array(v_actor::text);
  END IF;
  UPDATE public.orders SET rejected_by = v_excluded,
    offered_driver_id = NULL, offer_expires_at = NULL WHERE id = p_order_id;
  PERFORM private.record_driver_offer_refusal(
    p_order_id, v_actor, v_order.status, v_now, false
  );
  RETURN private.dispatch_next_order_offer(p_order_id, 5000);
END;
$$;
REVOKE ALL ON FUNCTION public.reject_order(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reject_order(uuid, text) TO authenticated;
