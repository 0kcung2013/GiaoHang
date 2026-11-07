-- Synthetic fixtures only. All orders, invoices, settings and audit rows roll back.
BEGIN;
UPDATE public.system_settings SET value=value||jsonb_build_object('values',
 private.cargo_business_defaults()||'{"cargo_pricing_enabled":1}'::jsonb)
WHERE key='business_settings';
DO $test$
DECLARE
 customer_id uuid:=gen_random_uuid(); admin_id uuid:=gen_random_uuid();
 policy jsonb:=private.current_business_settings(); payload jsonb; bad jsonb;
 session_row record; completed record; created record;
 ord public.orders%ROWTYPE; paid public.orders%ROWTYPE; old_ord public.orders%ROWTYPE;
 wallet_order public.orders%ROWTYPE; wallet_retry public.orders%ROWTYPE;
 wallet_request uuid:=gen_random_uuid();
 old_policy jsonb; next_policy jsonb; size text; kg numeric; expected bigint; result jsonb;
BEGIN
 ASSERT (SELECT count(*) FROM jsonb_object_keys(policy->'values'))=35;
 PERFORM private.validate_business_settings(policy->'values');
 FOREACH size IN ARRAY ARRAY['standard','large','extra_large'] LOOP
   FOREACH kg IN ARRAY ARRAY[5,5.001,10,10.001,20]::numeric[] LOOP
     result:=private.calculate_business_cargo(jsonb_build_object('item_weight_kg',kg,
       'cargo_details',jsonb_build_object('size_group',size,'package_count',3)),policy);
     expected:=CASE WHEN kg>10 OR size='extra_large' THEN 30000
       WHEN kg>5 OR size='large' THEN 15000 ELSE 0 END;
     ASSERT (result->>'surcharge')::bigint=expected, 'Tier double charged or threshold wrong';
     ASSERT (result->>'package_count')::int=3;
   END LOOP;
 END LOOP;
 payload:='{"item_weight_kg":6,"cargo_details":{"size_group":"standard","package_count":1},"quoted_distance_m":3100}';
 next_policy:=jsonb_set(policy,'{values,cargo_large_fee}','15500');
 ASSERT private.calculate_business_cargo_order_fee(payload,next_policy)=39000, 'Rounding order drift';
 FOREACH bad IN ARRAY ARRAY[
   '{}'::jsonb,
   '{"item_weight_kg":1,"cargo_details":{"size_group":"oversized","package_count":1}}',
   '{"item_weight_kg":20.001,"cargo_details":{"size_group":"standard","package_count":1}}',
   '{"item_weight_kg":0,"cargo_details":{"size_group":"standard","package_count":1}}',
   '{"item_weight_kg":0.0001,"cargo_details":{"size_group":"standard","package_count":1}}',
   '{"item_weight_kg":1,"cargo_details":{"size_group":"standard","package_count":0}}',
   '{"item_weight_kg":1,"cargo_details":{"size_group":"standard","package_count":101}}',
   '{"item_weight_kg":1,"cargo_details":{"size_group":"standard","package_count":1.5}}'
 ] LOOP
   BEGIN
     PERFORM private.calculate_business_cargo(bad,policy);
     RAISE EXCEPTION 'Accepted invalid cargo';
   EXCEPTION WHEN invalid_parameter_value THEN ASSERT SQLERRM LIKE 'CARGO_%'; END;
 END LOOP;
 BEGIN
   PERFORM private.validate_business_settings((policy->'values')||'{"cargo_large_weight_g":5000.0}');
   RAISE EXCEPTION 'Allowed equal weight boundaries';
 EXCEPTION WHEN invalid_parameter_value THEN ASSERT SQLERRM='SETTINGS_CARGO_RELATION_INVALID'; END;
 BEGIN
   PERFORM private.validate_business_settings((policy->'values')||'{"cargo_large_fee":40000}');
   RAISE EXCEPTION 'Allowed decreasing fees';
 EXCEPTION WHEN invalid_parameter_value THEN ASSERT SQLERRM='SETTINGS_CARGO_RELATION_INVALID'; END;

 INSERT INTO public.users(id,email,full_name,role) VALUES
 (customer_id,customer_id||'@cargo-test.invalid','Cargo synthetic customer','customer'),
 (admin_id,admin_id||'@cargo-test.invalid','Cargo synthetic admin','admin');
 PERFORM set_config('request.jwt.claim.sub',customer_id::text,true);
 payload:=jsonb_build_object(
   'pickup_address','Synthetic pickup','pickup_lat',80,'pickup_lng',160,
   'delivery_address','Synthetic drop','delivery_lat',80.01,'delivery_lng',160.01,
   'delivery_fee',63000,'quoted_distance_m',5000,'settings_revision',(policy->>'revision')::bigint,
   'delivery_fee_payer','recipient','goods_value',50000,'cod_collection_amount',100000,
   'item_weight_kg',12,'service_type','standard',
   'cargo_details','{"size_group":"large","package_count":2,"tier":"standard","surcharge":0}'::jsonb);
 SELECT * INTO created FROM public.create_customer_order_v2(payload);
 SELECT * INTO ord FROM public.orders WHERE id=created.order_id;
 ASSERT ord.cargo_details->>'tier'='extra_large' AND (ord.cargo_details->>'surcharge')::bigint=30000,
   'Trusted forged cargo fee';
 ASSERT ord.delivery_fee=63000 AND ord.receiver_collection_amount=163000, 'COD finance drift';
 ASSERT ord.service_type='standard', 'Cargo changed fragile category';
 BEGIN
   UPDATE public.orders SET item_weight_kg=1 WHERE id=ord.id;
   RAISE EXCEPTION 'Mutable declared weight after charging';
 EXCEPTION WHEN insufficient_privilege THEN ASSERT SQLERRM='CARGO_SNAPSHOT_IMMUTABLE'; END;
 BEGIN
   UPDATE public.orders SET cargo_details=NULL WHERE id=ord.id;
   RAISE EXCEPTION 'Mutable cargo snapshot';
 EXCEPTION WHEN insufficient_privilege THEN ASSERT SQLERRM='CARGO_SNAPSHOT_IMMUTABLE'; END;
 BEGIN
   PERFORM public.create_customer_order_v2(payload||'{"delivery_fee":33000}');
   RAISE EXCEPTION 'Accepted cargo fee bypass';
 EXCEPTION WHEN invalid_parameter_value THEN ASSERT SQLERRM='SETTINGS_QUOTE_MISMATCH'; END;
 BEGIN
   PERFORM public.create_customer_order_payment_session(customer_id,
     payload||'{"delivery_fee_payer":"sender","delivery_fee":33000}',gen_random_uuid()::text);
   RAISE EXCEPTION 'Undercharged payment session';
 EXCEPTION WHEN invalid_parameter_value THEN ASSERT SQLERRM='SETTINGS_QUOTE_MISMATCH'; END;
 BEGIN
   PERFORM public.create_customer_order_payment_session(customer_id,
     (payload-'cargo_details')||'{"delivery_fee_payer":"sender"}',gen_random_uuid()::text);
   RAISE EXCEPTION 'Charged missing cargo declaration';
 EXCEPTION WHEN invalid_parameter_value THEN ASSERT SQLERRM='CARGO_DECLARATION_REQUIRED'; END;
 BEGIN
   PERFORM public.update_business_settings(policy->'values',(policy->>'revision')::bigint,'Customer price edit');
   RAISE EXCEPTION 'Customer edited pricing';
 EXCEPTION WHEN insufficient_privilege THEN ASSERT SQLERRM='ADMIN_ROLE_REQUIRED'; END;
 SELECT * INTO session_row FROM public.create_customer_order_payment_session(customer_id,
   payload||'{"delivery_fee_payer":"sender","cod_collection_amount":0}',gen_random_uuid()::text);
 ASSERT session_row.amount=63000, 'Payment did not include cargo';

 INSERT INTO public.customer_wallet_transactions(customer_id,order_id,transaction_type,
   amount,available_delta,idempotency_key)
 VALUES(customer_id,ord.id,'delivery_credit',200000,200000,'cargo-test:'||customer_id::text);
 SET LOCAL ROLE authenticated;
 SELECT * INTO wallet_order FROM public.create_customer_order_with_wallet(
   payload||'{"delivery_fee_payer":"sender","cod_collection_amount":0}',wallet_request);
 SELECT * INTO wallet_retry FROM public.create_customer_order_with_wallet(
   payload||'{"delivery_fee_payer":"sender","cod_collection_amount":0}',wallet_request);
 RESET ROLE;
 ASSERT wallet_order.id=wallet_retry.id AND wallet_order.payment_method='wallet', 'Wallet retry duplicated cargo order';
 ASSERT (wallet_order.cargo_details->>'surcharge')::bigint=30000 AND wallet_order.delivery_fee=63000;
 ASSERT (SELECT sum(available_delta) FROM public.customer_wallet_transactions w
   WHERE w.customer_id=wallet_order.customer_id)=137000, 'Wallet cargo debit incorrect';

 SELECT * INTO old_ord FROM private.create_customer_order_with_policy(customer_id,
   payload||'{"quoted_customer_fee":3150}', 'not_required',NULL,
   jsonb_set(jsonb_set(policy,'{values,customer_individual_fee_bps}','500'),
     '{values,driver_platform_fee_bps}','1000'));
 ASSERT old_ord.customer_platform_fee_amount=3150 AND old_ord.platform_fee_amount=6300,
   'Platform fees excluded cargo';
 ASSERT old_ord.driver_net_earning=56700 AND old_ord.receiver_collection_amount=166150,
   'Cargo platform settlement drift';

 PERFORM set_config('request.jwt.claim.sub',admin_id::text,true);
 next_policy:=public.update_business_settings(
   (policy->'values')||'{"cargo_extra_large_fee":50000}',(policy->>'revision')::bigint,
   'Synthetic cargo price revision');
 ASSERT (next_policy->'values'->>'cargo_extra_large_fee')::bigint=50000;
 ASSERT EXISTS(SELECT 1 FROM public.system_settings WHERE
   key='business_settings_revision:'||(next_policy->>'revision') AND updated_by=admin_id),
   'Missing Admin audit';
 ASSERT (SELECT cargo_details FROM public.orders WHERE id=ord.id)=ord.cargo_details,
   'Repriced existing order';
 BEGIN
   PERFORM private.create_customer_order_from_payload(customer_id,payload,'not_required',NULL);
   RAISE EXCEPTION 'Allowed stale revision';
 EXCEPTION WHEN invalid_parameter_value THEN ASSERT SQLERRM='SETTINGS_QUOTE_EXPIRED'; END;

 SELECT * INTO completed FROM public.complete_customer_order_payment(session_row.txn_ref,'synthetic-cargo',true,'00');
 SELECT * INTO paid FROM public.orders WHERE id=completed.order_id;
 ASSERT paid.delivery_fee=63000 AND (paid.cargo_details->>'surcharge')::bigint=30000, 'Repriced VNPAY snapshot';
 ASSERT paid.receiver_collection_amount=0 AND paid.driver_advance_amount=50000, 'Paid cargo finance drift';
 SELECT * INTO completed FROM public.complete_customer_order_payment(session_row.txn_ref,'synthetic-cargo',true,'00');
 ASSERT completed.order_id=paid.id AND completed.activated=false, 'Duplicated paid cargo order';

 old_policy:=jsonb_build_object('revision',0,'values',private.business_settings_defaults());
 SELECT * INTO old_ord FROM private.create_customer_order_with_policy(customer_id,
   (payload-'cargo_details')||'{"settings_revision":0,"delivery_fee":33000}',
   'not_required',NULL,old_policy);
 ASSERT old_ord.cargo_details IS NULL AND old_ord.delivery_fee=33000, 'Legacy policy was changed';
 ASSERT NOT has_function_privilege('anon','private.calculate_business_cargo(jsonb,jsonb)','EXECUTE');
 ASSERT NOT has_function_privilege('authenticated','private.calculate_business_cargo(jsonb,jsonb)','EXECUTE');
END; $test$;
SELECT 'cargo_pricing_regression_passed' AS result;
ROLLBACK;
