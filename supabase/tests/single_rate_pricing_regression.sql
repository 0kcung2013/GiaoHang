-- Synthetic orders/sessions only; no committed orders, wallet movements or settings changes.
BEGIN;
UPDATE public.system_settings SET value=value||jsonb_build_object('values',
  (value->'values')||'{"customer_individual_fee_bps":0,"customer_business_fee_bps":0,"driver_platform_fee_bps":0}'::jsonb)
WHERE key='business_settings';
DO $test$
DECLARE
 customer_id uuid:=gen_random_uuid();
 current_policy jsonb:=private.current_business_settings();
 legacy_policy jsonb:=jsonb_build_object('revision',0,'values',private.business_settings_defaults());
 custom_policy jsonb; payload jsonb; old_payload jsonb; session_row record; completed record;
 old_order public.orders%ROWTYPE; new_order public.orders%ROWTYPE; paid_order public.orders%ROWTYPE;
BEGIN
 ASSERT NOT (current_policy->'values' ? 'long_distance_threshold_m'), 'Current pricing still has long-distance tier';
 ASSERT (SELECT count(*) FROM jsonb_object_keys(current_policy->'values'))=20, 'Wrong current settings shape';
 ASSERT private.calculate_business_delivery_fee(12000,current_policy)=68000, 'Single rate price';
 ASSERT private.calculate_business_delivery_fee(20000,current_policy)=108000, 'Single rate long route';
 ASSERT private.calculate_business_delivery_fee(12000,legacy_policy)=66000, 'Repriced legacy snapshot';
 ASSERT private.calculate_business_delivery_fee(20000,legacy_policy)=98000, 'Repriced legacy long route';
 ASSERT private.calculate_business_delivery_fee(0,current_policy)=18000, 'Zero distance base';
 ASSERT private.calculate_business_delivery_fee(2000,current_policy)=18000, 'Included distance';
 ASSERT private.calculate_business_delivery_fee(2150,current_policy)=19000, 'Rounding';
 custom_policy:=jsonb_build_object('revision',99,'values',(current_policy->'values')||
   '{"base_fee":25000,"included_distance_m":1000,"standard_per_km":6000,"rounding_unit":500}');
 ASSERT private.calculate_business_delivery_fee(6100,custom_policy)=56000, 'Custom single rate';
 PERFORM private.validate_business_settings(custom_policy->'values');
 BEGIN
   PERFORM private.validate_business_settings(private.business_settings_defaults());
   RAISE EXCEPTION 'Allowed editing retired price fields';
 EXCEPTION WHEN invalid_parameter_value THEN ASSERT SQLERRM='SETTINGS_FIELDS_INVALID'; END;
 ASSERT EXISTS(SELECT 1 FROM public.system_settings s WHERE starts_with(s.key,'business_settings_revision:')
   AND s.value->'previous_values' ? 'long_distance_threshold_m'
   AND NOT(s.value->'values' ? 'long_distance_threshold_m')), 'Missing migration audit';

 INSERT INTO public.users(id,email,full_name,role)
 VALUES(customer_id,customer_id||'@single-rate.invalid','Single rate customer','customer');
 payload:=jsonb_build_object('pickup_address','Synthetic pickup','pickup_lat',80,'pickup_lng',160,
   'delivery_address','Synthetic drop','delivery_lat',80.01,'delivery_lng',160.01,
   'delivery_fee',68000,'quoted_distance_m',12000,'settings_revision',(current_policy->>'revision')::bigint,
   'delivery_fee_payer','recipient','goods_value',0,'cod_collection_amount',100000);
 old_payload:=payload||'{"delivery_fee":66000,"settings_revision":0}'::jsonb;
 SELECT * INTO old_order FROM private.create_customer_order_with_policy(customer_id,old_payload,'not_required',NULL,legacy_policy);
 SELECT * INTO new_order FROM private.create_customer_order_from_payload(customer_id,payload,'not_required',NULL);
 ASSERT old_order.delivery_fee=66000 AND old_order.business_policy=legacy_policy, 'Legacy order changed';
 ASSERT new_order.delivery_fee=68000 AND new_order.business_policy=private.order_fee_policy(customer_id,current_policy), 'New order used old pricing';
 BEGIN
   PERFORM private.create_customer_order_from_payload(customer_id,payload||'{"delivery_fee":66000}','not_required',NULL);
   RAISE EXCEPTION 'Accepted stale distance-tier fee';
 EXCEPTION WHEN invalid_parameter_value THEN ASSERT SQLERRM='SETTINGS_QUOTE_MISMATCH'; END;
 BEGIN
   PERFORM private.create_customer_order_from_payload(customer_id,payload-ARRAY['quoted_distance_m','settings_revision'],'not_required',NULL);
   RAISE EXCEPTION 'Accepted legacy client with no quote';
 EXCEPTION WHEN invalid_parameter_value THEN ASSERT SQLERRM='SETTINGS_QUOTE_REQUIRED'; END;

 SELECT * INTO session_row FROM public.create_customer_order_payment_session(customer_id,
   payload||'{"delivery_fee_payer":"sender","cod_collection_amount":0,"goods_value":50000}',gen_random_uuid()::text);
 -- Reconstruct an invoice issued before this rollout, including its trusted policy and charged amount.
 UPDATE public.order_payment_sessions SET amount=66000,order_payload=
   order_payload||jsonb_build_object('_business_policy',legacy_policy,'settings_revision',0,'delivery_fee',66000)
 WHERE id=session_row.session_id;
 SELECT * INTO completed FROM public.complete_customer_order_payment(session_row.txn_ref,'synthetic-return',true,'00');
 SELECT * INTO paid_order FROM public.orders WHERE id=completed.order_id;
 ASSERT paid_order.delivery_fee=66000 AND paid_order.business_policy=legacy_policy, 'Changed pending invoice';
 ASSERT paid_order.driver_advance_amount=50000, 'Changed deposit on old invoice';
 SELECT * INTO completed FROM public.complete_customer_order_payment(session_row.txn_ref,'synthetic-return',true,'00');
 ASSERT completed.order_id=paid_order.id AND completed.activated=false, 'Duplicated completed invoice';
END;
$test$;
SELECT 'single_rate_pricing_regression_passed' AS result;
ROLLBACK;
