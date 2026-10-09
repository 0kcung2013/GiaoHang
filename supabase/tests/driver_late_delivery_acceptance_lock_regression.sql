-- Run in a test/staging project. Requires an approved idle driver and a
-- delivered template order. Fixture orders, locks, notifications and stats
-- are all rolled back; no historical real order is changed.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT set_config('request.jwt.claims','{}',true);

CREATE FUNCTION pg_temp.late_test_order(p_driver uuid,p_deadline timestamptz,p_issued boolean DEFAULT true)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
  v_template public.orders%ROWTYPE;
  v_id uuid := gen_random_uuid();
BEGIN
  SELECT * INTO STRICT v_template FROM public.orders
  WHERE status='delivered' AND tracking_code NOT LIKE 'TEST-LATE-%' LIMIT 1;
  INSERT INTO public.orders SELECT (jsonb_populate_record(NULL::public.orders,
    to_jsonb(v_template) || jsonb_build_object(
      'id',v_id,'tracking_code','TEST-LATE-'||v_id::text,'driver_id',p_driver,
      'status','delivering','created_at',clock_timestamp(),'updated_at',clock_timestamp(),
      'estimated_delivery_at',p_deadline,'actual_delivered_at',NULL,'cancelled_at',NULL,
      'offered_driver_id',NULL,'offer_expires_at',NULL,'risk_hold_report_id',NULL,
      'assignment_timed_out_at',NULL,'assignment_expires_at',clock_timestamp()+interval '1 hour'
    ))).*;
  IF p_issued THEN
    INSERT INTO public.order_status_logs(order_id,status,title,logged_by)
    VALUES(v_id,'assigned','Đã xác lập hạn giao',p_driver);
  END IF;
  RETURN v_id;
END;
$$;

DO $$
DECLARE
  v_driver uuid;
  v_id uuid;
  v_first uuid;
  v_third uuid;
  v_start timestamptz;
  v_lock timestamptz;
  v_again timestamptz;
  v_available boolean;
BEGIN
  SELECT d.user_id,d.is_available INTO STRICT v_driver,v_available
  FROM public.drivers d WHERE d.approval_status='approved'
    AND (d.acceptance_locked_until IS NULL OR d.acceptance_locked_until<=clock_timestamp())
    AND NOT EXISTS(SELECT 1 FROM public.orders o WHERE o.driver_id=d.user_id
      AND o.status NOT IN ('delivered','cancelled','returned')) LIMIT 1 FOR UPDATE;
  PERFORM set_config('test.late_driver_id',v_driver::text,true);
  UPDATE public.drivers SET acceptance_locked_until=NULL WHERE user_id=v_driver;

  -- Missing deadlines, on-time deliveries and legacy ETAs cannot create events.
  v_id := pg_temp.late_test_order(v_driver,NULL);
  UPDATE public.orders SET status='delivered' WHERE id=v_id;
  v_id := pg_temp.late_test_order(v_driver,clock_timestamp()+interval '1 hour');
  UPDATE public.orders SET status='delivered' WHERE id=v_id;
  v_id := pg_temp.late_test_order(v_driver,clock_timestamp()-interval '1 minute',false);
  UPDATE public.orders SET status='delivered' WHERE id=v_id;
  IF EXISTS(SELECT 1 FROM public.order_status_logs WHERE logged_by=v_driver AND title='Giao muộn đã ghi nhận') THEN
    RAISE EXCEPTION 'Non-qualifying deliveries counted';
  END IF;

  -- Two late orders do not lock acceptance.
  FOR i IN 1..2 LOOP
    v_id := pg_temp.late_test_order(v_driver,clock_timestamp()-interval '1 minute');
    UPDATE public.orders SET status='delivered' WHERE id=v_id;
    IF i=1 THEN v_first:=v_id; END IF;
  END LOOP;
  IF (SELECT acceptance_locked_until FROM public.drivers WHERE user_id=v_driver) IS NOT NULL THEN
    RAISE EXCEPTION 'Locked before the third late completion';
  END IF;

  -- An event outside the rolling window is excluded.
  UPDATE public.order_status_logs SET created_at=clock_timestamp()-interval '2 hours 1 minute'
  WHERE order_id=v_first AND title='Giao muộn đã ghi nhận';
  v_id := pg_temp.late_test_order(v_driver,clock_timestamp()-interval '1 minute');
  UPDATE public.orders SET status='delivered' WHERE id=v_id;
  IF (SELECT acceptance_locked_until FROM public.drivers WHERE user_id=v_driver) IS NOT NULL THEN
    RAISE EXCEPTION 'Counted an expired event';
  END IF;

  v_id := pg_temp.late_test_order(v_driver,clock_timestamp()-interval '1 minute');
  v_start:=clock_timestamp();
  UPDATE public.orders SET status='delivered' WHERE id=v_id;
  v_third:=v_id;
  SELECT acceptance_locked_until INTO v_lock FROM public.drivers WHERE user_id=v_driver;
  IF v_lock IS NULL OR v_lock<v_start+interval '30 minutes'
    OR v_lock>clock_timestamp()+interval '30 minutes' THEN RAISE EXCEPTION 'Incorrect 30-minute lock'; END IF;
  IF (SELECT count(*) FROM public.order_status_logs WHERE logged_by=v_driver AND title='Đã tính đơn vào khóa giao muộn')<>3 THEN
    RAISE EXCEPTION 'Did not consume exactly three orders';
  END IF;
  IF (SELECT is_available FROM public.drivers WHERE user_id=v_driver) IS DISTINCT FROM v_available THEN
    RAISE EXCEPTION 'Changed online intent';
  END IF;
  IF (SELECT count(*) FROM public.notifications WHERE user_id=v_driver AND title='Tạm khóa nhận đơn 30 phút')<>1 THEN
    RAISE EXCEPTION 'Missing or duplicated lock notification';
  END IF;

  -- Terminal replay never counts again or extends the lock.
  UPDATE public.orders SET status='delivered' WHERE id=v_third;
  UPDATE public.orders SET status='delivering' WHERE id=v_third;
  UPDATE public.orders SET status='delivered' WHERE id=v_third;
  SELECT acceptance_locked_until INTO v_again FROM public.drivers WHERE user_id=v_driver;
  IF v_again IS DISTINCT FROM v_lock OR
    (SELECT count(*) FROM public.order_status_logs WHERE order_id=v_third AND title='Giao muộn đã ghi nhận')<>1 THEN
    RAISE EXCEPTION 'Replay recounted an order or extended the lock';
  END IF;

  -- Both normal acceptance and FreePick reject the driver using existing guards.
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_driver,'role','authenticated')::text,true);
  BEGIN
    PERFORM public.accept_order(gen_random_uuid());
    RAISE EXCEPTION 'Normal acceptance ignored the lock';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'DRIVER_ACCEPTANCE_LOCKED' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.claim_free_pick_order(gen_random_uuid());
    RAISE EXCEPTION 'FreePick ignored the lock';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'DRIVER_ACCEPTANCE_LOCKED' THEN RAISE; END IF;
  END;
  PERFORM set_config('request.jwt.claims','{}',true);

  -- After expiry, the consumed batch cannot cause another lock.
  UPDATE public.drivers SET acceptance_locked_until=clock_timestamp()-interval '1 second' WHERE user_id=v_driver;
  FOR i IN 1..2 LOOP
    v_id := pg_temp.late_test_order(v_driver,clock_timestamp()-interval '1 minute');
    UPDATE public.orders SET status='delivered' WHERE id=v_id;
    IF (SELECT acceptance_locked_until>clock_timestamp() FROM public.drivers WHERE user_id=v_driver) THEN
      RAISE EXCEPTION 'Reused consumed orders after expiry';
    END IF;
  END LOOP;
  v_id := pg_temp.late_test_order(v_driver,clock_timestamp()-interval '1 minute');
  UPDATE public.orders SET status='delivered' WHERE id=v_id;
  IF NOT (SELECT acceptance_locked_until>clock_timestamp() FROM public.drivers WHERE user_id=v_driver) THEN
    RAISE EXCEPTION 'Three new late orders did not lock again';
  END IF;
  IF (SELECT count(*) FROM public.order_status_logs WHERE logged_by=v_driver AND title='Đã tính đơn vào khóa giao muộn')<>6 THEN
    RAISE EXCEPTION 'Second batch consumption failed';
  END IF;

  -- Preserve a different cooldown; an already-assigned order can still finish.
  UPDATE public.drivers SET acceptance_locked_until=NULL WHERE user_id=v_driver;
  v_id := pg_temp.late_test_order(v_driver,clock_timestamp()-interval '1 minute');
  v_lock:=clock_timestamp()+interval '1 hour';
  UPDATE public.drivers SET acceptance_locked_until=v_lock WHERE user_id=v_driver;
  UPDATE public.orders SET status='delivered' WHERE id=v_id;
  IF (SELECT acceptance_locked_until FROM public.drivers WHERE user_id=v_driver) IS DISTINCT FROM v_lock THEN
    RAISE EXCEPTION 'Changed an existing lock';
  END IF;
  IF (SELECT status FROM public.orders WHERE id=v_id)<>'delivered' THEN
    RAISE EXCEPTION 'Blocked completion of the active order';
  END IF;
  PERFORM set_config('test.late_order_id',v_id::text,true);
END;
$$;

-- Audit events cannot be forged by the signed-in driver.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object(
  'sub',current_setting('test.late_driver_id'),'role','authenticated')::text,true);
DO $$
BEGIN
  BEGIN
    INSERT INTO public.order_status_logs(order_id,status,title,logged_by)
    VALUES(current_setting('test.late_order_id')::uuid,'delivered',
      'Đã tính đơn vào khóa giao muộn',current_setting('test.late_driver_id')::uuid);
    RAISE EXCEPTION 'Driver forged a consumed marker';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'DELIVERY_POLICY_AUDIT_SERVER_OWNED' THEN RAISE; END IF;
  END;
END;
$$;
ROLLBACK;
