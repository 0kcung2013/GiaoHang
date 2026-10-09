-- Approved rule: 3 completed late orders in a rolling 2-hour window ->
-- 30-minute acceptance cooldown. Reuse orders, order_status_logs, drivers,
-- and notifications; do not create tables or columns or penalize old history.
CREATE UNIQUE INDEX order_status_logs_late_lock_once_idx
  ON public.order_status_logs(order_id,title)
  WHERE title IN ('Giao muộn đã ghi nhận','Đã tính đơn vào khóa giao muộn');
CREATE INDEX order_status_logs_late_window_idx
  ON public.order_status_logs(logged_by,created_at,order_id)
  WHERE title='Giao muộn đã ghi nhận';

-- These titles are machine-owned audit events. Clients cannot forge consumed
-- markers, move a deadline event to another driver, or delete penalty history.
CREATE OR REPLACE FUNCTION private.guard_delivery_policy_audit()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF current_user IN ('anon','authenticated') THEN
    IF TG_OP <> 'INSERT' AND OLD.title IN (
      'Đã xác lập hạn giao','Giao muộn đã ghi nhận','Đã tính đơn vào khóa giao muộn'
    ) THEN RAISE EXCEPTION 'DELIVERY_POLICY_AUDIT_SERVER_OWNED'; END IF;
    IF TG_OP <> 'DELETE' AND NEW.title IN (
      'Đã xác lập hạn giao','Giao muộn đã ghi nhận','Đã tính đơn vào khóa giao muộn'
    ) THEN RAISE EXCEPTION 'DELIVERY_POLICY_AUDIT_SERVER_OWNED'; END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_delivery_policy_audit() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER order_status_logs_guard_delivery_policy_audit
  BEFORE INSERT OR UPDATE OR DELETE ON public.order_status_logs
  FOR EACH ROW EXECUTE FUNCTION private.guard_delivery_policy_audit();

-- Internal trigger only. SECURITY DEFINER is needed to write the protected
-- driver cooldown and audit from any authorized order-completion path.
CREATE OR REPLACE FUNCTION private.record_late_delivery_acceptance_lock()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_completed_at timestamptz := clock_timestamp();
  v_locked_until timestamptz;
  v_event_id uuid;
  v_order_ids uuid[];
BEGIN
  IF NEW.status <> 'delivered' OR OLD.status = 'delivered'
    OR NEW.driver_id IS NULL OR NEW.estimated_delivery_at IS NULL
    OR v_completed_at <= NEW.estimated_delivery_at THEN RETURN NEW; END IF;
  -- Only use deadlines issued by our backend. Legacy/customer-supplied ETAs
  -- are not sufficient evidence for this acceptance cooldown.
  IF NOT EXISTS (
    SELECT 1 FROM public.order_status_logs
    WHERE order_id=NEW.id AND title='Đã xác lập hạn giao'
      AND logged_by=NEW.driver_id
  ) THEN RETURN NEW; END IF;
  -- Match the lock used by status progression/wallet settlement, then serialize
  -- per driver. A concurrent completion cannot consume the same three orders.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(NEW.driver_id::text,0));
  SELECT acceptance_locked_until INTO v_locked_until
  FROM public.drivers WHERE user_id=NEW.driver_id FOR UPDATE;
  IF NOT FOUND THEN RETURN NEW; END IF;

  INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by,created_at)
  VALUES(NEW.id,'delivered','Giao muộn đã ghi nhận',
    format('Hoàn tất quá hạn %s phút; hạn giao %s. Cửa sổ tính khóa: 2 giờ.',
      ceil(extract(epoch FROM v_completed_at-NEW.estimated_delivery_at)/60),
      NEW.estimated_delivery_at),NEW.driver_id,v_completed_at)
  ON CONFLICT(order_id,title) WHERE title IN (
    'Giao muộn đã ghi nhận','Đã tính đơn vào khóa giao muộn'
  ) DO NOTHING RETURNING id INTO v_event_id;
  IF v_event_id IS NULL THEN RETURN NEW; END IF;
  -- Never extend an existing cooldown while another lock is still in force.
  IF v_locked_until > v_completed_at THEN RETURN NEW; END IF;

  SELECT array_agg(recent.order_id) INTO v_order_ids FROM (
    SELECT event.order_id FROM public.order_status_logs event
    WHERE event.title='Giao muộn đã ghi nhận'
      AND event.logged_by=NEW.driver_id
      AND event.created_at >= v_completed_at-interval '2 hours'
      AND event.created_at <= v_completed_at
      AND NOT EXISTS (
        SELECT 1 FROM public.order_status_logs used
        WHERE used.order_id=event.order_id AND used.title='Đã tính đơn vào khóa giao muộn'
      )
    ORDER BY event.created_at,event.id LIMIT 3
  ) recent;
  IF COALESCE(cardinality(v_order_ids),0) < 3 THEN RETURN NEW; END IF;

  v_locked_until := v_completed_at + interval '30 minutes';
  UPDATE public.drivers SET acceptance_locked_until=v_locked_until,
    updated_at=clock_timestamp() WHERE user_id=NEW.driver_id;
  INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by,created_at)
  SELECT id,'delivered','Đã tính đơn vào khóa giao muộn',
    format('3 đơn giao muộn trong 2 giờ; khóa nhận đơn mới đến %s. Đơn này không được dùng lại.',
      v_locked_until),NEW.driver_id,v_completed_at FROM unnest(v_order_ids) AS id;
  INSERT INTO public.notifications(user_id,title,body,type,is_read,order_id,created_at)
  VALUES(NEW.driver_id,'Tạm khóa nhận đơn 30 phút',
    'Bạn đã hoàn tất 3 đơn giao muộn trong 2 giờ gần nhất. Hết 30 phút bạn có thể nhận đơn mới; đơn đang giao vẫn tiếp tục.',
    'system',false,NEW.id,v_completed_at);
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.record_late_delivery_acceptance_lock() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER orders_after_delivery_late_acceptance_lock AFTER UPDATE OF status
  ON public.orders FOR EACH ROW WHEN (NEW.status='delivered' AND OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION private.record_late_delivery_acceptance_lock();
COMMENT ON COLUMN public.drivers.acceptance_locked_until IS
  'Server-owned acceptance cooldown: personal cancellation or 3 late completions in 2 hours. Online intent and active delivery remain unchanged.';
