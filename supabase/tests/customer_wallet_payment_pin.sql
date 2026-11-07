-- Synthetic accounts, orders, Auth sessions and balances are rolled back.
BEGIN;
UPDATE public.system_settings SET value=(value||'{"platform_fee_version":1}'::jsonb)
 ||jsonb_build_object('values',(value->'values')||'{"customer_individual_fee_bps":500}'::jsonb)
WHERE key='business_settings';
DO $test$
DECLARE c uuid:=gen_random_uuid(); other_customer uuid:=gen_random_uuid(); seed uuid:=gen_random_uuid();
 sid uuid:=gen_random_uuid(); request_id uuid:=gen_random_uuid(); reset_id uuid:=gen_random_uuid();
 r jsonb; p jsonb; paid jsonb; policy jsonb; charge bigint; rev bigint; locked_at timestamptz; counter integer; verified_at timestamptz;
BEGIN
 INSERT INTO auth.users(id,email,email_confirmed_at) VALUES(c,c||'@pin-test.invalid',clock_timestamp());
 UPDATE public.users SET full_name='PIN test customer',customer_type='individual' WHERE id=c;
 INSERT INTO public.users(id,email,full_name,role,customer_type)
 VALUES(other_customer,other_customer||'@pin-test.invalid','Other PIN test customer','customer','individual');
 INSERT INTO public.orders(id,customer_id,status,pickup_address,pickup_lat,pickup_lng,delivery_address,delivery_lat,delivery_lng,delivery_fee,total_price,business_policy)
 VALUES(seed,c,'cancelled','Seed',80,160,'Seed delivery',80.01,160.01,18000,18000,private.legacy_business_settings());
 INSERT INTO public.customer_wallet_transactions(customer_id,order_id,transaction_type,amount,available_delta,idempotency_key)
 VALUES(c,seed,'delivery_credit',100000,100000,seed::text);
 rev:=(private.current_business_settings()->>'revision')::bigint;
 p:=jsonb_build_object('pickup_address','Pickup','pickup_lat',80,'pickup_lng',160,'delivery_address','Delivery','delivery_lat',80.01,'delivery_lng',160.01,
   'delivery_fee',18000,'goods_value',50000,'cod_collection_amount',0,'delivery_fee_payer','sender',
   'quoted_distance_m',2000,'settings_revision',rev,'quoted_customer_fee',900);
 policy:=private.order_fee_policy(c,private.current_business_settings());
 p:=p||jsonb_build_object('delivery_fee',private.calculate_business_cargo_order_fee(p,policy));
 p:=p||jsonb_build_object('quoted_customer_fee',private.customer_platform_fee((p->>'delivery_fee')::numeric,policy));
 charge:=(p->>'delivery_fee')::bigint+(p->>'quoted_customer_fee')::bigint;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated','email',c||'@pin-test.invalid','session_id',sid)::text,true);
 r:=public.get_customer_wallet_pin_status();
 ASSERT r->>'is_configured'='false','A new customer already has PIN';
 r:=public.create_customer_order_with_wallet(p,request_id,'001234');
 ASSERT r->>'code'='PIN_REQUIRED','Unconfigured customer paid';
 r:=public.set_customer_wallet_pin('001234',NULL);
 ASSERT r->>'ok'='true','Setup failed';
 ASSERT (SELECT pin_hash<>'001234' FROM private.customer_wallet_security WHERE customer_id=c),'Cleartext PIN';

 FOR counter IN 1..5 LOOP
   r:=public.create_customer_order_with_wallet(p,request_id,'999999');
   ASSERT r->>'code'=CASE WHEN counter=5 THEN 'PIN_LOCKED' ELSE 'PIN_INVALID' END,'Wrong failure state';
   ASSERT (r->>'attempts_remaining')::integer=5-counter,'Failure count rolled back';
 END LOOP;
 SELECT locked_until INTO locked_at FROM private.customer_wallet_security WHERE customer_id=c;
 ASSERT locked_at BETWEEN clock_timestamp()+interval '14 minutes' AND clock_timestamp()+interval '16 minutes','Incorrect lock time';
 r:=public.create_customer_order_with_wallet(p,request_id,'001234');
 ASSERT r->>'code'='PIN_LOCKED','Correct PIN bypassed active lock';
 r:=public.set_customer_wallet_pin('654321','001234');
 ASSERT r->>'code'='PIN_LOCKED','Change bypassed lock';
 ASSERT (SELECT sum(available_delta) FROM public.customer_wallet_transactions WHERE customer_id=c)=100000,'Failed payment debited';
 ASSERT (SELECT count(*) FROM public.orders WHERE customer_id=c)=1,'Failed payment created order';
 UPDATE private.customer_wallet_security SET locked_until=clock_timestamp()-interval '1 second' WHERE customer_id=c;
 r:=public.create_customer_order_with_wallet(p,request_id,'999999');
 ASSERT r->>'attempts_remaining'='4','Expired lock did not restart attempts';
 r:=public.set_customer_wallet_pin('654321','001234');
 ASSERT r->>'ok'='true','PIN change failed';
 r:=public.create_customer_order_with_wallet(p,request_id,'001234');
 ASSERT r->>'code'='PIN_INVALID','Old PIN still works';
 r:=public.create_customer_order_with_wallet(p||'{"quoted_customer_fee":-1}',request_id,'654321');
 ASSERT r->>'code'='SETTINGS_QUOTE_FEE_MISMATCH','Wrong quote accepted';
 r:=public.get_customer_wallet_pin_status();
 ASSERT r->>'attempts_remaining'='5','Correct PIN failed to reset attempts after quote rejection';
 paid:=public.create_customer_order_with_wallet(p,request_id,'654321');
 ASSERT paid->>'ok'='true' AND paid->'order'->>'payment_method'='wallet','Payment failed';
 ASSERT (SELECT sum(available_delta) FROM public.customer_wallet_transactions WHERE customer_id=c)=100000-charge,'Incorrect debit';
 UPDATE private.customer_wallet_security SET locked_until=clock_timestamp()+interval '15 minutes' WHERE customer_id=c;
 r:=public.create_customer_order_with_wallet(p,request_id,NULL);
 ASSERT r->'order'->>'id'=paid->'order'->>'id','Readback failed during lock';
 ASSERT (SELECT count(*) FROM public.customer_wallet_transactions WHERE customer_id=c AND transaction_type='delivery_fee_payment')=1,'Retry double debited';
 BEGIN
   PERFORM public.create_customer_order_with_wallet(p||'{"goods_value":60000}',request_id,NULL);
   RAISE EXCEPTION 'Accepted changed retry';
 EXCEPTION WHEN OTHERS THEN ASSERT SQLERRM='WALLET_REQUEST_PAYLOAD_MISMATCH','Wrong mismatch error'; END;

 -- All client entry points fail closed, including the old private helper.
 SET LOCAL ROLE authenticated;
 BEGIN
   PERFORM public.create_customer_order_with_wallet(p,gen_random_uuid());
   RAISE EXCEPTION 'Old RPC bypassed PIN';
 EXCEPTION WHEN OTHERS THEN ASSERT SQLERRM='CUSTOMER_WALLET_PIN_REQUIRED','Unexpected legacy error'; END;
 BEGIN
   PERFORM private.create_customer_order_with_wallet_unchecked(p,gen_random_uuid());
   RAISE EXCEPTION 'Unchecked helper exposed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
   PERFORM pin_hash FROM private.customer_wallet_security;
   RAISE EXCEPTION 'PIN hash exposed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
   PERFORM private.check_customer_wallet_pin(c,'654321');
   RAISE EXCEPTION 'Internal verifier exposed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 RESET ROLE;

 -- Server-side email recovery proof, not metadata, password, OAuth or JWT iat.
 INSERT INTO auth.sessions(id,user_id,created_at) VALUES(sid,c,clock_timestamp());
 r:=public.reset_customer_wallet_pin('123456',reset_id);
 ASSERT r->>'code'='EMAIL_VERIFICATION_REQUIRED','Reset without email proof';
 verified_at:=clock_timestamp();
 INSERT INTO auth.mfa_amr_claims(id,session_id,created_at,updated_at,authentication_method)
 VALUES(gen_random_uuid(),sid,verified_at,verified_at,'password');
 r:=public.reset_customer_wallet_pin('123456',reset_id);
 ASSERT r->>'code'='EMAIL_VERIFICATION_REQUIRED','Password session reset PIN';
 UPDATE auth.mfa_amr_claims SET authentication_method='recovery',created_at=clock_timestamp()-interval '6 minutes',updated_at=clock_timestamp()-interval '6 minutes' WHERE session_id=sid;
 r:=public.reset_customer_wallet_pin('123456',reset_id);
 ASSERT r->>'code'='EMAIL_VERIFICATION_REQUIRED','Expired email proof reset PIN';
 UPDATE auth.mfa_amr_claims SET created_at=verified_at,updated_at=verified_at WHERE session_id=sid;
 r:=public.reset_customer_wallet_pin('123456',reset_id);
 ASSERT r->>'ok'='true','Fresh recovery failed';
 ASSERT (SELECT locked_until IS NULL AND failed_attempts=0 FROM private.customer_wallet_security WHERE customer_id=c),'Recovery did not unlock';
 r:=public.reset_customer_wallet_pin('123456',reset_id);
 ASSERT r->>'ok'='true','Recovery lost-response retry failed';
 r:=public.reset_customer_wallet_pin('777777',gen_random_uuid());
 ASSERT r->>'code'='EMAIL_VERIFICATION_REQUIRED','Reused email proof';
 DELETE FROM auth.sessions WHERE id=sid;
 r:=public.reset_customer_wallet_pin('123456',reset_id);
 ASSERT r->>'code'='EMAIL_VERIFICATION_REQUIRED','Revoked recovery session accepted';
 PERFORM set_config('request.jwt.claim.sub',other_customer::text,true);
 r:=public.create_customer_order_with_wallet(p,request_id,NULL);
 ASSERT r->>'code'='PIN_REQUIRED','Other customer read payment receipt';
 PERFORM public.set_customer_wallet_pin('001234',NULL);
 PERFORM public.create_customer_order_with_wallet(p,gen_random_uuid(),'999999');
 r:=public.create_customer_order_with_wallet(p,gen_random_uuid(),'001234');
 ASSERT r->>'code'='CUSTOMER_WALLET_INSUFFICIENT_BALANCE','Empty wallet was not rejected';
 r:=public.get_customer_wallet_pin_status();
 ASSERT r->>'attempts_remaining'='5','Correct PIN failed to reset attempts after insufficient balance';
 ASSERT NOT EXISTS(SELECT 1 FROM public.orders WHERE customer_id=other_customer),'Insufficient balance created order';
 PERFORM set_config('request.jwt.claim.sub','',true);
 PERFORM set_config('request.jwt.claims','{}',true);
 BEGIN
   PERFORM public.get_customer_wallet_pin_status();
   RAISE EXCEPTION 'Anonymous read security';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;
$test$;
ROLLBACK;
