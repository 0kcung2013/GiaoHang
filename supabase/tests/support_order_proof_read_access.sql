-- Read-only regression using current data; no fixtures or business writes.
-- Run as postgres after support_order_proof_read_access migration.
BEGIN READ ONLY;
DO $test$
DECLARE
  actors jsonb;
  actor jsonb;
  expected_proofs bigint;
  actual_proofs bigint;
  expected_files bigint;
  actual_files bigint;
  checked_staff integer := 0;
  checked_participants integer := 0;
BEGIN
  SELECT jsonb_agg(jsonb_build_object('id', id, 'role', role)) INTO actors
  FROM public.users WHERE role IN ('support', 'admin', 'customer', 'driver');
  IF actors IS NULL THEN RAISE EXCEPTION 'No actors available for RLS regression'; END IF;

  FOR actor IN SELECT value FROM jsonb_array_elements(actors) LOOP
    SELECT count(*) INTO expected_proofs FROM public.order_delivery_proofs proof
    JOIN public.orders proof_order ON proof_order.id = proof.order_id
    WHERE actor->>'role' IN ('support', 'admin')
      OR proof_order.customer_id = (actor->>'id')::uuid
      OR proof_order.driver_id = (actor->>'id')::uuid;
    SELECT count(*) INTO expected_files FROM storage.objects object
    JOIN public.order_delivery_proofs proof ON proof.storage_path = object.name
    JOIN public.orders proof_order ON proof_order.id = proof.order_id
    WHERE object.bucket_id = 'delivery-proofs'
      AND (actor->>'role' IN ('support', 'admin')
        OR proof_order.customer_id = (actor->>'id')::uuid
        OR proof_order.driver_id = (actor->>'id')::uuid);

    PERFORM set_config('request.jwt.claims',
      jsonb_build_object('sub', actor->>'id', 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    SELECT count(*) INTO actual_proofs FROM public.order_delivery_proofs;
    SELECT count(*) INTO actual_files FROM storage.objects object
    JOIN public.order_delivery_proofs proof ON proof.storage_path = object.name
    WHERE object.bucket_id = 'delivery-proofs';
    RESET ROLE;

    IF actual_proofs <> expected_proofs OR actual_files <> expected_files THEN
      RAISE EXCEPTION 'Proof RLS mismatch for role %: metadata %/%; files %/%',
        actor->>'role', actual_proofs, expected_proofs, actual_files, expected_files;
    END IF;
    IF actor->>'role' IN ('support', 'admin') THEN
      checked_staff := checked_staff + 1;
    ELSE
      checked_participants := checked_participants + 1;
    END IF;
  END LOOP;
  IF checked_staff < 2 OR checked_participants < 2 THEN
    RAISE EXCEPTION 'Insufficient staff/participant coverage';
  END IF;

  PERFORM set_config('request.jwt.claims', '{"role":"anon"}', true);
  SET LOCAL ROLE anon;
  IF has_table_privilege('anon', 'public.order_delivery_proofs', 'SELECT') THEN
    RAISE EXCEPTION 'Anonymous users unexpectedly have proof metadata access';
  END IF;
  RESET ROLE;
END;
$test$;
ROLLBACK;
