-- Synthetic profiles and rate changes are rolled back.
BEGIN;
DO $test$
DECLARE
 customer_id uuid:=gen_random_uuid(); other_id uuid:=gen_random_uuid();
 driver_id uuid:=gen_random_uuid(); admin_id uuid:=gen_random_uuid(); support_id uuid:=gen_random_uuid();
 baseline jsonb:=private.current_business_settings(); changed jsonb; saved jsonb;
 affected integer; invalid jsonb;
BEGIN
 INSERT INTO public.users(id,email,full_name,role) VALUES
 (customer_id,customer_id||'@classification.invalid','Customer','customer'),
 (other_id,other_id||'@classification.invalid','Other customer','customer'),
 (driver_id,driver_id||'@classification.invalid','Driver','driver'),
 (support_id,support_id||'@classification.invalid','Support','support'),
 (admin_id,admin_id||'@classification.invalid','Admin','admin');
 ASSERT (SELECT customer_type IS NULL FROM public.users WHERE id=customer_id), 'New customer must choose type';
 ASSERT NOT has_table_privilege('authenticated','public.system_settings','UPDATE'), 'Direct settings writes allowed';
 ASSERT NOT has_column_privilege('anon','public.users','customer_type','UPDATE'), 'Anonymous classification writes allowed';
 ASSERT NOT has_column_privilege('authenticated','public.users','role','UPDATE'), 'Classification grants changed role privileges';
 PERFORM set_config('request.jwt.claim.sub',customer_id::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',customer_id,'role','authenticated')::text,true);
 PERFORM set_config('role','authenticated',true);
 UPDATE public.users SET customer_type='individual' WHERE id=customer_id;
 ASSERT (SELECT customer_type='individual' FROM public.users WHERE id=customer_id), 'Own classification not saved';
 UPDATE public.users SET customer_type='individual' WHERE id=other_id;
 GET DIAGNOSTICS affected=ROW_COUNT;
 ASSERT affected=0, 'Changed another customer';
 BEGIN
   UPDATE public.users SET customer_type='business' WHERE id=customer_id;
   RAISE EXCEPTION 'Accepted incomplete business';
 EXCEPTION WHEN check_violation THEN NULL; END;
 UPDATE public.users SET customer_type='business', business_name='Example shop',
   business_address='123 Example Street',business_tax_code=NULL WHERE id=customer_id;
 ASSERT (SELECT business_name='Example shop' FROM public.users WHERE id=customer_id), 'Shop without tax code rejected';
 BEGIN
   UPDATE public.users SET business_tax_code='invalid' WHERE id=customer_id;
   RAISE EXCEPTION 'Accepted malformed tax code';
 EXCEPTION WHEN check_violation THEN NULL; END;
 UPDATE public.users SET customer_type='individual', business_name=NULL,
   business_address=NULL,business_tax_code=NULL WHERE id=customer_id;
 ASSERT (SELECT business_name IS NULL FROM public.users WHERE id=customer_id), 'Business data retained after switch';
 BEGIN
   UPDATE public.users SET customer_type='unknown' WHERE id=customer_id;
   RAISE EXCEPTION 'Accepted unknown type';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
   PERFORM public.update_business_settings(baseline->'values',(baseline->>'revision')::bigint,'Customer fee attempt');
   RAISE EXCEPTION 'Customer changed rates';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub',driver_id::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',driver_id,'role','authenticated')::text,true);
 BEGIN
   UPDATE public.users SET customer_type='individual' WHERE id=driver_id;
   RAISE EXCEPTION 'Driver obtained customer classification';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
   PERFORM public.update_business_settings(baseline->'values',(baseline->>'revision')::bigint,'Driver fee attempt');
   RAISE EXCEPTION 'Driver changed rates';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub',support_id::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',support_id,'role','authenticated')::text,true);
 BEGIN
   PERFORM public.update_business_settings(baseline->'values',(baseline->>'revision')::bigint,'Support fee attempt');
   RAISE EXCEPTION 'Support changed rates';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub',admin_id::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
 FOREACH invalid IN ARRAY ARRAY['10001'::jsonb,'-1'::jsonb,'0.5'::jsonb,'"5"'::jsonb,'null'::jsonb] LOOP
   BEGIN
     PERFORM public.update_business_settings((baseline->'values')||jsonb_build_object('driver_platform_fee_bps',invalid),
       (baseline->>'revision')::bigint,'Invalid rate attempt');
     RAISE EXCEPTION 'Accepted invalid rate';
   EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 END LOOP;
 changed:=(baseline->'values')||'{"customer_individual_fee_bps":500,"customer_business_fee_bps":250,"driver_platform_fee_bps":1234}'::jsonb;
 saved:=public.update_business_settings(changed,(baseline->>'revision')::bigint,'Synthetic platform fee change');
 ASSERT saved->'values'=changed, 'Admin rates not saved';
 ASSERT (public.get_business_settings_history(NULL,1)->0->'previous_values')=baseline->'values', 'Missing fee audit';
 BEGIN
   PERFORM public.update_business_settings(changed,(baseline->>'revision')::bigint,'Stale rate change');
   RAISE EXCEPTION 'Accepted stale rate change';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub',customer_id::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',customer_id,'role','authenticated')::text,true);
 ASSERT public.get_business_settings()->'values'->>'customer_individual_fee_bps'='500', 'Customer cannot read rates';
 PERFORM set_config('role','postgres',true);
 ASSERT private.calculate_business_delivery_fee(3000,baseline)=private.calculate_business_delivery_fee(3000,saved), 'Display rate changed delivery quote';
 ASSERT public.get_platform_fee_amount()=0, 'Preview enabled legacy collection';
END;
$test$;
SELECT 'customer_classification_platform_fee_passed' AS result;
ROLLBACK;
