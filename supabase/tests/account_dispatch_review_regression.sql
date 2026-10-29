-- Live verification: no committed business writes; repeat existing reviews only.
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '20s';
DO $test$
DECLARE
  signature text;
  item record;
  receipt jsonb;
  total_before bigint;
  expected_average numeric;
  expected_count integer;
  checked integer := 0;
BEGIN
  FOREACH signature IN ARRAY ARRAY[
    'private.driver_account_access_gate(uuid)',
    'private.account_disabled_at(uuid,timestamptz)',
    'public.commit_road_driver_offer(uuid,jsonb)',
    'public.accept_driver_order_with_deadline(uuid,uuid,integer,boolean,text,boolean)'
  ] LOOP
    IF has_function_privilege('anon',signature,'EXECUTE')
      OR has_function_privilege('authenticated',signature,'EXECUTE') THEN
      RAISE EXCEPTION 'Unexpected client permission: %',signature;
    END IF;
    IF NOT has_function_privilege('service_role',signature,'EXECUTE') THEN
      RAISE EXCEPTION 'Missing server permission: %',signature;
    END IF;
  END LOOP;
  FOREACH signature IN ARRAY ARRAY[
    'public.submit_customer_driver_review(uuid,integer,text,text[])',
    'public.submit_driver_customer_review(uuid,integer,text,text[])'
  ] LOOP
    IF has_function_privilege('anon',signature,'EXECUTE')
      OR NOT has_function_privilege('authenticated',signature,'EXECUTE') THEN
      RAISE EXCEPTION 'Review permission mismatch: %',signature;
    END IF;
  END LOOP;

  FOR item IN SELECT u.id,u.role::text role,a.banned_until FROM public.users u JOIN auth.users a ON a.id=u.id LOOP
    IF private.driver_account_access_gate(item.id) IS DISTINCT FROM
      (item.role='driver' AND NOT COALESCE(item.banned_until>clock_timestamp(),false)) THEN
      RAISE EXCEPTION 'Native account gate mismatch';
    END IF;
  END LOOP;
  IF private.driver_account_access_gate('00000000-0000-0000-0000-000000000000') THEN
    RAISE EXCEPTION 'Missing account passes gate';
  END IF;
  IF EXISTS(
    SELECT 1 FROM public.orders o CROSS JOIN LATERAL private.road_driver_candidates(o.id) c
    JOIN auth.users a ON a.id=c.user_id WHERE a.banned_until>now()
  ) THEN RAISE EXCEPTION 'Disabled candidate visible'; END IF;

  SELECT count(*) INTO total_before FROM public.reviews;
  FOR item IN
    SELECT DISTINCT ON(r.direction) r.*
    FROM public.reviews r JOIN public.orders o ON o.id=r.order_id
    JOIN public.users u ON u.id=r.reviewer_id
    WHERE o.status='delivered'
      AND ((r.direction='customer_to_driver' AND u.role='customer' AND o.customer_id=u.id)
        OR (r.direction='driver_to_customer' AND u.role='driver' AND o.driver_id=u.id))
    ORDER BY r.direction,r.created_at DESC
  LOOP
    PERFORM set_config('request.jwt.claim.sub',item.reviewer_id::text,true);
    PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',item.reviewer_id,'role','authenticated')::text,true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    IF item.direction='customer_to_driver' THEN
      receipt := public.submit_customer_driver_review(item.order_id,item.rating,item.comment,item.tags);
    ELSE
      receipt := public.submit_driver_customer_review(item.order_id,item.rating,item.comment,item.tags);
    END IF;
    EXECUTE 'RESET ROLE';
    IF receipt->>'review_id' IS DISTINCT FROM item.id::text
      OR (receipt->>'rating')::integer IS DISTINCT FROM item.rating
      OR receipt->>'direction' IS DISTINCT FROM item.direction
      OR (receipt->>'already_reviewed')::boolean IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'Retry receipt mismatch';
    END IF;
    checked := checked+1;
  END LOOP;
  IF checked<>2 THEN RAISE EXCEPTION 'Expected both review directions, checked %',checked; END IF;
  IF (SELECT count(*) FROM public.reviews)<>total_before THEN
    RAISE EXCEPTION 'Retry inserted a review';
  END IF;
  IF EXISTS(
    SELECT 1 FROM public.drivers d JOIN (
      SELECT driver_id,round(avg(rating)::numeric,1) rating,count(*) n
      FROM public.reviews WHERE direction='customer_to_driver' GROUP BY driver_id
    ) r ON r.driver_id=d.id
    WHERE d.rating IS DISTINCT FROM r.rating OR d.rating_count IS DISTINCT FROM r.n
  ) OR EXISTS(
    SELECT 1 FROM public.users u JOIN (
      SELECT reviewee_id,round(avg(rating)::numeric,1) rating,count(*) n
      FROM public.reviews WHERE direction='driver_to_customer' GROUP BY reviewee_id
    ) r ON r.reviewee_id=u.id
    WHERE u.customer_rating IS DISTINCT FROM r.rating OR u.customer_rating_count IS DISTINCT FROM r.n
  ) THEN RAISE EXCEPTION 'Aggregate mismatch'; END IF;
  RAISE NOTICE 'Account guards, permissions and both review retry/aggregate checks passed';
END;
$test$;
ROLLBACK;
