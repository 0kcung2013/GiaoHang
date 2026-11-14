-- Synthetic data only. All changes, including Auth fixtures, are rolled back.
BEGIN;
DO $test$
DECLARE c uuid:=gen_random_uuid(); other_c uuid:=gen_random_uuid(); d uuid:=gen_random_uuid();
 staff uuid:=gen_random_uuid(); admin_id uuid:=gen_random_uuid(); o uuid:=gen_random_uuid();
 report jsonb; page jsonb; affected integer;
BEGIN
 INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 (c,c||'@business-report.invalid','{}'),(other_c,other_c||'@business-report.invalid','{}'),
 (d,d||'@business-report.invalid','{}'),(staff,staff||'@business-report.invalid','{}'),
 (admin_id,admin_id||'@business-report.invalid','{}');
 INSERT INTO public.users(id,email,full_name,role) VALUES
 (c,c||'@business-report.invalid','Business report customer','customer'),
 (other_c,other_c||'@business-report.invalid','Other customer','customer'),
 (d,d||'@business-report.invalid','Driver','driver'),
 (staff,staff||'@business-report.invalid','Support','support'),
 (admin_id,admin_id||'@business-report.invalid','Admin','admin')
 ON CONFLICT(id) DO UPDATE SET role=excluded.role,full_name=excluded.full_name;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated')::text,true);
 PERFORM set_config('role','authenticated',true);
 UPDATE public.users SET customer_type='business',business_name='Unique reporting shop '||c,
 business_address='123 Test address',business_tax_code='1234567890' WHERE id=c AND customer_type IS NULL;
 ASSERT FOUND,'Initial classification failed';
 UPDATE public.users SET customer_type='business' WHERE id=c;
 UPDATE public.users SET full_name='Updated contact' WHERE id=c;
 BEGIN UPDATE public.users SET customer_type='individual',business_name=NULL,business_address=NULL,business_tax_code=NULL WHERE id=c;
   RAISE EXCEPTION 'Classification changed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.users SET business_name='Changed business' WHERE id=c;
   RAISE EXCEPTION 'Business identity changed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.users SET business_tax_code=NULL WHERE id=c;
   RAISE EXCEPTION 'Tax identity cleared'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE public.users SET customer_type='individual' WHERE id=other_c;
 GET DIAGNOSTICS affected=ROW_COUNT; ASSERT affected=0,'Changed another customer';
 report:=public.get_customer_business_report(c,'2026-10-31 17:00Z','2026-11-30 17:00Z');
 ASSERT report->'orders'='[]'::jsonb AND report->'movements'='[]'::jsonb,'Empty report wrong';
 BEGIN PERFORM public.get_customer_business_report(other_c,'2026-10-31 17:00Z','2026-11-30 17:00Z');
   RAISE EXCEPTION 'Read other customer'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.list_staff_accounts_v2();
   RAISE EXCEPTION 'Customer read staff directory'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.get_customer_business_report(c,'2025-01-01','2027-01-01');
   RAISE EXCEPTION 'Unbounded report'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 -- Legacy snapshot fixture bypasses the order-command requirement using the
 -- existing legacy policy; no production order or wallet is changed.
 INSERT INTO public.orders(id,customer_id,status,pickup_address,pickup_lat,pickup_lng,
   delivery_address,delivery_lat,delivery_lng,delivery_fee,total_price,cod_collection_amount,
   delivery_fee_payer,cancelled_at,business_policy)
 VALUES(o,c,'cancelled','Pickup',80,160,'Delivery',80.01,160.01,18000,18000,0,
   'recipient','2026-10-31 17:00Z',private.legacy_business_settings());
 INSERT INTO public.customer_wallet_transactions(customer_id,order_id,transaction_type,amount,
   available_delta,idempotency_key,completed_at)
 VALUES(c,o,'delivery_fee_refund',18000,18000,'report:'||o,'2026-11-30 16:59:59Z'),
 (c,o,'delivery_fee_refund',18000,18000,'report:excluded:'||o,'2026-11-30 17:00Z');
 PERFORM set_config('request.jwt.claim.sub',staff::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',staff,'role','authenticated')::text,true);
 PERFORM set_config('role','authenticated',true);
 report:=public.get_customer_business_report(c,'2026-10-31 17:00Z','2026-11-30 17:00Z');
 ASSERT jsonb_array_length(report->'orders')=1,'Inclusive start missed';
 ASSERT jsonb_array_length(report->'movements')=1,'Exclusive end broken';
 ASSERT (report->'movements'->0->>'amount')::bigint=18000,'Refund amount wrong';
 page:=public.list_staff_accounts_v2(p_search:=c::text,p_role:='customer',p_customer_type:='business');
 ASSERT jsonb_array_length(page->'rows')=1,'Server business filtering failed';
 ASSERT page->'rows'->0->>'business_tax_code'='1234567890','Business identity missing';
 page:=public.list_staff_accounts_v2(p_search:=c::text,p_customer_type:='individual');
 ASSERT page->'rows'='[]'::jsonb,'Filter applied after pagination';
 PERFORM set_config('role','postgres',true);
 BEGIN
   INSERT INTO public.customer_wallet_transactions(customer_id,order_id,transaction_type,amount,
     available_delta,idempotency_key,completed_at)
   SELECT c,o,'adjustment_credit',1,1,'report:limit:'||o||':'||n,'2026-11-01 00:00Z'
   FROM generate_series(1,5000) n;
   PERFORM public.get_customer_business_report(c,'2026-10-31 17:00Z','2026-11-30 17:00Z');
   RAISE EXCEPTION 'Oversized report was silently truncated';
 EXCEPTION WHEN program_limit_exceeded THEN NULL; END;
 PERFORM set_config('role','authenticated',true);
 PERFORM set_config('request.jwt.claim.sub',admin_id::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
 PERFORM public.get_customer_business_report(c,'2026-10-31 17:00Z','2026-11-30 17:00Z');
 PERFORM set_config('request.jwt.claim.sub',d::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',d,'role','authenticated')::text,true);
 BEGIN PERFORM public.get_customer_business_report(c,'2026-10-31 17:00Z','2026-11-30 17:00Z');
   RAISE EXCEPTION 'Driver read report'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 UPDATE auth.users SET banned_until=statement_timestamp()+interval '1 day' WHERE id=c;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated')::text,true);
 PERFORM set_config('role','authenticated',true);
 BEGIN PERFORM public.get_customer_business_report(c,'2026-10-31 17:00Z','2026-11-30 17:00Z');
   RAISE EXCEPTION 'Disabled customer read report'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('role','postgres',true);
 ASSERT NOT has_function_privilege('anon','public.get_customer_business_report(uuid,timestamptz,timestamptz)','EXECUTE'),'Anon report access';
 ASSERT NOT has_function_privilege('anon','public.list_staff_accounts_v2(text,text,boolean,integer,integer,text)','EXECUTE'),'Anon directory access';
END;
$test$;
SELECT 'customer_business_reporting: passed (rollback)' result;
ROLLBACK;
