-- Run as postgres. Read-only checks against actual accounts; no business writes.
BEGIN READ ONLY;
DO $test$
DECLARE
  actors jsonb;
  actor jsonb;
  baseline jsonb;
  stats jsonb;
  signature text;
  statement text;
  expected_accounts bigint;
  expected_orders bigint;
  expected_drivers jsonb;
  actual_count bigint;
  page_count integer;
  page_offset integer;
  seen uuid[];
  account record;
  approval text;
  checked_staff integer := 0;
  checked_denied integer := 0;
BEGIN
  FOREACH signature IN ARRAY ARRAY[
    'public.admin_dashboard_stats()', 'public.admin_list_orders(text)',
    'public.admin_list_drivers(text)', 'public.list_admin_accounts(text,text,integer,integer)',
    'private.list_admin_accounts(text,text,integer,integer)'
  ] LOOP
    IF has_function_privilege('anon',signature,'EXECUTE') THEN
      RAISE EXCEPTION 'Anonymous Admin API permission: %',signature;
    END IF;
  END LOOP;
  SELECT jsonb_build_object(
    'total_orders',(SELECT count(*) FROM public.orders),
    'pending_orders',(SELECT count(*) FROM public.orders WHERE status='pending'),
    'delivering_orders',(SELECT count(*) FROM public.orders WHERE status IN('assigned','picking_up','delivering')),
    'completed_orders',(SELECT count(*) FROM public.orders WHERE status='delivered'),
    'total_drivers',(SELECT count(*) FROM public.drivers),
    'active_drivers',(SELECT count(*) FROM public.drivers WHERE is_available=true AND approval_status='approved'),
    'pending_drivers',(SELECT count(*) FROM public.drivers WHERE approval_status='pending'),
    'total_customers',(SELECT count(*) FROM public.users WHERE role::text='customer'),
    'total_revenue',COALESCE((SELECT sum(total_price) FROM public.orders WHERE status='delivered'),0)
  ) INTO baseline;
  SELECT count(*) INTO expected_accounts FROM public.users;
  SELECT least(count(*),100) INTO expected_orders FROM public.orders;
  SELECT jsonb_object_agg(approval_status,n) INTO expected_drivers FROM (
    SELECT approval_status::text,count(*) n FROM public.drivers GROUP BY approval_status
  ) counts;
  SELECT jsonb_agg(jsonb_build_object('id',id,'role',role)) INTO actors FROM public.users;
  -- Missing sub and a subject with no users row must both fail closed.
  actors:=actors||jsonb_build_array(jsonb_build_object('role','missing'),
    jsonb_build_object('id',gen_random_uuid(),'role','unknown'));
  FOR actor IN SELECT value FROM jsonb_array_elements(actors) LOOP
    PERFORM set_config('request.jwt.claims',jsonb_build_object(
      'sub',actor->>'id','role','authenticated')::text,true);
    SET LOCAL ROLE authenticated;
    IF actor->>'role'='admin' THEN
      checked_staff:=checked_staff+1;
      stats:=public.admin_dashboard_stats();
      IF stats<>baseline THEN RAISE EXCEPTION 'Admin statistics mismatch'; END IF;
      SELECT count(*) INTO actual_count FROM public.admin_list_orders(NULL);
      IF actual_count<>expected_orders THEN RAISE EXCEPTION 'Admin orders mismatch'; END IF;
      FOREACH approval IN ARRAY ARRAY['pending','approved','rejected'] LOOP
        SELECT count(*) INTO actual_count FROM public.admin_list_drivers(approval);
        IF actual_count<>COALESCE((expected_drivers->>approval)::bigint,0) THEN
          RAISE EXCEPTION 'Admin drivers mismatch';
        END IF;
      END LOOP;
      seen:=ARRAY[]::uuid[];page_offset:=0;
      LOOP
        page_count:=0;
        FOR account IN SELECT * FROM public.list_admin_accounts(p_offset=>page_offset,p_limit=>2) LOOP
          IF account.id=ANY(seen) THEN RAISE EXCEPTION 'Duplicate directory cursor'; END IF;
          seen:=array_append(seen,account.id);page_count:=page_count+1;
        END LOOP;
        EXIT WHEN page_count<2;
        page_offset:=page_offset+2;
        IF page_offset>expected_accounts+2 THEN RAISE EXCEPTION 'Directory pagination did not end'; END IF;
      END LOOP;
      IF cardinality(seen)<>expected_accounts THEN RAISE EXCEPTION 'Directory count mismatch'; END IF;
      SELECT count(*) INTO actual_count FROM public.users;
      IF actual_count<>1 THEN RAISE EXCEPTION 'Own-profile RLS unexpectedly changed'; END IF;
      BEGIN
        PERFORM * FROM public.list_admin_accounts(p_limit=>0);
        RAISE EXCEPTION 'Invalid page limit accepted';
      EXCEPTION WHEN invalid_parameter_value THEN NULL;
      END;
    ELSE
      checked_denied:=checked_denied+1;
      FOREACH statement IN ARRAY ARRAY[
        'SELECT public.admin_dashboard_stats()',
        'SELECT * FROM public.admin_list_orders(NULL)',
        'SELECT * FROM public.admin_list_drivers(''approved'')',
        'SELECT * FROM public.list_admin_accounts()',
        'SELECT * FROM private.list_admin_accounts()'
      ] LOOP
        BEGIN
          EXECUTE statement;
          RAISE EXCEPTION 'Non-admin API access succeeded';
        EXCEPTION WHEN insufficient_privilege THEN NULL;
        END;
      END LOOP;
    END IF;
    RESET ROLE;
  END LOOP;
  IF checked_staff<1 OR checked_denied<3 THEN RAISE EXCEPTION 'Insufficient role coverage'; END IF;
END;
$test$;
ROLLBACK;
SELECT 'admin read API regression passed' AS result;
