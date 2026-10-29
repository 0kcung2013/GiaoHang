-- New settings have one distance rate. Historical snapshots retain their two
-- legacy distance fields, which identify the old formula without rewriting data.
-- Keep business_settings_defaults()/legacy_business_settings() unchanged: older
-- payment sessions depend on those exact defaults.
CREATE OR REPLACE FUNCTION private.single_rate_business_defaults() RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT private.business_settings_defaults()-ARRAY['long_distance_threshold_m','long_distance_per_km'];
$fn$;
REVOKE ALL ON FUNCTION private.single_rate_business_defaults() FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION private.validate_business_settings(p_values jsonb) RETURNS void
LANGUAGE plpgsql SET search_path='' AS $fn$
DECLARE r record; v numeric;
BEGIN
 IF jsonb_typeof(p_values) IS DISTINCT FROM 'object'
   OR (SELECT count(*) FROM jsonb_object_keys(p_values))<>17
   OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_values) k WHERE NOT private.single_rate_business_defaults() ? k)
 THEN RAISE EXCEPTION 'SETTINGS_FIELDS_INVALID' USING ERRCODE='22023'; END IF;
 FOR r IN SELECT * FROM (VALUES
   ('base_fee',5000,1000000),('included_distance_m',0,100000),
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

CREATE OR REPLACE FUNCTION private.calculate_business_delivery_fee(p_distance_m numeric,p_policy jsonb) RETURNS bigint
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE
 v_values jsonb:=COALESCE(p_policy->'values',private.business_settings_defaults());
 included numeric:=private.business_number(p_policy,'included_distance_m');
 threshold numeric; amount numeric;
 unit numeric:=private.business_number(p_policy,'rounding_unit');
BEGIN
 IF p_distance_m IS NULL OR p_distance_m<0 OR p_distance_m>2000000 THEN
   RAISE EXCEPTION 'QUOTE_DISTANCE_INVALID' USING ERRCODE='22023'; END IF;
 IF v_values ?& ARRAY['long_distance_threshold_m','long_distance_per_km'] THEN
   threshold:=private.business_number(p_policy,'long_distance_threshold_m');
   amount:=private.business_number(p_policy,'base_fee')
     +greatest(0,least(p_distance_m,threshold)-included)/1000*private.business_number(p_policy,'standard_per_km')
     +greatest(0,p_distance_m-threshold)/1000*private.business_number(p_policy,'long_distance_per_km');
 ELSE
   amount:=private.business_number(p_policy,'base_fee')
     +greatest(0,p_distance_m-included)/1000*private.business_number(p_policy,'standard_per_km');
 END IF;
 RETURN (ceil(amount/unit)*unit)::bigint;
END;
$fn$;

CREATE OR REPLACE FUNCTION private.validate_business_order_quote(p_payload jsonb,p_policy jsonb) RETURNS void
LANGUAGE plpgsql SET search_path='' AS $fn$
BEGIN
 IF p_payload ? 'quoted_distance_m' THEN
   IF (p_payload->>'settings_revision')::bigint IS DISTINCT FROM (p_policy->>'revision')::bigint THEN
     RAISE EXCEPTION 'SETTINGS_QUOTE_EXPIRED' USING ERRCODE='22023'; END IF;
   IF (p_payload->>'delivery_fee')::numeric IS DISTINCT FROM
     private.calculate_business_delivery_fee((p_payload->>'quoted_distance_m')::numeric,p_policy) THEN
     RAISE EXCEPTION 'SETTINGS_QUOTE_MISMATCH' USING ERRCODE='22023'; END IF;
 ELSIF NOT (p_policy->'values' ?& ARRAY['long_distance_threshold_m','long_distance_per_km'])
   OR EXISTS(SELECT 1 FROM jsonb_each(private.business_settings_defaults()) d
     WHERE d.key IN ('base_fee','included_distance_m','long_distance_threshold_m','standard_per_km','long_distance_per_km','rounding_unit')
       AND p_policy->'values'->d.key IS DISTINCT FROM d.value) THEN
   RAISE EXCEPTION 'SETTINGS_QUOTE_REQUIRED' USING ERRCODE='22023';
 END IF;
END;
$fn$;

DO $migration$
DECLARE previous jsonb; next_value jsonb; next_revision bigint; applied_at timestamptz:=clock_timestamp();
BEGIN
 SELECT value INTO STRICT previous FROM public.system_settings WHERE key='business_settings' FOR UPDATE;
 IF previous->'values' ?| ARRAY['long_distance_threshold_m','long_distance_per_km'] THEN
   next_revision:=(previous->>'revision')::bigint+1;
   next_value:=jsonb_build_object('revision',next_revision,'values',
     (previous->'values')-ARRAY['long_distance_threshold_m','long_distance_per_km']);
   PERFORM private.validate_business_settings(next_value->'values');
   INSERT INTO public.system_settings(key,value,updated_by,updated_at) VALUES(
     'business_settings_revision:'||next_revision::text,
     next_value||jsonb_build_object('previous_values',previous->'values','reason',
       'Đơn giản hóa giá cước đã được duyệt: phí cơ bản + một giá/km vượt gói. Chỉ áp dụng cho đơn mới; giữ chính sách trên đơn và phiên thanh toán đã chốt.'),
     NULL,applied_at);
   UPDATE public.system_settings SET value=next_value,updated_by=NULL,updated_at=applied_at
   WHERE key='business_settings';
 END IF;
END;
$migration$;
