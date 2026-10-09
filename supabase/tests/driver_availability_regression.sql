-- Fixtures and all availability changes are rolled back.
BEGIN;
DO $test$
DECLARE
  customer_id uuid := gen_random_uuid();
  driver_id uuid;
  order_id uuid;
  active_status text;
  before_order jsonb;
  before_driver jsonb;
  after_driver jsonb;
  result boolean;
BEGIN
  INSERT INTO public.users(id,email,full_name,role) VALUES
    (customer_id,customer_id::text || '@availability-test.invalid','Availability test customer','customer');

  FOREACH active_status IN ARRAY ARRAY['assigned','picking_up','delivering','return_approved','returning'] LOOP
    order_id := gen_random_uuid();
    driver_id := gen_random_uuid();
    INSERT INTO public.users(id,email,full_name,role) VALUES
      (driver_id,driver_id::text || '@availability-test.invalid','Availability test driver','driver');
    INSERT INTO public.drivers(user_id,is_available,approval_status,current_lat,current_lng,location_updated_at)
    VALUES (driver_id,true,'approved',80,160,clock_timestamp());
    INSERT INTO public.orders(id,customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,
      delivery_address,delivery_lat,delivery_lng,tracking_code)
    VALUES (order_id,customer_id,driver_id,active_status::public.order_status,'Test pickup',80,160,
      'Test delivery',80.01,160.01,'GH-AVAILABILITY-' || order_id::text);
    SELECT to_jsonb(o) INTO before_order FROM public.orders o WHERE o.id = order_id;
    SELECT to_jsonb(d) INTO before_driver FROM public.drivers d WHERE d.user_id = driver_id;

    PERFORM set_config('request.jwt.claim.sub',driver_id::text,true);
    SET LOCAL ROLE authenticated;
    result := public.set_driver_availability(false);
    IF result IS DISTINCT FROM false THEN RAISE EXCEPTION 'OFF failed for %', active_status; END IF;
    -- Repeating OFF remains safe while the order is active.
    PERFORM public.set_driver_availability(false);
    RESET ROLE;

    SELECT to_jsonb(d) INTO after_driver FROM public.drivers d WHERE d.user_id = driver_id;
    IF after_driver->>'is_available' <> 'false' THEN RAISE EXCEPTION 'Availability stayed ON'; END IF;
    IF (before_driver - 'is_available' - 'updated_at') IS DISTINCT FROM
       (after_driver - 'is_available' - 'updated_at') THEN
      RAISE EXCEPTION 'OFF changed unrelated driver fields';
    END IF;
    IF before_order IS DISTINCT FROM (SELECT to_jsonb(o) FROM public.orders o WHERE o.id = order_id) THEN
      RAISE EXCEPTION 'OFF changed active order %', active_status;
    END IF;
  END LOOP;

  -- A temporary intake lock must still allow stopping new orders.
  UPDATE public.drivers SET is_available = true WHERE user_id = driver_id;
  UPDATE public.drivers SET acceptance_locked_until = clock_timestamp() + interval '30 minutes'
    WHERE user_id = driver_id;
  SET LOCAL ROLE authenticated;
  result := public.set_driver_availability(false);
  IF result IS DISTINCT FROM false THEN RAISE EXCEPTION 'Locked driver could not turn OFF'; END IF;

  BEGIN
    PERFORM public.set_driver_availability(true);
    RAISE EXCEPTION 'Expected PIN/location requirement';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'DRIVER_ONLINE_REQUIRES_PIN_AND_LOCATION' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.set_driver_availability(NULL);
    RAISE EXCEPTION 'Expected null rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'DRIVER_AVAILABILITY_REQUIRED' THEN RAISE; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub','',true);
  BEGIN
    PERFORM public.set_driver_availability(false);
    RAISE EXCEPTION 'Expected authentication rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'AUTH_REQUIRED' THEN RAISE; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  BEGIN
    PERFORM public.set_driver_availability(false);
    RAISE EXCEPTION 'Expected missing profile rejection';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'APPROVED_DRIVER_REQUIRED' THEN RAISE; END IF;
  END;
  RESET ROLE;
  IF has_function_privilege('anon','public.set_driver_availability(boolean)','EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous caller can execute availability RPC';
  END IF;
  IF NOT has_function_privilege('authenticated','public.set_driver_availability(boolean)','EXECUTE') THEN
    RAISE EXCEPTION 'Authenticated caller cannot execute availability RPC';
  END IF;
END;
$test$;
ROLLBACK;
SELECT 'availability regression passed; fixtures rolled back' AS result;
