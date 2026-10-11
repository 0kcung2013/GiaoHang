-- Exercise the actual authenticated role; every fixture rolls back.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT set_config('giaohang.road_dispatch_requested','yes',true);
SELECT set_config('request.jwt.claims','{}',true);
DO $$
DECLARE
  c uuid; d uuid; s uuid; a uuid;
  o uuid := gen_random_uuid(); r uuid := gen_random_uuid(); expected jsonb;
BEGIN
  SELECT id INTO STRICT c FROM public.users WHERE role='customer' LIMIT 1;
  SELECT id INTO STRICT s FROM public.users WHERE role='support' LIMIT 1;
  SELECT id INTO STRICT a FROM public.users WHERE role='admin' LIMIT 1;
  SELECT user_id INTO STRICT d FROM public.drivers x WHERE NOT EXISTS (
    SELECT 1 FROM public.orders WHERE driver_id=x.user_id
      AND status IN ('assigned','picking_up','delivering')) LIMIT 1;
  INSERT INTO public.orders(id,customer_id,status,pickup_address,pickup_lat,pickup_lng,
    delivery_address,delivery_lat,delivery_lng,tracking_code,item_weight_kg)
  VALUES(o,c,'confirmed','Support contacts pickup',10.78,106.68,
    'Support contacts delivery',10.8,106.71,'TEST-SUPPORT-CONTACTS-'||o,2.75);
  UPDATE public.orders SET driver_id=d,status='picking_up' WHERE id=o;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
  PERFORM public.create_participant_risk_report(r,o,'cargo_issue',
    'Hàng thực tế quá cỡ, yêu cầu CSKH đối chiếu.',
    ARRAY['r2://media/orders/'||o||'/risk-evidence/'||r||'/photo.jpg'],NULL,NULL,NULL,ARRAY[]::uuid[]);
  SELECT jsonb_build_object('orders',jsonb_build_array(jsonb_build_object(
    'order_id',o,'customer_id',c,'driver_id',d,
    'customer',jsonb_build_object('full_name',sender.full_name,'phone',sender.phone,
      'email',sender.email,'avatar_url',sender.avatar_url),
    'driver',jsonb_build_object('full_name',driver.full_name,'phone',driver.phone,
      'email',driver.email,'avatar_url',driver.avatar_url)
  )), 'reporter',jsonb_build_object('full_name',driver.full_name,'phone',driver.phone,
    'email',driver.email,'avatar_url',driver.avatar_url,'role',driver.role::text))
  INTO expected FROM public.users sender CROSS JOIN public.users driver
  WHERE sender.id=c AND driver.id=d;
  PERFORM set_config('test.support_contacts_ids',jsonb_build_object('c',c,'d',d,'s',s,'a',a,'o',o,'r',r)::text,true);
  PERFORM set_config('test.support_contacts_expected',expected::text,true);
END;
$$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  ids jsonb := current_setting('test.support_contacts_ids')::jsonb;
  expected jsonb := current_setting('test.support_contacts_expected')::jsonb;
  actor text; actual jsonb; o uuid := (ids->>'o')::uuid;
BEGIN
  FOREACH actor IN ARRAY ARRAY['s','a'] LOOP
    PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',ids->>actor,'role','authenticated')::text,true);
    ASSERT (SELECT count(*) FROM public.users WHERE id IN ((ids->>'c')::uuid,(ids->>'d')::uuid))=0,
      'Direct user reads became visible to staff';
    actual:=public.get_support_order_contacts(ARRAY[o],(ids->>'r')::uuid);
    ASSERT actual=expected, 'Staff API dropped or mixed contact fields';
    ASSERT (public.get_support_order_contacts(ARRAY[gen_random_uuid()])->'orders')='[]'::jsonb,
      'Unknown order exposed unrelated contacts';
    BEGIN
      PERFORM public.get_support_order_contacts(ARRAY[gen_random_uuid()],(ids->>'r')::uuid);
      RAISE EXCEPTION 'Read reporter from a different order';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
      PERFORM public.get_support_order_contacts(ARRAY[]::uuid[]);
      RAISE EXCEPTION 'Empty contact scope accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
      PERFORM public.get_support_order_contacts(ARRAY[NULL::uuid]);
      RAISE EXCEPTION 'Null contact scope accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
      PERFORM public.get_support_order_contacts(array_fill(o,ARRAY[201]));
      RAISE EXCEPTION 'Unbounded contact scope accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  END LOOP;
  FOREACH actor IN ARRAY ARRAY['c','d'] LOOP
    PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',ids->>actor,'role','authenticated')::text,true);
    BEGIN
      PERFORM public.get_support_order_contacts(ARRAY[o]);
      RAISE EXCEPTION 'Participant called staff contact API';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  END LOOP;
  PERFORM set_config('request.jwt.claims','{}',true);
  BEGIN
    PERFORM public.get_support_order_contacts(ARRAY[o]);
    RAISE EXCEPTION 'Unauthenticated caller read contacts';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  ASSERT NOT has_function_privilege('anon','public.get_support_order_contacts(uuid[],uuid)','EXECUTE'),
    'Anon can execute the contact API';
END;
$$;
RESET ROLE;
SELECT 'support order contacts and permissions passed; fixtures rolled back' AS result;
ROLLBACK;
