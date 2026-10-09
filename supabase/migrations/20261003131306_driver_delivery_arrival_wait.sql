-- Mốc đến điểm giao nằm trong audit hiện có, không thêm bảng/cột/trạng thái đơn.
CREATE UNIQUE INDEX order_status_logs_delivery_arrival_once
  ON public.order_status_logs(order_id, logged_by)
  WHERE title = 'Tài xế đã đến điểm giao';

CREATE FUNCTION private.guard_delivery_arrival_audit()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF current_user IN ('anon', 'authenticated') THEN
    IF TG_OP <> 'INSERT' AND OLD.title = 'Tài xế đã đến điểm giao' THEN
      RAISE EXCEPTION 'DELIVERY_ARRIVAL_SERVER_OWNED' USING ERRCODE = '42501';
    END IF;
    IF TG_OP <> 'DELETE' AND NEW.title = 'Tài xế đã đến điểm giao' THEN
      RAISE EXCEPTION 'DELIVERY_ARRIVAL_SERVER_OWNED' USING ERRCODE = '42501';
    END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER order_status_logs_guard_delivery_arrival
  BEFORE INSERT OR UPDATE OR DELETE ON public.order_status_logs
  FOR EACH ROW EXECUTE FUNCTION private.guard_delivery_arrival_audit();

CREATE FUNCTION public.get_driver_delivery_arrival(p_order_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_arrived timestamptz;
  v_now timestamptz := clock_timestamp();
BEGIN
  IF v_actor IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.users WHERE id = v_actor AND role = 'driver'
  ) THEN RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED' USING ERRCODE = '42501'; END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND OR v_order.driver_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED' USING ERRCODE = '42501';
  END IF;
  SELECT created_at INTO v_arrived FROM public.order_status_logs
  WHERE order_id = p_order_id AND logged_by = v_actor
    AND title = 'Tài xế đã đến điểm giao';
  RETURN jsonb_build_object(
    'delivery_arrived_at', v_arrived, 'server_now', v_now,
    'can_report_recipient', COALESCE(v_order.status = 'delivering'
      AND v_arrived IS NOT NULL AND v_now >= v_arrived + interval '10 minutes', false));
END;
$$;

CREATE FUNCTION public.confirm_driver_delivery_arrival(p_order_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_driver public.drivers%ROWTYPE;
BEGIN
  IF v_actor IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.users WHERE id = v_actor AND role = 'driver'
  ) THEN RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED' USING ERRCODE = '42501'; END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR v_order.driver_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED' USING ERRCODE = '42501';
  END IF;
  IF v_order.status <> 'delivering' THEN
    RAISE EXCEPTION 'DELIVERY_ARRIVAL_INVALID_STATUS' USING ERRCODE = '23514';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.order_status_logs WHERE order_id = p_order_id
    AND logged_by = v_actor AND title = 'Tài xế đã đến điểm giao') THEN
    -- Dùng vị trí mới nhất đã đồng bộ; không tin tọa độ truyền vào RPC.
    SELECT * INTO v_driver FROM public.drivers WHERE user_id = v_actor;
    IF NOT FOUND OR v_driver.location_updated_at IS NULL
      OR v_driver.location_updated_at < clock_timestamp() - interval '60 seconds'
      OR v_driver.location_updated_at > clock_timestamp() + interval '5 seconds'
      OR v_driver.current_lat IS NULL OR v_driver.current_lng IS NULL
      OR NOT (v_driver.current_lat BETWEEN -90 AND 90 AND v_driver.current_lng BETWEEN -180 AND 180) THEN
      RAISE EXCEPTION 'DELIVERY_LOCATION_STALE' USING ERRCODE = '23514';
    END IF;
    IF NOT public.ST_DWithin(
      public.ST_SetSRID(public.ST_MakePoint(v_driver.current_lng, v_driver.current_lat), 4326)::public.geography,
      public.ST_SetSRID(public.ST_MakePoint(v_order.delivery_lng, v_order.delivery_lat), 4326)::public.geography, 100
    ) THEN RAISE EXCEPTION 'DELIVERY_OUTSIDE_GEOFENCE' USING ERRCODE = '23514'; END IF;
    INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by,created_at)
    VALUES(p_order_id,v_order.status,'Tài xế đã đến điểm giao',
      'Bắt đầu chờ 10 phút. Báo cáo không liên lạc cần ảnh lịch sử ít nhất 3 cuộc gọi trong thời gian chờ.',
      v_actor,clock_timestamp());
  END IF;
  RETURN public.get_driver_delivery_arrival(p_order_id);
END;
$$;

-- Defense in depth: chặn thời gian chờ cả khi có đường INSERT ngoài RPC.
CREATE FUNCTION private.guard_recipient_contact_report()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_order public.orders%ROWTYPE; v_arrived timestamptz;
BEGIN
  IF NEW.category <> 'contact_issue' OR NEW.source <> 'manual'
    OR NOT EXISTS (SELECT 1 FROM public.users WHERE id = NEW.reported_by AND role = 'driver') THEN
    RETURN NEW;
  END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = NEW.order_id FOR UPDATE;
  IF v_order.status = 'delivering' THEN
    SELECT created_at INTO v_arrived FROM public.order_status_logs
    WHERE order_id = NEW.order_id AND logged_by = NEW.reported_by
      AND title = 'Tài xế đã đến điểm giao';
    IF v_arrived IS NULL THEN
      RAISE EXCEPTION 'DELIVERY_ARRIVAL_REQUIRED' USING ERRCODE = '23514';
    END IF;
    IF clock_timestamp() < v_arrived + interval '10 minutes' THEN
      RAISE EXCEPTION 'RECIPIENT_WAIT_REQUIRED' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER risk_reports_guard_recipient_contact
  BEFORE INSERT ON public.risk_reports FOR EACH ROW
  EXECUTE FUNCTION private.guard_recipient_contact_report();

-- RPC ghi ảnh sau INSERT report; kiểm tra ảnh cuối transaction, không chặn RPC hợp lệ.
CREATE FUNCTION private.require_recipient_call_evidence()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.category = 'contact_issue' AND NEW.source = 'manual'
    AND NEW.reporter_role_snapshot = 'driver'
    AND EXISTS (SELECT 1 FROM public.order_status_logs WHERE order_id = NEW.order_id
      AND logged_by = NEW.reported_by AND title = 'Tài xế đã đến điểm giao')
    AND NOT EXISTS (SELECT 1 FROM public.risk_report_attachments
      WHERE risk_report_id = NEW.id AND evidence_type = 'photo'
        AND storage_path IS NOT NULL AND length(trim(storage_path)) > 0) THEN
    RAISE EXCEPTION 'RECIPIENT_CALL_EVIDENCE_REQUIRED' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;
CREATE CONSTRAINT TRIGGER risk_reports_require_recipient_call_evidence
  AFTER INSERT ON public.risk_reports DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION private.require_recipient_call_evidence();

CREATE FUNCTION private.record_recipient_contact_wait()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_arrived timestamptz;
BEGIN
  IF NEW.category = 'contact_issue' AND NEW.source = 'manual' AND NEW.reporter_role_snapshot = 'driver' THEN
    SELECT created_at INTO v_arrived FROM public.order_status_logs
    WHERE order_id = NEW.order_id AND logged_by = NEW.reported_by
      AND title = 'Tài xế đã đến điểm giao';
    IF v_arrived IS NOT NULL THEN
      INSERT INTO public.risk_report_events(risk_report_id, actor_id, event_type, to_status, note, details)
      VALUES(NEW.id,NEW.reported_by,'note_added',NEW.status,
        'Bắt đầu chờ: ' || to_char(v_arrived AT TIME ZONE 'Asia/Ho_Chi_Minh','DD/MM/YYYY HH24:MI:SS')
          || '. Khoảng gọi đến: ' || to_char((v_arrived + interval '10 minutes') AT TIME ZONE 'Asia/Ho_Chi_Minh','DD/MM/YYYY HH24:MI:SS')
          || ' (giờ Việt Nam). CSKH đối chiếu số người nhận và ít nhất 3 cuộc gọi trong khoảng này; ghi kết quả xác minh trước khi duyệt hoàn hàng.',
        jsonb_build_object('verification_type','recipient_wait','delivery_arrived_at',v_arrived,
          'call_window_ends_at',v_arrived + interval '10 minutes',
          'minimum_call_attempts',3,'call_evidence_review_required',true));
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER risk_reports_record_recipient_wait
  AFTER INSERT ON public.risk_reports FOR EACH ROW
  EXECUTE FUNCTION private.record_recipient_contact_wait();

REVOKE ALL ON FUNCTION public.get_driver_delivery_arrival(uuid),
  public.confirm_driver_delivery_arrival(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_driver_delivery_arrival(uuid),
  public.confirm_driver_delivery_arrival(uuid) TO authenticated;
REVOKE ALL ON FUNCTION private.guard_delivery_arrival_audit(),
  private.guard_recipient_contact_report(), private.require_recipient_call_evidence(), private.record_recipient_contact_wait()
  FROM PUBLIC, anon, authenticated;
