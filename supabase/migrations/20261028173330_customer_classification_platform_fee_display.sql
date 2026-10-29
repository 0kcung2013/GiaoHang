-- Reuse users for the customer profile and system_settings for rates/history.
-- Rates are informational in this phase; no wallet/payment/order totals change.
ALTER TABLE public.users
 ADD COLUMN customer_type text,
 ADD COLUMN business_name text,
 ADD COLUMN business_tax_code text,
 ADD COLUMN business_address text,
 ADD CONSTRAINT users_customer_classification_check CHECK (
   (customer_type IS NULL AND business_name IS NULL AND business_tax_code IS NULL AND business_address IS NULL)
   OR (role='customer' AND customer_type IS NOT NULL AND (
     (customer_type='individual' AND business_name IS NULL AND business_tax_code IS NULL AND business_address IS NULL)
     OR (customer_type='business'
       AND business_name IS NOT NULL AND char_length(btrim(business_name)) BETWEEN 2 AND 160
       AND business_address IS NOT NULL AND char_length(btrim(business_address)) BETWEEN 5 AND 500
       AND (business_tax_code IS NULL OR business_tax_code ~ '^[0-9-]{10,20}$'))))
 );
COMMENT ON COLUMN public.users.customer_type IS 'Self-declared individual/business profile; does not grant verification or financial privileges.';
-- Existing own-row RLS and account-enabled write policy remain in force.
GRANT UPDATE(customer_type,business_name,business_tax_code,business_address) ON public.users TO authenticated;

CREATE OR REPLACE FUNCTION private.platform_fee_business_defaults() RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT private.single_rate_business_defaults() ||
 '{"customer_individual_fee_bps":0,"customer_business_fee_bps":0,"driver_platform_fee_bps":0}'::jsonb;
$fn$;
REVOKE ALL ON FUNCTION private.platform_fee_business_defaults() FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION private.validate_business_settings(p_values jsonb) RETURNS void
LANGUAGE plpgsql SET search_path='' AS $fn$
DECLARE r record; v numeric;
BEGIN
 IF jsonb_typeof(p_values) IS DISTINCT FROM 'object'
   OR (SELECT count(*) FROM jsonb_object_keys(p_values))<>20
   OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_values) k WHERE NOT private.platform_fee_business_defaults() ? k)
 THEN RAISE EXCEPTION 'SETTINGS_FIELDS_INVALID' USING ERRCODE='22023'; END IF;
 FOR r IN SELECT * FROM (VALUES
   ('customer_individual_fee_bps',0,10000),('customer_business_fee_bps',0,10000),
   ('driver_platform_fee_bps',0,10000),('base_fee',5000,1000000),('included_distance_m',0,100000),
   ('standard_per_km',0,100000),('rounding_unit',1,10000),
   ('return_fee_rate_bps',0,10000),('max_cod',0,10000000),
   ('max_goods_value',1,100000000),('max_paid_goods_value',1,2000000),
   ('topup_min',5000,10000000),('topup_max',5000,10000000),
   ('offer_seconds',15,300),('assignment_minutes',1,60),
   ('auto_radius_m',100,10000),('free_pick_radius_m',101,20000)
 ) AS rules(key,minimum,maximum) LOOP
   IF jsonb_typeof(p_values->r.key) IS DISTINCT FROM 'number' THEN
     RAISE EXCEPTION 'SETTINGS_VALUE_INVALID:%',r.key USING ERRCODE='22023'; END IF;
   v:=(p_values->>r.key)::numeric;
   IF v<>trunc(v) OR v<r.minimum OR v>r.maximum THEN
     RAISE EXCEPTION 'SETTINGS_VALUE_INVALID:%',r.key USING ERRCODE='22023'; END IF;
 END LOOP;
 IF (p_values->>'auto_radius_m')::numeric >= (p_values->>'free_pick_radius_m')::numeric
   OR (p_values->>'topup_min')::numeric > (p_values->>'topup_max')::numeric
   OR (p_values->>'max_paid_goods_value')::numeric > (p_values->>'max_goods_value')::numeric
   OR (p_values->>'offer_seconds')::numeric > (p_values->>'assignment_minutes')::numeric*60
 THEN RAISE EXCEPTION 'SETTINGS_RELATION_INVALID' USING ERRCODE='22023'; END IF;
 IF jsonb_typeof(p_values->'company_name') IS DISTINCT FROM 'string'
   OR char_length(btrim(p_values->>'company_name')) NOT BETWEEN 1 AND 80
   OR jsonb_typeof(p_values->'support_email') IS DISTINCT FROM 'string'
   OR char_length(p_values->>'support_email')>254
   OR (p_values->>'support_email') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
   OR jsonb_typeof(p_values->'support_phone') IS DISTINCT FROM 'string'
   OR (p_values->>'support_phone') !~ '^[+0-9() .-]{0,25}$'
 THEN RAISE EXCEPTION 'SETTINGS_CONTACT_INVALID' USING ERRCODE='22023'; END IF;
END;
$fn$;

DO $migration$
DECLARE previous jsonb; next_value jsonb; next_revision bigint; applied_at timestamptz:=clock_timestamp();
BEGIN
 SELECT value INTO STRICT previous FROM public.system_settings WHERE key='business_settings' FOR UPDATE;
 next_revision:=(previous->>'revision')::bigint+1;
 next_value:=jsonb_build_object('revision',next_revision,'values',
   private.platform_fee_business_defaults() || (previous->'values'));
 PERFORM private.validate_business_settings(next_value->'values');
 INSERT INTO public.system_settings(key,value,updated_by,updated_at) VALUES(
   'business_settings_revision:'||next_revision::text,
   next_value||jsonb_build_object('previous_values',previous->'values','reason',
     'Bổ sung tỷ lệ phí sàn cá nhân, doanh nghiệp và tài xế; chỉ hiển thị, chưa thu phí.'),
   NULL,applied_at);
 UPDATE public.system_settings SET value=next_value,updated_by=NULL,updated_at=applied_at
 WHERE key='business_settings';
END;
$migration$;
