-- Read-only readiness checks. Run as database owner in SQL Editor.
SELECT required_table, to_regclass('public.'||required_table) IS NOT NULL AS ready
FROM unnest(ARRAY['users','drivers','orders','order_payment_sessions',
 'driver_wallet_transactions','customer_wallet_transactions','system_settings',
 'order_returns','risk_reports','order_delivery_proofs']) AS required_table;

SELECT required_function, to_regprocedure(required_function) IS NOT NULL AS ready
FROM unnest(ARRAY[
 'private.current_business_settings()',
 'private.create_customer_order_with_policy(uuid,jsonb,text,timestamp with time zone,jsonb)',
 'public.update_business_settings(jsonb,bigint,text)',
 'public.complete_customer_order_payment(text,text,boolean,text)',
 'public.confirm_driver_pickup_code(uuid,text)',
 'public.advance_driver_order_status(uuid)']) AS required_function;

SELECT table_name,column_name,data_type,is_nullable
FROM information_schema.columns WHERE table_schema='public' AND (
 (table_name='users' AND column_name IN ('customer_type','business_name','business_address','business_tax_code')) OR
 (table_name='orders' AND column_name IN ('customer_platform_fee_rate_bps','customer_platform_fee_amount')) OR
 (table_name='customer_wallet_transactions' AND column_name IN ('order_id','payment_session_id')))
ORDER BY table_name,column_name;

SELECT value->>'revision' AS revision,value->>'platform_fee_version' AS collection_version,
 value->'values'->'customer_individual_fee_bps' AS individual_bps,
 value->'values'->'customer_business_fee_bps' AS business_bps,
 value->'values'->'driver_platform_fee_bps' AS driver_bps
FROM public.system_settings WHERE key='business_settings';
