-- Synthetic fixtures and settings changes are always rolled back.
BEGIN;
-- Keep these pricing/limits scenarios independent from Admin's fee rates.
UPDATE public.system_settings SET value=value||jsonb_build_object('values',
  (value->'values')||'{"customer_individual_fee_bps":0,"customer_business_fee_bps":0,"driver_platform_fee_bps":0}'::jsonb)
WHERE key='business_settings';
DO $test$
DECLARE
 admin_id uuid:=gen_random_uuid(); customer_id uuid:=gen_random_uuid(); support_id uuid:=gen_random_uuid(); driver_id uuid:=gen_random_uuid();
 baseline jsonb:=private.current_business_settings(); changed jsonb; saved jsonb;
 payload jsonb; cash_order public.orders%ROWTYPE; old_order public.orders%ROWTYPE; paid_order public.orders%ROWTYPE;
 session_row record; completion record; topup_row record; next_rev bigint;
BEGIN
 INSERT INTO public.users(id,email,full_name,role) VALUES
   (admin_id,admin_id||'@settings-test.invalid','Settings admin','admin'),
   (customer_id,customer_id||'@settings-test.invalid','Settings customer','customer'),
   (support_id,support_id||'@settings-test.invalid','Settings support','support'),
   (driver_id,driver_id||'@settings-test.invalid','Settings driver','driver');
 INSERT INTO public.drivers(user_id,is_available,approval_status) VALUES(driver_id,false,'approved');
 ASSERT NOT has_table_privilege('authenticated','public.system_settings','UPDATE'), 'Direct settings writes allowed';
 ASSERT NOT has_function_privilege('anon','public.update_business_settings(jsonb,bigint,text)','EXECUTE'), 'Anonymous settings write exposed';
 ASSERT NOT has_function_privilege('authenticated','private.create_customer_order_with_policy(uuid,jsonb,text,timestamptz,jsonb)','EXECUTE'), 'Trusted snapshot helper exposed';
 ASSERT private.calculate_business_delivery_fee(2000,baseline)=18000, 'Base fee';
 ASSERT private.calculate_business_delivery_fee(2150,baseline)=19000, 'Round up';
 ASSERT private.calculate_business_delivery_fee(12000,baseline)=68000, 'Single distance rate';
 PERFORM set_config('request.jwt.claim.sub',customer_id::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',customer_id,'role','authenticated')::text,true);
 BEGIN
   PERFORM public.update_business_settings(baseline->'values',(baseline->>'revision')::bigint,'Customer attempt');
   RAISE EXCEPTION 'Customer changed settings';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 payload:=jsonb_build_object('pickup_address','Synthetic pickup','pickup_lat',80,'pickup_lng',160,
   'delivery_address','Synthetic drop','delivery_lat',80.01,'delivery_lng',160.01,
   'delivery_fee',23000,'quoted_distance_m',3000,'settings_revision',(baseline->>'revision')::bigint,
   'delivery_fee_payer','recipient','goods_value',0,'cod_collection_amount',100000);
 SELECT * INTO old_order FROM private.create_customer_order_from_payload(customer_id,payload,'not_required',NULL);
 ASSERT old_order.business_policy=private.order_fee_policy(customer_id,baseline), 'Missing order snapshot';
 SELECT * INTO session_row FROM public.create_customer_order_payment_session(customer_id,
   payload||jsonb_build_object('delivery_fee_payer','sender','cod_collection_amount',0,'goods_value',50000),gen_random_uuid()::text);

 changed:=(baseline->'values')||'{"base_fee":30000,"max_cod":200000,"topup_min":100000,"topup_max":500000,
   "offer_seconds":60,"assignment_minutes":20,"auto_radius_m":2500,"free_pick_radius_m":5000,"return_fee_rate_bps":7500}'::jsonb;
 PERFORM set_config('request.jwt.claim.sub',admin_id::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
 saved:=public.update_business_settings(changed,(baseline->>'revision')::bigint,'Synthetic settings update');
 next_rev:=(saved->>'revision')::bigint;
 ASSERT next_rev=(baseline->>'revision')::bigint+1, 'Missing revision increment';
 PERFORM set_config('request.jwt.claim.sub',driver_id::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',driver_id,'role','authenticated')::text,true);
 BEGIN
   PERFORM public.create_driver_wallet_topup(50000,gen_random_uuid()::text);
   RAISE EXCEPTION 'Ignored configured topup minimum';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='TOPUP_AMOUNT_INVALID'; END;
 BEGIN
   PERFORM public.create_driver_wallet_topup(500001,gen_random_uuid()::text);
   RAISE EXCEPTION 'Ignored configured topup maximum';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='TOPUP_AMOUNT_INVALID'; END;
 SELECT * INTO topup_row FROM public.create_driver_wallet_topup(100000,gen_random_uuid()::text);
 ASSERT topup_row.amount=100000 AND topup_row.status='pending','Configured topup rejected';
 PERFORM set_config('request.jwt.claim.sub',admin_id::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
 ASSERT (SELECT business_policy FROM public.orders WHERE id=old_order.id)=old_order.business_policy, 'Changed existing snapshot';
 ASSERT (SELECT value->'previous_values' FROM public.system_settings WHERE key='business_settings_revision:'||next_rev)=baseline->'values', 'Missing before audit';
 BEGIN
   DELETE FROM public.system_settings WHERE key='business_settings_revision:'||next_rev;
   RAISE EXCEPTION 'Deleted immutable audit';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
   PERFORM public.update_business_settings(changed,(baseline->>'revision')::bigint,'Stale admin update');
   RAISE EXCEPTION 'Overwrote a newer revision';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
 BEGIN
   PERFORM public.update_business_settings(changed||'{"auto_radius_m":6000}',next_rev,'Invalid relation');
   RAISE EXCEPTION 'Accepted overlapping dispatch bands';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
   PERFORM public.update_business_settings(changed||'{"rounding_unit":0}',next_rev,'Invalid rounding');
   RAISE EXCEPTION 'Accepted zero rounding unit';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
   PERFORM public.update_business_settings(changed||'{"unknown":1}',next_rev,'Unknown field');
   RAISE EXCEPTION 'Accepted unknown field';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
   PERFORM private.create_customer_order_from_payload(customer_id,payload,'not_required',NULL);
   RAISE EXCEPTION 'Accepted stale quote';
 EXCEPTION WHEN invalid_parameter_value THEN ASSERT SQLERRM='SETTINGS_QUOTE_EXPIRED'; END;
 payload:=payload||jsonb_build_object('settings_revision',next_rev,'delivery_fee',35000);
 SELECT * INTO cash_order FROM private.create_customer_order_from_payload(customer_id,payload,'not_required',NULL);
 ASSERT cash_order.delivery_fee=35000 AND cash_order.business_policy=private.order_fee_policy(customer_id,saved), 'New price/snapshot ignored';
 ASSERT cash_order.assignment_expires_at>clock_timestamp()+interval '19 minutes', 'New assignment timeout ignored';
 ASSERT private.business_number(cash_order.business_policy,'return_fee_rate_bps')=7500, 'New return rate ignored';
 BEGIN
   PERFORM private.create_customer_order_from_payload(customer_id,payload||'{"cod_collection_amount":200001}','not_required',NULL);
   RAISE EXCEPTION 'Accepted excessive COD';
 EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='ORDER_PRICE_INVALID'; END;
 BEGIN
   PERFORM private.create_customer_order_from_payload(customer_id,payload||'{"delivery_fee":1}','not_required',NULL);
   RAISE EXCEPTION 'Accepted tampered price';
 EXCEPTION WHEN invalid_parameter_value THEN ASSERT SQLERRM='SETTINGS_QUOTE_MISMATCH'; END;
 BEGIN
   UPDATE public.orders SET business_policy=saved WHERE id=old_order.id;
   RAISE EXCEPTION 'Changed immutable snapshot';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;

 -- VNPAY issued before a change finishes with the already approved price and limits.
 SELECT * INTO completion FROM public.complete_customer_order_payment(session_row.txn_ref,'synthetic-payment',true,'00');
 SELECT * INTO paid_order FROM public.orders WHERE id=completion.order_id;
 ASSERT paid_order.delivery_fee=23000 AND paid_order.business_policy=private.order_fee_policy(customer_id,baseline), 'Repriced pending payment';
 ASSERT paid_order.assignment_expires_at<clock_timestamp()+interval '16 minutes', 'Changed pending payment timeout';
 ASSERT paid_order.driver_advance_amount=50000, 'Changed goods deposit';
 -- Pre-rollout pending invoices retain the previous server COD ceiling (10m).
 SELECT * INTO paid_order FROM private.create_customer_order_with_policy(customer_id,
   (payload-ARRAY['quoted_distance_m','settings_revision'])||'{"delivery_fee_payer":"sender","cod_collection_amount":3000000}',
   'paid',clock_timestamp(),private.legacy_business_settings());
 ASSERT paid_order.cod_collection_amount=3000000, 'Retroactively rejected a legacy COD invoice';
 -- Restoring creates a new immutable revision, never rewrites the original.
 saved:=public.update_business_settings(baseline->'values',next_rev,'Restore previous values');
 ASSERT (saved->>'revision')::bigint=next_rev+1, 'Restore rewrote audit history';
 PERFORM set_config('request.jwt.claim.sub',support_id::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',support_id,'role','authenticated')::text,true);
 ASSERT jsonb_array_length(public.get_business_settings_history(NULL,20))>=3, 'Staff cannot read history';
 BEGIN
   PERFORM public.update_business_settings(changed,next_rev+1,'Support write attempt');
   RAISE EXCEPTION 'Support changed settings';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub',customer_id::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',customer_id,'role','authenticated')::text,true);
 SET LOCAL ROLE authenticated;
 ASSERT (SELECT count(*) FROM public.system_settings WHERE starts_with(key,'business_settings_revision:'))=0,
   'Customer can bypass RPC and read audit history';
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub','',true);
 PERFORM set_config('request.jwt.claims','{"role":"anon"}',true);
 ASSERT public.get_business_contact() ? 'support_email', 'Missing pre-login contact';
 BEGIN
   PERFORM public.get_business_settings();
   RAISE EXCEPTION 'Anonymous read operational policy';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;
$test$;
SELECT 'business_settings_regression_passed' AS result;
ROLLBACK;
