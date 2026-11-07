-- Approved cargo pricing. No new table, RLS, media or GPS pipeline changes.
-- Legacy business defaults are deliberately untouched for pending invoices.
ALTER TABLE public.orders ADD COLUMN cargo_details jsonb;
COMMENT ON COLUMN public.orders.cargo_details IS
 'Declared package count/size and server-owned tier/surcharge. NULL for legacy or disabled policies.';

CREATE FUNCTION private.cargo_business_defaults() RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT private.platform_fee_business_defaults() || '{
 "cargo_pricing_enabled":0,
 "cargo_standard_weight_g":5000,"cargo_standard_length_cm":30,"cargo_standard_width_cm":25,"cargo_standard_height_cm":20,
 "cargo_large_weight_g":10000,"cargo_large_length_cm":40,"cargo_large_width_cm":35,"cargo_large_height_cm":30,
 "cargo_extra_large_weight_g":20000,"cargo_extra_large_length_cm":50,"cargo_extra_large_width_cm":40,"cargo_extra_large_height_cm":40,
 "cargo_large_fee":15000,"cargo_extra_large_fee":30000}'::jsonb;
$fn$;
REVOKE ALL ON FUNCTION private.cargo_business_defaults() FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION private.validate_business_settings(p_values jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE r record; v numeric;
BEGIN
 IF jsonb_typeof(p_values) IS DISTINCT FROM 'object'
   OR (SELECT count(*) FROM jsonb_object_keys(p_values))<>35
   OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_values) k WHERE NOT private.cargo_business_defaults() ? k)
 THEN RAISE EXCEPTION 'SETTINGS_FIELDS_INVALID' USING ERRCODE='22023'; END IF;
 FOR r IN SELECT * FROM (VALUES
   ('cargo_pricing_enabled',0,1),
   ('cargo_standard_weight_g',1,100000),('cargo_large_weight_g',1,100000),('cargo_extra_large_weight_g',1,100000),
   ('cargo_standard_length_cm',1,200),('cargo_standard_width_cm',1,200),('cargo_standard_height_cm',1,200),
   ('cargo_large_length_cm',1,200),('cargo_large_width_cm',1,200),('cargo_large_height_cm',1,200),
   ('cargo_extra_large_length_cm',1,200),('cargo_extra_large_width_cm',1,200),('cargo_extra_large_height_cm',1,200),
   ('cargo_large_fee',0,1000000),('cargo_extra_large_fee',0,1000000),
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
 FOR r IN SELECT * FROM (VALUES ('weight_g'),('length_cm'),('width_cm'),('height_cm')) AS x(suffix) LOOP
   IF (p_values->>('cargo_standard_'||r.suffix))::numeric >
      (p_values->>('cargo_large_'||r.suffix))::numeric
      OR (p_values->>('cargo_large_'||r.suffix))::numeric >
      (p_values->>('cargo_extra_large_'||r.suffix))::numeric
      OR (r.suffix='weight_g' AND (
        (p_values->>'cargo_standard_weight_g')::numeric=(p_values->>'cargo_large_weight_g')::numeric
        OR (p_values->>'cargo_large_weight_g')::numeric=(p_values->>'cargo_extra_large_weight_g')::numeric))
   THEN RAISE EXCEPTION 'SETTINGS_CARGO_RELATION_INVALID' USING ERRCODE='22023'; END IF;
 END LOOP;
 FOR r IN SELECT * FROM (VALUES ('standard'),('large'),('extra_large')) AS x(tier) LOOP
   IF (p_values->>('cargo_'||r.tier||'_length_cm'))::numeric <
      (p_values->>('cargo_'||r.tier||'_width_cm'))::numeric
      OR (p_values->>('cargo_'||r.tier||'_width_cm'))::numeric <
      (p_values->>('cargo_'||r.tier||'_height_cm'))::numeric
   THEN RAISE EXCEPTION 'SETTINGS_CARGO_RELATION_INVALID' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF (p_values->>'cargo_large_fee')::numeric > (p_values->>'cargo_extra_large_fee')::numeric
 THEN RAISE EXCEPTION 'SETTINGS_CARGO_RELATION_INVALID' USING ERRCODE='22023'; END IF;
END;
$function$;

-- Returns a canonical result; client-supplied tier/fee are never trusted.
CREATE FUNCTION private.calculate_business_cargo(p_payload jsonb,p_policy jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE cargo jsonb:=p_payload->'cargo_details'; weight numeric; packages numeric;
 size_index integer; weight_index integer; tier_index integer; tier text; fee bigint;
BEGIN
 IF COALESCE(p_policy->'values'->>'cargo_pricing_enabled','0')<>'1' THEN RETURN NULL; END IF;
 IF jsonb_typeof(cargo) IS DISTINCT FROM 'object'
    OR jsonb_typeof(cargo->'size_group') IS DISTINCT FROM 'string'
    OR jsonb_typeof(cargo->'package_count') IS DISTINCT FROM 'number'
    OR jsonb_typeof(p_payload->'item_weight_kg') IS DISTINCT FROM 'number'
 THEN RAISE EXCEPTION 'CARGO_DECLARATION_REQUIRED' USING ERRCODE='22023'; END IF;
 size_index:=CASE cargo->>'size_group' WHEN 'standard' THEN 0 WHEN 'large' THEN 1 WHEN 'extra_large' THEN 2 ELSE NULL END;
 IF size_index IS NULL THEN RAISE EXCEPTION 'CARGO_SIZE_INVALID' USING ERRCODE='22023'; END IF;
 weight:=(p_payload->>'item_weight_kg')::numeric;
 packages:=(cargo->>'package_count')::numeric;
 IF weight<=0 OR weight>100 OR weight<>trunc(weight,3)
   OR packages<1 OR packages>100 OR packages<>trunc(packages)
 THEN RAISE EXCEPTION 'CARGO_DECLARATION_INVALID' USING ERRCODE='22023'; END IF;
 IF weight*1000>(p_policy->'values'->>'cargo_extra_large_weight_g')::numeric
 THEN RAISE EXCEPTION 'CARGO_OVERWEIGHT' USING ERRCODE='22023'; END IF;
 weight_index:=CASE
   WHEN weight*1000<=(p_policy->'values'->>'cargo_standard_weight_g')::numeric THEN 0
   WHEN weight*1000<=(p_policy->'values'->>'cargo_large_weight_g')::numeric THEN 1 ELSE 2 END;
 tier_index:=greatest(size_index,weight_index);
 tier:=(ARRAY['standard','large','extra_large'])[tier_index+1];
 fee:=CASE WHEN tier_index=0 THEN 0 ELSE (p_policy->'values'->>('cargo_'||tier||'_fee'))::bigint END;
 RETURN jsonb_build_object('size_group',cargo->>'size_group','package_count',packages::integer,'tier',tier,'surcharge',fee);
END; $fn$;
REVOKE ALL ON FUNCTION private.calculate_business_cargo(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION private.calculate_business_cargo_order_fee(p_payload jsonb,p_policy jsonb) RETURNS bigint
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE cargo jsonb:=private.calculate_business_cargo(p_payload,p_policy);
 unit numeric:=private.business_number(p_policy,'rounding_unit'); distance_fee bigint;
BEGIN
 IF cargo IS NULL THEN
   RETURN private.calculate_business_delivery_fee((p_payload->>'quoted_distance_m')::numeric,p_policy);
 END IF;
 -- Integer đồng precision before the final configured rounding. With integer
 -- surcharge and rounding unit this is equivalent to rounding the raw sum once.
 distance_fee:=private.calculate_business_delivery_fee((p_payload->>'quoted_distance_m')::numeric,
   jsonb_set(p_policy,'{values,rounding_unit}','1'::jsonb));
 RETURN (ceil((distance_fee+(cargo->>'surcharge')::bigint)/unit)*unit)::bigint;
END; $fn$;
REVOKE ALL ON FUNCTION private.calculate_business_cargo_order_fee(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION private.validate_business_order_quote(p_payload jsonb, p_policy jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
 IF p_payload ? 'quoted_distance_m' THEN
   IF (p_payload->>'settings_revision')::bigint IS DISTINCT FROM (p_policy->>'revision')::bigint THEN
     RAISE EXCEPTION 'SETTINGS_QUOTE_EXPIRED' USING ERRCODE='22023'; END IF;
   IF (p_payload->>'delivery_fee')::numeric IS DISTINCT FROM
     private.calculate_business_cargo_order_fee(p_payload,p_policy) THEN
     RAISE EXCEPTION 'SETTINGS_QUOTE_MISMATCH' USING ERRCODE='22023'; END IF;
 ELSIF NOT (p_policy->'values' ?& ARRAY['long_distance_threshold_m','long_distance_per_km'])
   OR EXISTS(SELECT 1 FROM jsonb_each(private.business_settings_defaults()) d
     WHERE d.key IN ('base_fee','included_distance_m','long_distance_threshold_m','standard_per_km','long_distance_per_km','rounding_unit')
       AND p_policy->'values'->d.key IS DISTINCT FROM d.value) THEN
   RAISE EXCEPTION 'SETTINGS_QUOTE_REQUIRED' USING ERRCODE='22023';
 END IF;
END;
$function$;

CREATE FUNCTION private.guard_order_cargo_details() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $fn$
BEGIN
 IF TG_OP='INSERT' THEN
   IF current_user IN ('anon','authenticated') AND NEW.cargo_details IS NOT NULL
   THEN RAISE EXCEPTION 'CARGO_COMMAND_REQUIRED' USING ERRCODE='42501'; END IF;
   NEW.cargo_details:=private.calculate_business_cargo(
     jsonb_build_object('cargo_details',NEW.cargo_details,'item_weight_kg',NEW.item_weight_kg),
     COALESCE(NEW.business_policy,private.current_business_settings()));
 ELSE
   IF NEW.cargo_details IS DISTINCT FROM OLD.cargo_details
      OR (OLD.cargo_details IS NOT NULL AND NEW.item_weight_kg IS DISTINCT FROM OLD.item_weight_kg)
   THEN RAISE EXCEPTION 'CARGO_SNAPSHOT_IMMUTABLE' USING ERRCODE='42501'; END IF;
 END IF;
 RETURN NEW;
END; $fn$;
REVOKE ALL ON FUNCTION private.guard_order_cargo_details() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER orders_guard_cargo_details BEFORE INSERT OR UPDATE OF cargo_details,item_weight_kg
 ON public.orders FOR EACH ROW EXECUTE FUNCTION private.guard_order_cargo_details();

CREATE OR REPLACE FUNCTION private.create_customer_order_with_policy(p_customer_id uuid, p_order_payload jsonb, p_payment_status text, p_paid_at timestamp with time zone, p_policy jsonb)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_order public.orders%ROWTYPE;
  v_policy jsonb := private.order_fee_policy(p_customer_id,COALESCE(p_policy,private.current_business_settings()));
  v_traffic_demo_key text := NULLIF(p_order_payload->>'traffic_demo_key', '');
  v_item_weight_kg numeric;
  v_pickup_address text := NULLIF(btrim(p_order_payload->>'pickup_address'), '');
  v_delivery_address text := NULLIF(btrim(p_order_payload->>'delivery_address'), '');
  v_item_name text := NULLIF(btrim(p_order_payload->>'item_name'), '');
  v_service_type text;
  v_fee_payer text;
  v_payment_method text;
  v_payment_mode text;
  v_delivery_fee bigint;
  v_goods_value bigint;
  v_cod_amount bigint;
  v_receiver_amount bigint;
  v_paid_goods_deposit boolean;
  v_estimated_pickup_at timestamptz;
  v_estimated_delivery_at timestamptz;
BEGIN
  IF v_traffic_demo_key IS NOT NULL AND v_traffic_demo_key NOT IN ('peak', 'off_peak') THEN
    RAISE EXCEPTION 'TRAFFIC_DEMO_INVALID';
  END IF;
  IF p_customer_id IS NULL THEN RAISE EXCEPTION 'CUSTOMER_ID_REQUIRED'; END IF;
  IF p_order_payload IS NULL OR jsonb_typeof(p_order_payload) <> 'object' THEN
    RAISE EXCEPTION 'ORDER_PAYLOAD_INVALID';
  END IF;
  IF v_pickup_address IS NULL OR v_delivery_address IS NULL THEN
    RAISE EXCEPTION 'ORDER_ADDRESS_REQUIRED';
  END IF;
  IF p_payment_status NOT IN ('not_required', 'paid') THEN
    RAISE EXCEPTION 'ORDER_PAYMENT_STATUS_INVALID';
  END IF;

  PERFORM private.validate_business_order_quote(p_order_payload,v_policy);
  PERFORM private.validate_platform_fee_quote(p_order_payload,v_policy);
  BEGIN
    v_item_weight_kg := NULLIF(btrim(p_order_payload->>'item_weight_kg'), '')::numeric;
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RAISE EXCEPTION 'ITEM_WEIGHT_INVALID' USING ERRCODE = '23514';
  END;
  IF v_item_weight_kg IS NOT NULL AND NOT (
    v_item_weight_kg > 0 AND v_item_weight_kg < 'Infinity'::numeric
    AND v_item_weight_kg = trunc(v_item_weight_kg, 3)
  ) THEN
    RAISE EXCEPTION 'ITEM_WEIGHT_INVALID' USING ERRCODE = '23514';
  END IF;

  BEGIN
    IF (p_order_payload->>'pickup_lat')::double precision IS NULL
       OR (p_order_payload->>'pickup_lng')::double precision IS NULL
       OR (p_order_payload->>'delivery_lat')::double precision IS NULL
       OR (p_order_payload->>'delivery_lng')::double precision IS NULL THEN
      RAISE EXCEPTION 'ORDER_COORDINATES_REQUIRED';
    END IF;
    v_delivery_fee := round((p_order_payload->>'delivery_fee')::numeric)::bigint;
    v_goods_value := round(COALESCE(
      NULLIF(p_order_payload->>'goods_value', '')::numeric, 0
    ))::bigint;
    v_cod_amount := round(COALESCE(
      NULLIF(p_order_payload->>'cod_collection_amount', '')::numeric, 0
    ))::bigint;
    v_estimated_pickup_at := NULLIF(
      p_order_payload->>'estimated_pickup_at', ''
    )::timestamptz;
    v_estimated_delivery_at := NULLIF(
      p_order_payload->>'estimated_delivery_at', ''
    )::timestamptz;
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RAISE EXCEPTION 'ORDER_PAYLOAD_INVALID';
  END;

  IF v_delivery_fee IS NULL
     OR v_delivery_fee < 0 OR v_delivery_fee > 10000000
     OR v_goods_value < 0 OR v_goods_value > private.business_number(v_policy,'max_goods_value')
     OR v_cod_amount < 0 OR v_cod_amount > private.business_number(v_policy,'max_cod') THEN
    RAISE EXCEPTION 'ORDER_PRICE_INVALID';
  END IF;

  v_fee_payer := lower(COALESCE(
    NULLIF(btrim(p_order_payload->>'delivery_fee_payer'), ''), 'recipient'
  ));
  IF v_fee_payer NOT IN ('sender', 'recipient') THEN
    RAISE EXCEPTION 'DELIVERY_FEE_PAYER_INVALID';
  END IF;
  IF v_fee_payer = 'sender' AND p_payment_status <> 'paid' THEN
    RAISE EXCEPTION 'ORDER_PAYMENT_REQUIRED';
  END IF;
  IF v_fee_payer = 'recipient' AND p_payment_status <> 'not_required' THEN
    RAISE EXCEPTION 'ORDER_PAYMENT_NOT_REQUIRED';
  END IF;

  v_paid_goods_deposit := v_fee_payer = 'sender' AND v_cod_amount = 0
    AND p_order_payload->>'paid_goods_deposit_version' = '1';
  IF v_paid_goods_deposit AND (v_goods_value <= 0 OR v_goods_value > private.business_number(v_policy,'max_paid_goods_value')) THEN
    RAISE EXCEPTION 'PAID_GOODS_VALUE_REQUIRED';
  END IF;

  v_service_type := CASE
    WHEN p_order_payload->>'service_type' = 'bulky' THEN 'fragile'
    WHEN p_order_payload->>'service_type' IN (
      'standard', 'express', 'fragile', 'document'
    ) THEN p_order_payload->>'service_type'
    ELSE 'standard'
  END;
  v_payment_method := CASE WHEN v_fee_payer = 'sender' THEN 'vnpay' ELSE 'cash' END;
  v_payment_mode := CASE WHEN v_fee_payer = 'sender' THEN 'prepaid' ELSE 'cod' END;
  v_receiver_amount := v_cod_amount + CASE
    WHEN v_fee_payer = 'recipient' THEN v_delivery_fee ELSE 0 END;

  INSERT INTO public.orders (
    business_policy, traffic_demo_key, customer_id, status, pickup_address, pickup_lat, pickup_lng,
    delivery_address, delivery_lat, delivery_lng, total_price, note,
    estimated_pickup_at, estimated_delivery_at, recipient_name,
    recipient_phone, delivery_fee, service_type, payment_method, item_name,
    item_category, item_description, item_image_url, item_weight_kg, cargo_details, payment_mode,
    delivery_fee_payer, payment_status, paid_at, goods_value,
    cod_collection_amount, platform_fee_rate_bps, platform_fee_amount,
    driver_net_earning, driver_advance_amount, receiver_collection_amount
  ) VALUES (
    v_policy, v_traffic_demo_key, p_customer_id, 'pending'::public.order_status,
    v_pickup_address,
    (p_order_payload->>'pickup_lat')::double precision,
    (p_order_payload->>'pickup_lng')::double precision,
    v_delivery_address,
    (p_order_payload->>'delivery_lat')::double precision,
    (p_order_payload->>'delivery_lng')::double precision,
    v_delivery_fee + v_cod_amount,
    NULLIF(btrim(p_order_payload->>'note'), ''),
    v_estimated_pickup_at, v_estimated_delivery_at,
    NULLIF(btrim(p_order_payload->>'recipient_name'), ''),
    NULLIF(btrim(p_order_payload->>'recipient_phone'), ''),
    v_delivery_fee, v_service_type, v_payment_method, v_item_name,
    NULLIF(btrim(p_order_payload->>'item_category'), ''),
    NULLIF(btrim(p_order_payload->>'item_description'), ''),
    NULLIF(btrim(p_order_payload->>'item_image_url'), ''),
    v_item_weight_kg, p_order_payload->'cargo_details', v_payment_mode, v_fee_payer, p_payment_status, p_paid_at,
    v_goods_value, v_cod_amount, 0, 0, v_delivery_fee,
    CASE WHEN v_paid_goods_deposit THEN v_goods_value ELSE v_cod_amount END,
    v_receiver_amount
  ) RETURNING * INTO v_order;

  IF v_item_name IS NOT NULL THEN
    INSERT INTO public.order_items (order_id, name, quantity, price)
    VALUES (v_order.id, v_item_name, 1, v_goods_value);
  END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    v_order.id, 'pending'::public.order_status, 'Đã tạo đơn',
    CASE WHEN v_fee_payer = 'sender'
      THEN 'Phí giao hàng đã được thanh toán qua VNPAY. Đơn đang chờ tài xế nhận.'
      ELSE 'Đơn hàng đã được ghi nhận và đang chờ tài xế nhận.' END,
    p_customer_id
  );

  RETURN v_order;
END;
$function$;

-- Assert algorithm/defaults before committing the rollout, without creating orders.
DO $checks$
DECLARE policy jsonb:=jsonb_build_object('revision',1,'values',
 private.cargo_business_defaults()||'{"cargo_pricing_enabled":1}'::jsonb);
 payload jsonb:='{"item_weight_kg":12,"cargo_details":{"size_group":"large","package_count":2},
 "quoted_distance_m":5000}'::jsonb;
BEGIN
 PERFORM private.validate_business_settings(policy->'values');
 ASSERT (private.calculate_business_cargo(payload,policy)->>'surcharge')::bigint=30000;
 ASSERT private.calculate_business_cargo_order_fee(payload,policy)=63000;
 ASSERT private.calculate_business_cargo(payload,policy)->>'tier'='extra_large';
 ASSERT private.calculate_business_cargo(payload, jsonb_build_object('values',private.platform_fee_business_defaults())) IS NULL;
END; $checks$;

DO $rollout$
DECLARE previous jsonb; next_value jsonb; next_revision bigint;
BEGIN
 SELECT value INTO STRICT previous FROM public.system_settings WHERE key='business_settings' FOR UPDATE;
 next_revision:=(previous->>'revision')::bigint+1;
 next_value:=previous||jsonb_build_object('revision',next_revision,'values',
   private.cargo_business_defaults()||(previous->'values')||'{"cargo_pricing_enabled":0}'::jsonb);
 PERFORM private.validate_business_settings(next_value->'values');
 INSERT INTO public.system_settings(key,value,updated_by) VALUES(
   'business_settings_revision:'||next_revision::text,
   next_value||jsonb_build_object('previous_values',previous->'values','reason',
     'Triển khai phụ phí theo cân nặng/kích thước đã được duyệt. Ban đầu tắt thu phí; giữ snapshot đơn và phiên thanh toán cũ.'),NULL);
 UPDATE public.system_settings SET value=next_value,updated_by=NULL,updated_at=clock_timestamp()
 WHERE key='business_settings';
END; $rollout$;
