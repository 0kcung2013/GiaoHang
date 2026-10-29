-- Business settings and immutable revisions reuse system_settings.
-- No new tables, storage services or changes to monitoring penalties.
CREATE FUNCTION private.business_settings_defaults() RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT '{"base_fee":18000,"included_distance_m":2000,"long_distance_threshold_m":10000,
 "standard_per_km":5000,"long_distance_per_km":4000,"rounding_unit":1000,
 "return_fee_rate_bps":5000,"max_cod":2000000,"max_goods_value":100000000,
 "max_paid_goods_value":2000000,"topup_min":5000,"topup_max":10000000,
 "offer_seconds":45,"assignment_minutes":15,"auto_radius_m":2000,"free_pick_radius_m":3000,
 "company_name":"GiaoHang","support_phone":"","support_email":"cskh@gmail.com"}'::jsonb;
$fn$;

INSERT INTO public.system_settings(key,value) VALUES
 ('business_settings',jsonb_build_object('revision',0,'values',private.business_settings_defaults())),
 ('business_settings_revision:0',jsonb_build_object('revision',0,'values',private.business_settings_defaults(),
    'previous_values',NULL,'reason','Khởi tạo cấu hình hiện hành'));

CREATE FUNCTION private.current_business_settings() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT value FROM public.system_settings WHERE key='business_settings';
$fn$;

CREATE INDEX system_settings_business_revision_idx ON public.system_settings
 (((value->>'revision')::bigint) DESC) WHERE starts_with(key,'business_settings_revision:');

CREATE FUNCTION private.guard_business_revision() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $fn$
BEGIN
 IF starts_with(OLD.key,'business_settings_revision:') THEN
   RAISE EXCEPTION 'SETTINGS_HISTORY_IMMUTABLE' USING ERRCODE='42501'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 IF starts_with(NEW.key,'business_settings_revision:') THEN
   RAISE EXCEPTION 'SETTINGS_HISTORY_IMMUTABLE' USING ERRCODE='42501'; END IF;
 RETURN NEW;
END;
$fn$;
REVOKE ALL ON FUNCTION private.guard_business_revision() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER guard_business_revision BEFORE UPDATE OR DELETE ON public.system_settings
FOR EACH ROW EXECUTE FUNCTION private.guard_business_revision();

CREATE FUNCTION private.legacy_business_settings() RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT jsonb_build_object('revision',-1,'values',private.business_settings_defaults()||'{"max_cod":10000000}'::jsonb);
$fn$;

CREATE FUNCTION private.business_number(p_policy jsonb,p_key text) RETURNS numeric
LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT COALESCE((p_policy->'values'->>p_key)::numeric,
   (private.business_settings_defaults()->>p_key)::numeric);
$fn$;

CREATE FUNCTION private.validate_business_settings(p_values jsonb) RETURNS void
LANGUAGE plpgsql SET search_path='' AS $fn$
DECLARE r record; v numeric;
BEGIN
 IF jsonb_typeof(p_values) IS DISTINCT FROM 'object'
   OR (SELECT count(*) FROM jsonb_object_keys(p_values))<>19
   OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_values) k WHERE NOT private.business_settings_defaults() ? k)
 THEN RAISE EXCEPTION 'SETTINGS_FIELDS_INVALID' USING ERRCODE='22023'; END IF;
 FOR r IN SELECT * FROM (VALUES
   ('base_fee',5000,1000000),('included_distance_m',0,100000),
   ('long_distance_threshold_m',100,500000),('standard_per_km',0,100000),
   ('long_distance_per_km',0,100000),('rounding_unit',1,10000),
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
 IF (p_values->>'included_distance_m')::numeric >= (p_values->>'long_distance_threshold_m')::numeric
   OR (p_values->>'auto_radius_m')::numeric >= (p_values->>'free_pick_radius_m')::numeric
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

CREATE FUNCTION public.get_business_settings() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 IF auth.uid() IS NULL AND COALESCE(auth.jwt()->>'role','')<>'service_role' THEN
   RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501'; END IF;
 RETURN private.current_business_settings();
END;
$fn$;

-- Public contact details are available before login or for disabled accounts.
CREATE FUNCTION public.get_business_contact() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT jsonb_build_object('company_name',value->'values'->'company_name',
   'support_phone',value->'values'->'support_phone',
   'support_email',value->'values'->'support_email')
 FROM public.system_settings WHERE key='business_settings';
$fn$;

CREATE FUNCTION public.update_business_settings(p_values jsonb,p_expected_revision bigint,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE old_value jsonb; new_value jsonb; next_revision bigint; actor uuid:=auth.uid();
BEGIN
 IF actor IS NULL OR NOT EXISTS(SELECT 1 FROM public.users WHERE id=actor AND role='admin') THEN
   RAISE EXCEPTION 'ADMIN_ROLE_REQUIRED' USING ERRCODE='42501'; END IF;
 IF char_length(btrim(COALESCE(p_reason,''))) NOT BETWEEN 5 AND 500 THEN
   RAISE EXCEPTION 'SETTINGS_REASON_REQUIRED' USING ERRCODE='22023'; END IF;
 PERFORM private.validate_business_settings(p_values);
 SELECT value INTO STRICT old_value FROM public.system_settings WHERE key='business_settings' FOR UPDATE;
 IF p_expected_revision IS NULL OR p_expected_revision<>(old_value->>'revision')::bigint THEN
   RAISE EXCEPTION 'SETTINGS_CONFLICT' USING ERRCODE='40001'; END IF;
 IF old_value->'values'=p_values THEN RETURN old_value; END IF;
 next_revision:=(old_value->>'revision')::bigint+1;
 new_value:=jsonb_build_object('revision',next_revision,'values',p_values);
 INSERT INTO public.system_settings(key,value,updated_by)
 VALUES('business_settings_revision:'||next_revision::text,
   new_value||jsonb_build_object('previous_values',old_value->'values','reason',btrim(p_reason)),actor);
 UPDATE public.system_settings SET value=new_value,updated_by=actor,updated_at=clock_timestamp()
 WHERE key='business_settings';
 RETURN new_value;
END;
$fn$;

CREATE FUNCTION public.get_business_settings_history(p_before_revision bigint DEFAULT NULL,p_limit integer DEFAULT 20)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.users WHERE id=auth.uid() AND role IN ('admin','support')) THEN
   RAISE EXCEPTION 'STAFF_ROLE_REQUIRED' USING ERRCODE='42501'; END IF;
 RETURN COALESCE((SELECT jsonb_agg(row_data ORDER BY revision DESC) FROM (
   SELECT s.value||jsonb_build_object('updated_by',s.updated_by,'updated_at',s.updated_at,
     'actor_name',u.full_name) AS row_data,(s.value->>'revision')::bigint AS revision
   FROM public.system_settings s LEFT JOIN public.users u ON u.id=s.updated_by
   WHERE starts_with(s.key,'business_settings_revision:')
     AND (p_before_revision IS NULL OR (s.value->>'revision')::bigint<p_before_revision)
   ORDER BY (s.value->>'revision')::bigint DESC LIMIT LEAST(GREATEST(COALESCE(p_limit,20),1),50)
 ) history),'[]'::jsonb);
END;
$fn$;

-- Historical values/reasons are staff-only. Current non-secret values retain authenticated access.
ALTER POLICY system_settings_select_authenticated ON public.system_settings USING (
 (SELECT auth.uid()) IS NOT NULL AND (
   NOT starts_with(key,'business_settings_revision:') OR EXISTS(
     SELECT 1 FROM public.users u WHERE u.id=(SELECT auth.uid()) AND u.role IN ('admin','support'))));

ALTER TABLE public.orders ADD COLUMN business_policy jsonb;
COMMENT ON COLUMN public.orders.business_policy IS
 'Server-owned business settings snapshot at creation. NULL legacy orders retain pre-rollout defaults.';

CREATE FUNCTION private.calculate_business_delivery_fee(p_distance_m numeric,p_policy jsonb) RETURNS bigint
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE included numeric:=private.business_number(p_policy,'included_distance_m');
 threshold numeric:=private.business_number(p_policy,'long_distance_threshold_m'); amount numeric;
 unit numeric:=private.business_number(p_policy,'rounding_unit');
BEGIN
 IF p_distance_m IS NULL OR p_distance_m<0 OR p_distance_m>2000000 THEN
   RAISE EXCEPTION 'QUOTE_DISTANCE_INVALID' USING ERRCODE='22023'; END IF;
 amount:=private.business_number(p_policy,'base_fee')
   +greatest(0,least(p_distance_m,threshold)-included)/1000*private.business_number(p_policy,'standard_per_km')
   +greatest(0,p_distance_m-threshold)/1000*private.business_number(p_policy,'long_distance_per_km');
 RETURN (ceil(amount/unit)*unit)::bigint;
END;
$fn$;

CREATE FUNCTION private.validate_business_order_quote(p_payload jsonb,p_policy jsonb) RETURNS void
LANGUAGE plpgsql SET search_path='' AS $fn$
BEGIN
 IF p_payload ? 'quoted_distance_m' THEN
   IF (p_payload->>'settings_revision')::bigint IS DISTINCT FROM (p_policy->>'revision')::bigint THEN
     RAISE EXCEPTION 'SETTINGS_QUOTE_EXPIRED' USING ERRCODE='22023'; END IF;
   IF (p_payload->>'delivery_fee')::numeric IS DISTINCT FROM
     private.calculate_business_delivery_fee((p_payload->>'quoted_distance_m')::numeric,p_policy) THEN
     RAISE EXCEPTION 'SETTINGS_QUOTE_MISMATCH' USING ERRCODE='22023'; END IF;
 ELSIF EXISTS(SELECT 1 FROM jsonb_each(private.business_settings_defaults()) d
   WHERE d.key IN ('base_fee','included_distance_m','long_distance_threshold_m','standard_per_km','long_distance_per_km','rounding_unit')
     AND p_policy->'values'->d.key IS DISTINCT FROM d.value) THEN
   RAISE EXCEPTION 'SETTINGS_QUOTE_REQUIRED' USING ERRCODE='22023';
 END IF;
END;
$fn$;

CREATE FUNCTION private.guard_order_business_policy() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $fn$
BEGIN
 IF NEW.business_policy IS DISTINCT FROM OLD.business_policy THEN
   RAISE EXCEPTION 'ORDER_BUSINESS_POLICY_IMMUTABLE' USING ERRCODE='42501'; END IF;
 RETURN NEW;
END;
$fn$;
CREATE TRIGGER guard_order_business_policy BEFORE UPDATE OF business_policy ON public.orders
FOR EACH ROW EXECUTE FUNCTION private.guard_order_business_policy();

REVOKE ALL ON FUNCTION private.business_settings_defaults(),private.current_business_settings(),
 private.legacy_business_settings(),private.business_number(jsonb,text),private.validate_business_settings(jsonb),
 private.calculate_business_delivery_fee(numeric,jsonb),private.validate_business_order_quote(jsonb,jsonb),
 private.guard_order_business_policy() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.get_business_settings(),public.get_business_contact(),
 public.update_business_settings(jsonb,bigint,text),public.get_business_settings_history(bigint,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_business_settings() TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_business_contact() TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.update_business_settings(jsonb,bigint,text),public.get_business_settings_history(bigint,integer) TO authenticated;


CREATE OR REPLACE FUNCTION private.create_customer_order_with_policy(p_customer_id uuid, p_order_payload jsonb, p_payment_status text, p_paid_at timestamp with time zone, p_policy jsonb)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_order public.orders%ROWTYPE;
  v_policy jsonb := COALESCE(p_policy,private.current_business_settings());
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
    item_category, item_description, item_image_url, item_weight_kg, payment_mode,
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
    v_item_weight_kg, v_payment_mode, v_fee_payer, p_payment_status, p_paid_at,
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



CREATE OR REPLACE FUNCTION private.create_customer_order_from_payload(p_customer_id uuid,
 p_order_payload jsonb,p_payment_status text,p_paid_at timestamptz DEFAULT NULL) RETURNS public.orders
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $fn$
 SELECT private.create_customer_order_with_policy(p_customer_id,p_order_payload,p_payment_status,
   p_paid_at,private.current_business_settings());
$fn$;
REVOKE ALL ON FUNCTION private.create_customer_order_with_policy(uuid,jsonb,text,timestamptz,jsonb)
 FROM PUBLIC,anon,authenticated,service_role;


CREATE OR REPLACE FUNCTION public.create_customer_order_payment_session(p_customer_id uuid, p_order_payload jsonb, p_txn_ref text)
 RETURNS TABLE(session_id uuid, txn_ref text, amount bigint, status text, expires_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_session public.order_payment_sessions%ROWTYPE;
  v_policy jsonb := private.current_business_settings();
  v_item_weight_kg numeric;
  v_amount bigint;
  v_fee_payer text;
  v_cod_amount bigint;
  v_goods_value bigint;
BEGIN
  IF NULLIF(p_order_payload->>'traffic_demo_key', '') IS NOT NULL
     AND p_order_payload->>'traffic_demo_key' NOT IN ('peak', 'off_peak') THEN
    RAISE EXCEPTION 'TRAFFIC_DEMO_INVALID';
  END IF;
  IF p_customer_id IS NULL THEN RAISE EXCEPTION 'CUSTOMER_ID_REQUIRED'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users app_user
    WHERE app_user.id = p_customer_id
      AND app_user.role = 'customer'::public.user_role
  ) THEN RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED'; END IF;
  IF p_order_payload IS NULL OR jsonb_typeof(p_order_payload) <> 'object' THEN
    RAISE EXCEPTION 'ORDER_PAYLOAD_INVALID';
  END IF;
  IF NULLIF(btrim(p_txn_ref), '') IS NULL THEN
    RAISE EXCEPTION 'PAYMENT_TXN_REF_REQUIRED';
  END IF;

  PERFORM private.validate_business_order_quote(p_order_payload,v_policy);
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
    v_amount := round((p_order_payload->>'delivery_fee')::numeric)::bigint;
    v_cod_amount := round(COALESCE(
      NULLIF(p_order_payload->>'cod_collection_amount', '')::numeric, 0
    ))::bigint;
    v_goods_value := round(COALESCE(
      NULLIF(p_order_payload->>'goods_value', '')::numeric, 0
    ))::bigint;
    PERFORM (p_order_payload->>'pickup_lat')::double precision;
    PERFORM (p_order_payload->>'pickup_lng')::double precision;
    PERFORM (p_order_payload->>'delivery_lat')::double precision;
    PERFORM (p_order_payload->>'delivery_lng')::double precision;
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RAISE EXCEPTION 'ORDER_PAYLOAD_INVALID';
  END;

  v_fee_payer := lower(COALESCE(
    NULLIF(btrim(p_order_payload->>'delivery_fee_payer'), ''), 'recipient'
  ));
  IF v_fee_payer <> 'sender' THEN RAISE EXCEPTION 'VNPAY_PAYMENT_NOT_REQUIRED'; END IF;
  IF NULLIF(btrim(p_order_payload->>'pickup_address'), '') IS NULL
     OR NULLIF(btrim(p_order_payload->>'delivery_address'), '') IS NULL THEN
    RAISE EXCEPTION 'ORDER_ADDRESS_REQUIRED';
  END IF;
  IF NULLIF(btrim(p_order_payload->>'pickup_lat'), '') IS NULL
     OR NULLIF(btrim(p_order_payload->>'pickup_lng'), '') IS NULL
     OR NULLIF(btrim(p_order_payload->>'delivery_lat'), '') IS NULL
     OR NULLIF(btrim(p_order_payload->>'delivery_lng'), '') IS NULL THEN
    RAISE EXCEPTION 'ORDER_COORDINATES_REQUIRED';
  END IF;
  IF v_amount IS NULL
     OR v_amount < 5000 OR v_amount > 10000000
     OR v_cod_amount < 0 OR v_cod_amount > private.business_number(v_policy,'max_cod')
     OR v_goods_value < 0 OR v_goods_value > private.business_number(v_policy,'max_goods_value') THEN
    RAISE EXCEPTION 'ORDER_PRICE_INVALID';
  END IF;

  -- Validate before taking a VNPAY payment, then store the server-owned policy
  -- marker in the existing session payload so older pending sessions still work.
  IF v_cod_amount = 0 AND (v_goods_value <= 0 OR v_goods_value > private.business_number(v_policy,'max_paid_goods_value')) THEN
    RAISE EXCEPTION 'PAID_GOODS_VALUE_REQUIRED';
  END IF;

  INSERT INTO public.order_payment_sessions (
    customer_id, provider_txn_ref, amount, status,
    order_payload, expires_at
  ) VALUES (
    p_customer_id, btrim(p_txn_ref), v_amount, 'pending',
    (p_order_payload - 'paid_goods_deposit_version') || jsonb_build_object(
      '_business_policy',v_policy,
      'delivery_fee_payer', 'sender',
      'paid_goods_deposit_version', CASE WHEN v_cod_amount = 0 THEN 1 ELSE 0 END
    ),
    clock_timestamp() + interval '15 minutes'
  ) RETURNING * INTO v_session;

  RETURN QUERY SELECT v_session.id, v_session.provider_txn_ref,
    v_session.amount, v_session.status, v_session.expires_at;
END;
$function$;


CREATE OR REPLACE FUNCTION public.complete_customer_order_payment(p_txn_ref text, p_vnp_transaction_no text, p_success boolean, p_response_code text)
 RETURNS TABLE(session_id uuid, order_id uuid, tracking_code text, status text, activated boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_session public.order_payment_sessions%ROWTYPE;
  v_order public.orders%ROWTYPE;
BEGIN
  SELECT * INTO v_session
  FROM public.order_payment_sessions session
  WHERE session.provider = 'vnpay'
    AND session.provider_txn_ref = btrim(p_txn_ref)
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PAYMENT_SESSION_NOT_FOUND'; END IF;

  IF v_session.status = 'paid' THEN
    SELECT * INTO v_order FROM public.orders WHERE id = v_session.order_id;
    RETURN QUERY SELECT v_session.id, v_session.order_id,
      v_order.tracking_code, v_session.status, false;
    RETURN;
  END IF;
  IF v_session.status <> 'pending' THEN
    RETURN QUERY SELECT v_session.id, v_session.order_id,
      NULL::text, v_session.status, false;
    RETURN;
  END IF;

  IF p_success IS DISTINCT FROM true THEN
    UPDATE public.order_payment_sessions session
    SET status = 'failed',
      provider_transaction_no = NULLIF(btrim(p_vnp_transaction_no), ''),
      provider_response_code = NULLIF(btrim(p_response_code), ''),
      updated_at = clock_timestamp()
    WHERE session.id = v_session.id
    RETURNING * INTO v_session;
    RETURN QUERY SELECT v_session.id, NULL::uuid, NULL::text,
      v_session.status, false;
    RETURN;
  END IF;

  IF v_session.expires_at <= clock_timestamp() THEN
    UPDATE public.order_payment_sessions session
    SET status = 'refund_required',
      provider_transaction_no = NULLIF(btrim(p_vnp_transaction_no), ''),
      provider_response_code = NULLIF(btrim(p_response_code), ''),
      paid_at = clock_timestamp(), updated_at = clock_timestamp()
    WHERE session.id = v_session.id
    RETURNING * INTO v_session;
    RETURN QUERY SELECT v_session.id, NULL::uuid, NULL::text,
      v_session.status, false;
    RETURN;
  END IF;

  SELECT * INTO v_order
  FROM private.create_customer_order_with_policy(
    v_session.customer_id, v_session.order_payload, 'paid', clock_timestamp(),
    COALESCE(v_session.order_payload->'_business_policy',private.legacy_business_settings())
  );

  UPDATE public.order_payment_sessions session
  SET status = 'paid', order_id = v_order.id,
    provider_transaction_no = NULLIF(btrim(p_vnp_transaction_no), ''),
    provider_response_code = NULLIF(btrim(p_response_code), ''),
    paid_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE session.id = v_session.id
  RETURNING * INTO v_session;

  RETURN QUERY SELECT v_session.id, v_order.id, v_order.tracking_code,
    v_session.status, true;
END;
$function$;


CREATE OR REPLACE FUNCTION public.create_customer_order(p_pickup_address text, p_pickup_lat double precision, p_pickup_lng double precision, p_delivery_address text, p_delivery_lat double precision, p_delivery_lng double precision, p_total_price numeric DEFAULT NULL::numeric, p_note text DEFAULT NULL::text, p_estimated_pickup_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_estimated_delivery_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_recipient_name text DEFAULT NULL::text, p_recipient_phone text DEFAULT NULL::text, p_delivery_fee numeric DEFAULT 0, p_service_type text DEFAULT 'standard'::text, p_payment_method text DEFAULT 'cash'::text, p_item_name text DEFAULT NULL::text, p_item_category text DEFAULT NULL::text, p_item_description text DEFAULT NULL::text, p_item_image_url text DEFAULT NULL::text, p_item_quantity integer DEFAULT 1, p_item_price numeric DEFAULT NULL::numeric, p_payment_mode text DEFAULT 'cod'::text)
 RETURNS TABLE(order_id uuid, tracking_code text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_customer_user_id uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_item_name text := NULLIF(btrim(p_item_name), '');
  v_service_type text;
  v_payment_mode text;
  v_delivery_fee bigint;
  v_unit_price bigint;
  v_goods_value bigint;
  v_platform_fee bigint;
  v_policy jsonb := private.current_business_settings();
BEGIN
  IF v_customer_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.users customer_user
    WHERE customer_user.id = v_customer_user_id
      AND customer_user.role = 'customer'::public.user_role
  ) THEN
    RAISE EXCEPTION 'CUSTOMER_ROLE_REQUIRED';
  END IF;
  IF NULLIF(btrim(p_pickup_address), '') IS NULL
     OR NULLIF(btrim(p_delivery_address), '') IS NULL THEN
    RAISE EXCEPTION 'ORDER_ADDRESS_REQUIRED';
  END IF;
  IF p_pickup_lat IS NULL OR p_pickup_lng IS NULL
     OR p_delivery_lat IS NULL OR p_delivery_lng IS NULL THEN
    RAISE EXCEPTION 'ORDER_COORDINATES_REQUIRED';
  END IF;
  IF COALESCE(p_delivery_fee, 0) < 0
     OR COALESCE(p_item_price, 0) < 0
     OR COALESCE(p_item_quantity, 0) <= 0
     OR COALESCE(p_delivery_fee, 0) <> trunc(COALESCE(p_delivery_fee, 0))
     OR COALESCE(p_item_price, 0) <> trunc(COALESCE(p_item_price, 0)) THEN
    RAISE EXCEPTION 'ORDER_PRICE_INVALID';
  END IF;

  v_payment_mode := lower(COALESCE(NULLIF(btrim(p_payment_mode), ''), 'cod'));
  IF v_payment_mode NOT IN ('prepaid', 'cod') THEN
    RAISE EXCEPTION 'ORDER_PAYMENT_MODE_INVALID';
  END IF;

  v_service_type := CASE
    WHEN p_service_type = 'bulky' THEN 'fragile'
    WHEN p_service_type IN ('standard', 'express', 'fragile', 'document')
      THEN p_service_type
    ELSE 'standard'
  END;
  v_delivery_fee := round(COALESCE(p_delivery_fee, 0))::bigint;
  v_unit_price := round(COALESCE(p_item_price, 0))::bigint;
  v_goods_value := v_unit_price * COALESCE(p_item_quantity, 1);
  v_platform_fee := public.get_platform_fee_amount();
  PERFORM private.validate_business_order_quote(jsonb_build_object('delivery_fee',v_delivery_fee),v_policy);
  IF v_goods_value > private.business_number(v_policy,'max_goods_value')
    OR (v_payment_mode='cod' AND v_goods_value>private.business_number(v_policy,'max_cod')) THEN
    RAISE EXCEPTION 'ORDER_PRICE_INVALID'; END IF;

  INSERT INTO public.orders (
    customer_id, status, pickup_address, pickup_lat, pickup_lng,
    delivery_address, delivery_lat, delivery_lng, total_price, note,
    estimated_pickup_at, estimated_delivery_at, recipient_name,
    recipient_phone, delivery_fee, service_type, payment_method, item_name,
    item_category, item_description, item_image_url, payment_mode,
    goods_value, platform_fee_rate_bps, platform_fee_amount,
    driver_net_earning, driver_advance_amount, receiver_collection_amount
  ) VALUES (
    v_customer_user_id, 'pending'::public.order_status,
    btrim(p_pickup_address), p_pickup_lat, p_pickup_lng,
    btrim(p_delivery_address), p_delivery_lat, p_delivery_lng,
    v_goods_value + v_delivery_fee + v_platform_fee,
    NULLIF(btrim(p_note), ''),
    p_estimated_pickup_at, p_estimated_delivery_at,
    NULLIF(btrim(p_recipient_name), ''),
    NULLIF(btrim(p_recipient_phone), ''), v_delivery_fee, v_service_type,
    COALESCE(NULLIF(btrim(p_payment_method), ''), 'cash'), v_item_name,
    NULLIF(btrim(p_item_category), ''),
    NULLIF(btrim(p_item_description), ''),
    NULLIF(btrim(p_item_image_url), ''), v_payment_mode, v_goods_value,
    0, v_platform_fee, v_delivery_fee,
    CASE WHEN v_payment_mode = 'cod' THEN v_goods_value ELSE 0 END,
    CASE WHEN v_payment_mode = 'cod'
      THEN v_goods_value + v_delivery_fee + v_platform_fee ELSE 0 END
  ) RETURNING * INTO v_order;

  IF v_item_name IS NOT NULL THEN
    INSERT INTO public.order_items (order_id, name, quantity, price)
    VALUES (v_order.id, v_item_name, p_item_quantity, v_unit_price);
  END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    v_order.id, 'pending'::public.order_status, 'Đã tạo đơn',
    'Đơn hàng đã được ghi nhận và đang chờ tài xế nhận.',
    v_customer_user_id
  );

  RETURN QUERY SELECT v_order.id, v_order.tracking_code;
END;
$function$;



CREATE FUNCTION private.set_order_business_policy() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 NEW.business_policy:=COALESCE(NEW.business_policy,private.current_business_settings());
 NEW.assignment_expires_at:=clock_timestamp()+make_interval(
   mins=>private.business_number(NEW.business_policy,'assignment_minutes')::integer);
 RETURN NEW;
END;
$fn$;
REVOKE ALL ON FUNCTION private.set_order_business_policy() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER set_order_business_policy BEFORE INSERT ON public.orders
FOR EACH ROW EXECUTE FUNCTION private.set_order_business_policy();


CREATE OR REPLACE FUNCTION public.create_driver_wallet_topup(p_amount bigint, p_txn_ref text)
 RETURNS TABLE(topup_id uuid, txn_ref text, amount bigint, status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_driver_user_id uuid := auth.uid();
  v_topup public.driver_wallet_transactions%ROWTYPE;
BEGIN
  IF v_driver_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.drivers driver
    WHERE driver.user_id = v_driver_user_id
      AND driver.approval_status = 'approved'::public.approval_status
  ) THEN
    RAISE EXCEPTION 'APPROVED_DRIVER_REQUIRED';
  END IF;
  IF p_amount IS NULL OR p_amount < private.business_number(private.current_business_settings(),'topup_min') OR p_amount > private.business_number(private.current_business_settings(),'topup_max') THEN
    RAISE EXCEPTION 'TOPUP_AMOUNT_INVALID';
  END IF;
  IF NULLIF(btrim(p_txn_ref), '') IS NULL THEN
    RAISE EXCEPTION 'TOPUP_TXN_REF_REQUIRED';
  END IF;

  INSERT INTO public.driver_wallet_transactions (
    driver_id,
    transaction_type,
    status,
    amount,
    provider,
    provider_txn_ref,
    idempotency_key
  )
  VALUES (
    v_driver_user_id,
    'vnpay_topup',
    'pending',
    p_amount,
    'vnpay',
    btrim(p_txn_ref),
    'vnpay:' || btrim(p_txn_ref)
  )
  RETURNING * INTO v_topup;

  RETURN QUERY
  SELECT v_topup.id, v_topup.provider_txn_ref, v_topup.amount, v_topup.status;
END;
$function$;


CREATE OR REPLACE FUNCTION private.road_driver_candidates(p_order_id uuid)
 RETURNS TABLE(user_id uuid, current_lat double precision, current_lng double precision)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT d.user_id, d.current_lat, d.current_lng
  FROM public.orders o CROSS JOIN public.drivers d
  WHERE o.id = p_order_id
    AND o.driver_id IS NULL AND o.status IN ('pending','confirmed')
    AND o.assignment_timed_out_at IS NULL AND o.assignment_expires_at > now()
    AND o.payment_status IN ('paid','not_required')
    AND COALESCE(o.note,'') <> 'FREEPICK_DEMO_PERSISTENT'
    AND (o.offered_driver_id IS NULL OR o.offer_expires_at <= now())
    AND EXISTS(SELECT 1 FROM auth.users a WHERE a.id=d.user_id
      AND (a.banned_until IS NULL OR a.banned_until<=statement_timestamp()))
    AND d.is_available AND d.approval_status = 'approved'
    AND (d.acceptance_locked_until IS NULL OR d.acceptance_locked_until <= now())
    AND d.current_lat IS NOT NULL AND d.current_lng IS NOT NULL
    AND d.location_updated_at >= now() - interval '3 minutes'
    AND NOT (COALESCE(o.rejected_by,'[]'::jsonb) ? d.user_id::text)
    AND COALESCE((SELECT sum(w.available_delta) FROM public.driver_wallet_transactions w
      WHERE w.driver_id = d.user_id AND w.status = 'completed'),0) >= o.driver_advance_amount
    AND NOT EXISTS (SELECT 1 FROM public.orders a WHERE a.driver_id = d.user_id
      AND a.status IN ('assigned','picking_up','delivering','return_approved','returning'))
    AND NOT EXISTS (SELECT 1 FROM public.orders a WHERE a.id <> o.id
      AND a.offered_driver_id = d.user_id AND a.driver_id IS NULL
      AND a.assignment_timed_out_at IS NULL AND a.status IN ('pending','confirmed')
      AND a.offer_expires_at > now())
    -- Geographic distance only limits API work. Include a 200 m snapping margin.
    AND public.ST_DWithin(public.ST_SetSRID(public.ST_MakePoint(d.current_lng,d.current_lat),4326)::public.geography,
      public.ST_SetSRID(public.ST_MakePoint(o.pickup_lng,o.pickup_lat),4326)::public.geography,private.business_number(o.business_policy,'auto_radius_m')+200)
  ORDER BY d.user_id;
$function$;


CREATE OR REPLACE FUNCTION public.commit_road_driver_offer(p_order_id uuid, p_candidates jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_order public.orders%ROWTYPE; v_driver public.drivers%ROWTYPE; v_quote jsonb;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR v_order.offered_driver_id IS NOT NULL OR NOT EXISTS
    (SELECT 1 FROM private.road_driver_candidates(p_order_id)) THEN RETURN NULL; END IF;
  IF jsonb_typeof(p_candidates) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'INVALID_ROAD_QUOTES'; END IF;
  FOR v_quote IN SELECT q FROM jsonb_array_elements(p_candidates) q
    ORDER BY (q->>'distance_meters')::double precision,
      (q->>'duration_seconds')::double precision,q->>'user_id'
  LOOP
    PERFORM pg_advisory_xact_lock(hashtextextended('driver-assignment:' || (v_quote->>'user_id'),0));
    IF NOT private.driver_account_access_gate((v_quote->>'user_id')::uuid) THEN CONTINUE; END IF;
    SELECT d.* INTO v_driver FROM public.drivers d
      JOIN private.road_driver_candidates(p_order_id) c ON c.user_id = d.user_id
      WHERE d.user_id = (v_quote->>'user_id')::uuid FOR UPDATE OF d;
    IF NOT FOUND OR v_driver.is_available IS DISTINCT FROM true
      OR v_driver.approval_status <> 'approved'
      OR v_driver.acceptance_locked_until > clock_timestamp()
      OR v_driver.location_updated_at < clock_timestamp() - interval '3 minutes'
      OR NOT private.valid_pickup_road_quote(v_quote,v_driver,v_order,0,private.business_number(v_order.business_policy,'auto_radius_m')::double precision) THEN CONTINUE; END IF;
    BEGIN
      UPDATE public.orders SET offered_driver_id = v_driver.user_id,
        offer_expires_at = LEAST(clock_timestamp() + make_interval(secs=>private.business_number(v_order.business_policy,'offer_seconds')::double precision),assignment_expires_at),
        status_note = NULL WHERE id = p_order_id AND driver_id IS NULL AND offered_driver_id IS NULL
        AND assignment_timed_out_at IS NULL AND assignment_expires_at > clock_timestamp()
        AND status IN ('pending','confirmed');
      IF FOUND THEN
        INSERT INTO public.notifications(user_id,title,body,type,is_read,order_id)
          VALUES(v_driver.user_id,'Đơn giao hàng mới',
            format('Đơn %s đang chờ bạn nhận. Điểm lấy: %s',v_order.tracking_code,v_order.pickup_address),
            'order_update',false,p_order_id);
        INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
          VALUES(p_order_id,v_order.status,'Đã gửi lời mời tài xế',
            format('Lời mời %s giây; khoảng cách theo tuyến đường OSRM: %s m.',
              private.business_number(v_order.business_policy,'offer_seconds'),
              round((v_quote->>'distance_meters')::numeric)),NULL);
        RETURN v_driver.user_id;
      END IF;
    EXCEPTION WHEN unique_violation THEN CONTINUE;
    END;
  END LOOP;
  RETURN NULL;
END;
$function$;


CREATE OR REPLACE FUNCTION public.claim_free_pick_order(p_order_id uuid)
 RETURNS TABLE(order_id uuid, customer_id uuid, tracking_code text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  driver_user_id uuid := auth.uid();
  driver_profile public.drivers%ROWTYPE;
  free_order public.orders%ROWTYPE;
BEGIN
  IF driver_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT * INTO driver_profile
  FROM public.drivers
  WHERE user_id = driver_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND'; END IF;
  IF driver_profile.acceptance_locked_until > clock_timestamp() THEN
    RAISE EXCEPTION 'DRIVER_ACCEPTANCE_LOCKED';
  END IF;
  IF driver_profile.current_lat IS NULL
     OR driver_profile.current_lng IS NULL
     OR driver_profile.location_updated_at <
        clock_timestamp() - interval '3 minutes' THEN
    RAISE EXCEPTION 'DRIVER_LOCATION_STALE';
  END IF;

  SELECT * INTO free_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  IF free_order.driver_id IS NOT NULL
     OR free_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     )
     OR free_order.assignment_timed_out_at IS NOT NULL
     OR free_order.assignment_expires_at <= clock_timestamp() THEN
    RAISE EXCEPTION 'ORDER_NOT_AVAILABLE';
  END IF;
  IF free_order.offered_driver_id IS NOT NULL
     AND free_order.offered_driver_id IS DISTINCT FROM driver_user_id
     AND free_order.offer_expires_at > clock_timestamp() THEN
    RAISE EXCEPTION 'FREE_PICK_ORDER_RESERVED';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('driver-assignment:' || driver_user_id::text,0));
  IF NOT private.valid_pickup_road_quote(
    NULLIF(current_setting('giaohang.road_pickup_quote',true),'')::jsonb,
    driver_profile,free_order,(private.business_number(free_order.business_policy,'auto_radius_m')+0.000001)::double precision,private.business_number(free_order.business_policy,'free_pick_radius_m')::double precision) THEN
    RAISE EXCEPTION 'ROAD_ROUTE_QUOTE_REQUIRED';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.orders AS active_offer
    WHERE active_offer.id <> p_order_id
      AND active_offer.offered_driver_id = driver_user_id
      AND active_offer.driver_id IS NULL
      AND active_offer.offer_expires_at > clock_timestamp()
      AND active_offer.assignment_timed_out_at IS NULL
      AND active_offer.status IN (
        'pending'::public.order_status,
        'confirmed'::public.order_status
      )
  ) THEN RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_OFFER'; END IF;

  UPDATE public.orders
  SET offered_driver_id = driver_user_id,
      offer_expires_at = LEAST(
        clock_timestamp() + make_interval(secs=>private.business_number(free_order.business_policy,'offer_seconds')::double precision),
        free_order.assignment_expires_at
      ),
      status_note = 'Tài xế đang nhận đơn qua FreePick.'
  WHERE id = p_order_id;

  RETURN QUERY
  SELECT accepted.order_id, accepted.customer_id, accepted.tracking_code
  FROM public.accept_order(p_order_id) AS accepted;
END;
$function$;


CREATE OR REPLACE FUNCTION public.get_free_pick_orders_in_view(p_south double precision, p_west double precision, p_north double precision, p_east double precision, p_limit integer DEFAULT 50)
 RETURNS SETOF orders
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  driver_user_id uuid := auth.uid();
  driver_profile public.drivers%ROWTYPE;
BEGIN
  IF driver_user_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF p_south < -90 OR p_north > 90
     OR p_west < -180 OR p_east > 180
     OR p_south >= p_north OR p_west >= p_east THEN
    RAISE EXCEPTION 'FREE_PICK_VIEWPORT_INVALID';
  END IF;
  IF p_north - p_south > 1 OR p_east - p_west > 1 THEN
    RAISE EXCEPTION 'FREE_PICK_VIEWPORT_TOO_LARGE';
  END IF;

  SELECT * INTO driver_profile
  FROM public.drivers
  WHERE user_id = driver_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'DRIVER_PROFILE_NOT_FOUND'; END IF;
  IF driver_profile.acceptance_locked_until > clock_timestamp() THEN
    RAISE EXCEPTION 'DRIVER_ACCEPTANCE_LOCKED';
  END IF;
  IF driver_profile.approval_status IS DISTINCT FROM
     'approved'::public.approval_status THEN
    RAISE EXCEPTION 'DRIVER_NOT_APPROVED';
  END IF;
  IF driver_profile.is_available IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'DRIVER_OFFLINE';
  END IF;
  IF driver_profile.current_lat IS NULL
     OR driver_profile.current_lng IS NULL
     OR driver_profile.location_updated_at < now() - interval '3 minutes' THEN
    RAISE EXCEPTION 'DRIVER_LOCATION_STALE';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.orders AS active_order
    WHERE active_order.driver_id = driver_user_id
      AND active_order.status IN (
        'assigned'::public.order_status,
        'picking_up'::public.order_status,
        'delivering'::public.order_status,
        'return_approved'::public.order_status,
        'returning'::public.order_status
      )
  ) THEN RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_ORDER'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.orders AS active_offer
    WHERE active_offer.offered_driver_id = driver_user_id
      AND active_offer.driver_id IS NULL
      AND active_offer.offer_expires_at > now()
      AND active_offer.assignment_timed_out_at IS NULL
      AND active_offer.status IN (
        'pending'::public.order_status,
        'confirmed'::public.order_status
      )
  ) THEN RAISE EXCEPTION 'DRIVER_HAS_ACTIVE_OFFER'; END IF;

  RETURN QUERY
  SELECT free_order.*
  FROM public.orders AS free_order
  WHERE free_order.driver_id IS NULL
    AND free_order.status IN (
      'pending'::public.order_status,
      'confirmed'::public.order_status
    )
    AND free_order.payment_status IN ('not_required', 'paid')
    AND free_order.assignment_timed_out_at IS NULL
    AND free_order.assignment_expires_at > now()
    AND (
      free_order.offered_driver_id IS NULL
      OR free_order.offer_expires_at IS NULL
      OR free_order.offer_expires_at <= now()
    )
    AND free_order.pickup_lat BETWEEN p_south AND p_north
    AND free_order.pickup_lng BETWEEN p_west AND p_east
    AND public.ST_DWithin(
      public.ST_SetSRID(
        public.ST_MakePoint(
          driver_profile.current_lng,
          driver_profile.current_lat
        ),
        4326
      )::public.geography,
      public.ST_SetSRID(
        public.ST_MakePoint(free_order.pickup_lng, free_order.pickup_lat),
        4326
      )::public.geography,
      private.business_number(free_order.business_policy,'free_pick_radius_m')+200
    )
  ORDER BY free_order.created_at ASC, free_order.id ASC
  LIMIT LEAST(GREATEST(p_limit, 1), 50);
END;
$function$;


CREATE OR REPLACE FUNCTION public.road_lookup_candidates(pickup_lat double precision, pickup_lng double precision, radius_meters double precision DEFAULT 2000, max_results integer DEFAULT 10)
 RETURNS TABLE(id uuid, user_id uuid, full_name text, vehicle_type text, license_plate text, current_lat double precision, current_lng double precision, distance_meters double precision, rating double precision, location_updated_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  WITH candidate_distances AS (
    SELECT
      driver_profile.id,
      driver_profile.user_id,
      driver_user.full_name,
      driver_profile.vehicle_type,
      driver_profile.license_plate,
      driver_profile.current_lat,
      driver_profile.current_lng,
      public.ST_Distance(
        public.ST_SetSRID(
          public.ST_MakePoint(
            driver_profile.current_lng,
            driver_profile.current_lat
          ),
          4326
        )::public.geography,
        public.ST_SetSRID(
          public.ST_MakePoint(pickup_lng, pickup_lat),
          4326
        )::public.geography
      ) AS distance_meters,
      COALESCE(driver_profile.rating, 0)::double precision AS rating,
      driver_profile.location_updated_at
    FROM public.drivers AS driver_profile
    JOIN public.users AS driver_user
      ON driver_user.id = driver_profile.user_id
    WHERE pickup_lat BETWEEN -90 AND 90
      AND pickup_lng BETWEEN -180 AND 180
      AND radius_meters > 0
      AND driver_profile.is_available = true
      AND (driver_profile.acceptance_locked_until IS NULL
        OR driver_profile.acceptance_locked_until <= now())
      AND driver_profile.approval_status =
        'approved'::public.approval_status
      AND driver_profile.current_lat IS NOT NULL
      AND driver_profile.current_lng IS NOT NULL
      AND driver_profile.location_updated_at >= now() - interval '3 minutes'
      AND NOT EXISTS (
        SELECT 1
        FROM public.orders AS active_order
        WHERE active_order.driver_id = driver_profile.user_id
          AND active_order.status IN (
            'assigned'::public.order_status,
            'picking_up'::public.order_status,
            'delivering'::public.order_status,
            'return_approved'::public.order_status,
            'returning'::public.order_status
          )
      )
      AND public.ST_DWithin(
        public.ST_SetSRID(
          public.ST_MakePoint(
            driver_profile.current_lng,
            driver_profile.current_lat
          ),
          4326
        )::public.geography,
        public.ST_SetSRID(
          public.ST_MakePoint(pickup_lng, pickup_lat),
          4326
        )::public.geography,
        LEAST(GREATEST(radius_meters,1),private.business_number(private.current_business_settings(),'auto_radius_m')) + 200
      )
  )
  SELECT
    candidate.id,
    candidate.user_id,
    candidate.full_name,
    candidate.vehicle_type,
    candidate.license_plate,
    candidate.current_lat,
    candidate.current_lng,
    candidate.distance_meters,
    candidate.rating,
    candidate.location_updated_at
  FROM candidate_distances AS candidate
  ORDER BY candidate.distance_meters ASC, candidate.user_id ASC
;
$function$;


CREATE OR REPLACE FUNCTION public.road_dispatch_work(p_secret text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_secret text; v_work jsonb;
BEGIN
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'road_dispatch_secret';
  IF p_secret IS NULL OR v_secret IS NULL OR p_secret <> v_secret THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object('id',w.id,'pickup_lat',w.pickup_lat,
    'pickup_lng',w.pickup_lng,'business_policy',w.business_policy) ORDER BY w.created_at,w.id),'[]'::jsonb) INTO v_work
  FROM (SELECT o.id,o.pickup_lat,o.pickup_lng,o.created_at,o.business_policy FROM public.orders o
    WHERE o.driver_id IS NULL AND o.status IN ('pending','confirmed')
      AND o.assignment_timed_out_at IS NULL AND o.assignment_expires_at > now()
      AND o.payment_status IN ('paid','not_required')
      AND COALESCE(o.note,'') <> 'FREEPICK_DEMO_PERSISTENT'
      AND o.offered_driver_id IS NULL
    ORDER BY o.created_at,o.id LIMIT 20) w;
  RETURN v_work;
END;
$function$;


CREATE OR REPLACE FUNCTION public.retry_order_assignment(p_order_id uuid)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  retry_order public.orders%ROWTYPE;
  new_deadline timestamptz;
BEGIN
  SELECT * INTO retry_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND OR auth.uid() IS DISTINCT FROM retry_order.customer_id THEN
    RAISE EXCEPTION 'ORDER_NOT_FOUND';
  END IF;
  IF retry_order.driver_id IS NOT NULL
     OR retry_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     ) THEN
    RAISE EXCEPTION 'ORDER_NOT_RETRYABLE';
  END IF;
  IF retry_order.assignment_timed_out_at IS NULL
     AND retry_order.assignment_expires_at > clock_timestamp() THEN
    RAISE EXCEPTION 'ASSIGNMENT_STILL_OPEN';
  END IF;
  new_deadline := clock_timestamp() + make_interval(mins=>private.business_number(retry_order.business_policy,'assignment_minutes')::integer);
  UPDATE public.orders
  SET assignment_expires_at = new_deadline,
      assignment_timed_out_at = NULL,
      rejected_by = '[]'::jsonb,
      offered_driver_id = NULL,
      offer_expires_at = NULL,
      status_note = NULL
  WHERE id = p_order_id;
  INSERT INTO public.order_status_logs(
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id,
    retry_order.status,
    'Đang tìm lại tài xế',
    format('Hệ thống bắt đầu lượt tìm tài xế mới trong %s phút.',private.business_number(retry_order.business_policy,'assignment_minutes')),
    auth.uid()
  );
  PERFORM private.dispatch_next_order_offer(p_order_id, 2000);
  RETURN new_deadline;
END;
$function$;


CREATE OR REPLACE FUNCTION private.dispatch_next_order_offer_unbounded(p_order_id uuid, p_radius_meters double precision DEFAULT 2000)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  offer_order public.orders%ROWTYPE;
  candidate record;
  v_now timestamptz := clock_timestamp();
  excluded_drivers jsonb;
  offer_deadline timestamptz;
BEGIN
  SELECT *
  INTO offer_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN RETURN NULL; END IF;

  IF COALESCE(offer_order.note, '') = 'FREEPICK_DEMO_PERSISTENT' THEN
    UPDATE public.orders
    SET offered_driver_id = NULL,
        offer_expires_at = NULL,
        status_note = NULL
    WHERE id = p_order_id;
    RETURN NULL;
  END IF;

  IF offer_order.driver_id IS NOT NULL
     OR offer_order.status NOT IN (
       'pending'::public.order_status,
       'confirmed'::public.order_status
     )
     OR offer_order.assignment_timed_out_at IS NOT NULL THEN
    RETURN NULL;
  END IF;

  excluded_drivers := COALESCE(offer_order.rejected_by, '[]'::jsonb);

  IF offer_order.assignment_expires_at <= v_now THEN
    IF offer_order.offered_driver_id IS NOT NULL
       AND NOT (excluded_drivers ? offer_order.offered_driver_id::text) THEN
      excluded_drivers := excluded_drivers
        || pg_catalog.jsonb_build_array(offer_order.offered_driver_id::text);
    END IF;
    UPDATE public.orders
    SET assignment_timed_out_at = v_now,
        offered_driver_id = NULL,
        offer_expires_at = NULL,
        rejected_by = excluded_drivers,
        status_note = format('Không có tài xế nhận đơn trong vòng %s phút.',private.business_number(offer_order.business_policy,'assignment_minutes'))
    WHERE id = p_order_id AND assignment_timed_out_at IS NULL;
    IF FOUND THEN
      INSERT INTO public.order_status_logs(
        order_id, status, title, description, logged_by
      ) VALUES (
        p_order_id, offer_order.status, 'Chưa tìm thấy tài xế',
        format('Không có tài xế nhận đơn trong vòng %s phút.',private.business_number(offer_order.business_policy,'assignment_minutes')), NULL
      );
    END IF;
    RETURN NULL;
  END IF;

  IF offer_order.offered_driver_id IS NOT NULL
     AND offer_order.offer_expires_at > v_now THEN
    RETURN offer_order.offered_driver_id;
  END IF;

  IF offer_order.offered_driver_id IS NOT NULL THEN
    IF NOT (excluded_drivers ? offer_order.offered_driver_id::text) THEN
      excluded_drivers := excluded_drivers
        || pg_catalog.jsonb_build_array(offer_order.offered_driver_id::text);
    END IF;
    INSERT INTO public.order_status_logs(
      order_id, status, title, description, logged_by
    ) VALUES (
      p_order_id, offer_order.status, 'Lời mời tài xế hết hạn',
      format('Tài xế không phản hồi lời mời trong vòng %s giây.',private.business_number(offer_order.business_policy,'offer_seconds')), NULL
    );
    UPDATE public.orders
    SET rejected_by = excluded_drivers,
        offered_driver_id = NULL,
        offer_expires_at = NULL
    WHERE id = p_order_id;
  END IF;

  IF offer_order.payment_status IN ('paid','not_required') THEN
    PERFORM private.request_road_dispatch();
  END IF;
  RETURN NULL;
END;
$function$;


CREATE OR REPLACE FUNCTION public.support_approve_return(p_report_id uuid, p_reason_code text, p_destination_type text, p_destination_address text, p_destination_lat double precision, p_destination_lng double precision, p_route_origin_lat double precision, p_route_origin_lng double precision, p_route_distance_m integer, p_route_duration_s integer, p_quote_source text, p_fee_payer text, p_customer_return_charge bigint, p_driver_return_earning bigint, p_instruction text DEFAULT NULL::text)
 RETURNS order_returns
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  actor_role public.user_role;
  report public.risk_reports%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  return_order public.orders%ROWTYPE;
  created_return public.order_returns%ROWTYPE;
  expected_return_fee bigint;
  normalized_instruction text := NULLIF(trim(p_instruction), '');
BEGIN
  SELECT role INTO actor_role FROM public.users WHERE id = actor_id;
  IF actor_id IS NULL OR actor_role <> 'support'::public.user_role THEN
    RAISE EXCEPTION 'SUPPORT_REQUIRED' USING ERRCODE = '42501';
  END IF;
  IF p_destination_type NOT IN ('sender', 'processing_center')
    OR char_length(trim(COALESCE(p_destination_address, ''))) < 3
    OR p_destination_lat NOT BETWEEN -90 AND 90
    OR p_destination_lng NOT BETWEEN -180 AND 180
    OR p_route_origin_lat NOT BETWEEN -90 AND 90
    OR p_route_origin_lng NOT BETWEEN -180 AND 180
    OR p_route_distance_m < 0
    OR p_route_duration_s < 0
    OR p_quote_source NOT IN ('osrm', 'fallback')
    OR p_fee_payer <> 'platform'
    OR p_customer_return_charge < 0
    OR p_driver_return_earning < 0 THEN
    RAISE EXCEPTION 'INVALID_RETURN_QUOTE' USING ERRCODE = '22023';
  END IF;
  IF p_customer_return_charge <> 0 THEN
    RAISE EXCEPTION 'RETURN_CUSTOMER_CHARGE_NOT_SUPPORTED'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO report
  FROM public.risk_reports
  WHERE id = p_report_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'RISK_REPORT_NOT_FOUND'; END IF;

  SELECT * INTO return_order
  FROM public.orders
  WHERE id = report.order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;

  -- All return commands serialize on the order before locking case records.
  SELECT * INTO report FROM public.risk_reports
  WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RISK_REPORT_NOT_FOUND'; END IF;

  expected_return_fee := round(
    greatest(COALESCE(return_order.delivery_fee, 0), 0) * private.business_number(return_order.business_policy,'return_fee_rate_bps')/10000
  )::bigint;

  SELECT * INTO intervention
  FROM public.risk_report_interventions
  WHERE risk_report_id = p_report_id
  FOR UPDATE;

  IF report.assigned_to IS DISTINCT FROM actor_id
    OR report.status NOT IN ('investigating', 'action_required') THEN
    RAISE EXCEPTION 'REPORT_NOT_ASSIGNED_TO_SUPPORT'
      USING ERRCODE = '42501';
  END IF;
  IF intervention.state <> 'awaiting_triage'
    OR return_order.status <> 'delivering'::public.order_status
    OR return_order.driver_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_RETURN_APPROVAL_STATE'
      USING ERRCODE = '23514';
  END IF;

  UPDATE public.risk_report_interventions SET
    state = 'return_required',
    driver_id = return_order.driver_id,
    decided_by = actor_id,
    decided_at = clock_timestamp(),
    instruction = COALESCE(
      normalized_instruction,
      'Quay về điểm trả và bàn giao hàng cho đúng người phụ trách.'
    ),
    updated_at = clock_timestamp()
  WHERE risk_report_id = p_report_id
  RETURNING * INTO intervention;

  INSERT INTO public.order_returns (
    order_id, risk_report_id, driver_id, destination_type,
    destination_address, destination_lat, destination_lng,
    route_origin_lat, route_origin_lng, route_distance_m, route_duration_s,
    quote_source, reason_code, fee_payer, customer_return_charge,
    driver_return_earning, fee_status, instruction, approved_by
  ) VALUES (
    return_order.id, report.id, return_order.driver_id, p_destination_type,
    trim(p_destination_address), p_destination_lat, p_destination_lng,
    p_route_origin_lat, p_route_origin_lng, p_route_distance_m,
    p_route_duration_s, p_quote_source, trim(p_reason_code), p_fee_payer,
    p_customer_return_charge, expected_return_fee,
    'waived',
    COALESCE(
      normalized_instruction,
      'Quay về điểm trả và bàn giao hàng cho đúng người phụ trách.'
    ),
    actor_id
  )
  ON CONFLICT (order_id) DO UPDATE SET
    risk_report_id = EXCLUDED.risk_report_id,
    driver_id = EXCLUDED.driver_id,
    destination_type = EXCLUDED.destination_type,
    destination_address = EXCLUDED.destination_address,
    destination_lat = EXCLUDED.destination_lat,
    destination_lng = EXCLUDED.destination_lng,
    route_origin_lat = EXCLUDED.route_origin_lat,
    route_origin_lng = EXCLUDED.route_origin_lng,
    route_distance_m = EXCLUDED.route_distance_m,
    route_duration_s = EXCLUDED.route_duration_s,
    quote_source = EXCLUDED.quote_source,
    reason_code = EXCLUDED.reason_code,
    fee_payer = EXCLUDED.fee_payer,
    customer_return_charge = EXCLUDED.customer_return_charge,
    driver_return_earning = EXCLUDED.driver_return_earning,
    fee_status = EXCLUDED.fee_status,
    instruction = EXCLUDED.instruction,
    approved_by = EXCLUDED.approved_by,
    status = 'approved',
    approved_at = clock_timestamp(),
    started_at = NULL,
    arrived_at = NULL,
    returned_at = NULL,
    receiver_name = NULL,
    proof_storage_path = NULL,
    updated_at = clock_timestamp()
  WHERE public.order_returns.status = 'cancelled'
  RETURNING * INTO created_return;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'RETURN_ALREADY_ACTIVE' USING ERRCODE = '23514';
  END IF;

  UPDATE public.orders SET
    status = 'return_approved'::public.order_status,
    status_note = 'CSKH đã duyệt hoàn hàng về điểm trả.',
    updated_at = clock_timestamp()
  WHERE id = return_order.id;

  IF report.status = 'investigating' THEN
    UPDATE public.risk_reports SET
      status = 'action_required',
      updated_by = actor_id,
      updated_at = clock_timestamp()
    WHERE id = report.id;
  END IF;

  INSERT INTO public.order_status_logs(
    order_id, status, title, description, logged_by
  ) VALUES (
    return_order.id,
    'return_approved'::public.order_status,
    'CSKH đã duyệt hoàn hàng',
    'Tài xế chuẩn bị quay về điểm trả: ' || trim(p_destination_address),
    actor_id
  );

  INSERT INTO public.risk_report_events(
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (
    report.id, actor_id, 'return_approved', report.status,
    CASE WHEN report.status = 'investigating'
      THEN 'action_required' ELSE report.status END,
    jsonb_build_object(
      'return_id', created_return.id,
      'fee_payer', p_fee_payer,
      'customer_return_charge', p_customer_return_charge,
      'driver_return_earning', expected_return_fee,
      'return_fee_rate_bps', private.business_number(return_order.business_policy,'return_fee_rate_bps')
    )
  );

  PERFORM private.enqueue_case_notification(
    return_order.customer_id,
    'Đã duyệt hoàn hàng',
    'Tài xế sẽ quay về điểm trả đã được CSKH xác nhận.',
    'order_return_approved',
    return_order.id
  );
  PERFORM private.enqueue_case_notification(
    return_order.driver_id,
    'Chuyến hoàn hàng mới',
    format('Phí hoàn hàng bằng %s%% cước giao và do đơn vị vận hành chi trả.',private.business_number(return_order.business_policy,'return_fee_rate_bps')/100),
    'order_return_approved',
    return_order.id
  );
  RETURN created_return;
END;
$function$;


CREATE OR REPLACE FUNCTION public.confirm_order_return(p_order_id uuid, p_receiver_name text, p_note text DEFAULT NULL::text)
 RETURNS order_returns
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor_id uuid := (SELECT auth.uid());
  return_order public.orders%ROWTYPE;
  order_return public.order_returns%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  return_proof public.order_delivery_proofs%ROWTYPE;
  distance_m double precision;
  delivery_earning bigint;
  advance_refunded boolean := false;
  normalized_receiver text := trim(COALESCE(p_receiver_name, ''));
  normalized_note text := NULLIF(trim(p_note), '');
BEGIN
  IF actor_id IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF char_length(normalized_receiver) NOT BETWEEN 2 AND 80 THEN
    RAISE EXCEPTION 'RETURN_RECEIVER_REQUIRED' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO return_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;

  SELECT * INTO order_return
  FROM public.order_returns
  WHERE order_id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RETURN_NOT_FOUND'; END IF;

  IF return_order.driver_id IS DISTINCT FROM actor_id
    OR order_return.driver_id IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED' USING ERRCODE = '42501';
  END IF;
  IF return_order.status = 'returned'::public.order_status
    AND order_return.status = 'returned' THEN
    RETURN order_return;
  END IF;
  IF return_order.status <> 'returning'::public.order_status
    OR order_return.status <> 'returning' THEN
    RAISE EXCEPTION 'INVALID_RETURN_COMPLETE_STATE'
      USING ERRCODE = '23514';
  END IF;

  SELECT * INTO return_proof
  FROM public.order_delivery_proofs AS proof
  WHERE proof.order_id = p_order_id
    AND proof.driver_id = actor_id
    AND proof.stage = 'return'
  FOR UPDATE;
  IF NOT FOUND OR return_proof.captured_lat IS NULL
    OR return_proof.captured_lng IS NULL THEN
    RAISE EXCEPTION 'RETURN_PROOF_REQUIRED' USING ERRCODE = '23514';
  END IF;

  distance_m := 6371000 * acos(least(1.0, greatest(-1.0,
    cos(radians(order_return.destination_lat))
      * cos(radians(return_proof.captured_lat))
      * cos(radians(return_proof.captured_lng)
        - radians(order_return.destination_lng))
    + sin(radians(order_return.destination_lat))
      * sin(radians(return_proof.captured_lat))
  )));
  IF distance_m > 150 THEN
    RAISE EXCEPTION 'RETURN_OUTSIDE_GEOFENCE' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO intervention
  FROM public.risk_report_interventions
  WHERE risk_report_id = order_return.risk_report_id
  FOR UPDATE;
  IF intervention.state <> 'return_required' THEN
    RAISE EXCEPTION 'RETURN_INTERVENTION_MISMATCH' USING ERRCODE = '23514';
  END IF;

  delivery_earning := round(greatest(COALESCE(
    return_order.driver_net_earning,
    return_order.delivery_fee,
    0
  ), 0))::bigint;

  UPDATE public.orders SET
    status = 'returned'::public.order_status,
    risk_hold_report_id = NULL,
    status_note = COALESCE(normalized_note, 'Đã hoàn hàng về điểm trả.'),
    updated_at = clock_timestamp()
  WHERE id = p_order_id;

  UPDATE public.order_returns SET
    status = 'returned',
    fee_status = 'settled',
    receiver_name = normalized_receiver,
    proof_storage_path = return_proof.storage_path,
    arrived_at = COALESCE(arrived_at, return_proof.captured_at),
    returned_at = COALESCE(returned_at, clock_timestamp()),
    updated_at = clock_timestamp()
  WHERE id = order_return.id
  RETURNING * INTO order_return;

  UPDATE public.risk_report_interventions SET
    state = 'released',
    driver_released_at = clock_timestamp(),
    updated_at = clock_timestamp()
  WHERE risk_report_id = order_return.risk_report_id;

  UPDATE public.risk_reports SET
    status = 'resolved',
    resolution = COALESCE(normalized_note, 'Đã hoàn hàng về điểm trả.'),
    resolved_at = clock_timestamp(),
    updated_by = actor_id,
    updated_at = clock_timestamp()
  WHERE id = order_return.risk_report_id;

  INSERT INTO public.driver_wallet_transactions (
    driver_id, order_id, transaction_type, amount, available_delta,
    idempotency_key, completed_at, metadata
  ) VALUES (
    actor_id,
    p_order_id,
    'return_delivery_earning',
    delivery_earning,
    delivery_earning,
    'order:' || p_order_id::text || ':return_delivery_earning',
    clock_timestamp(),
    jsonb_build_object(
      'return_id', order_return.id,
      'delivery_fee', round(return_order.delivery_fee)::bigint,
      'earning_kind', 'original_delivery_fee_for_returned_order'
    )
  ) ON CONFLICT (idempotency_key) DO NOTHING;

  INSERT INTO public.driver_wallet_transactions (
    driver_id, order_id, transaction_type, amount, available_delta,
    idempotency_key, completed_at, metadata
  ) VALUES (
    actor_id, p_order_id, 'return_earning',
    order_return.driver_return_earning,
    order_return.driver_return_earning,
    'order:' || p_order_id::text || ':return_earning',
    clock_timestamp(),
    jsonb_build_object(
      'return_id', order_return.id,
      'distance_m', order_return.route_distance_m,
      'fee_payer', order_return.fee_payer,
      'return_fee_rate_bps', private.business_number(return_order.business_policy,'return_fee_rate_bps'),
      'delivery_fee', round(return_order.delivery_fee)::bigint
    )
  ) ON CONFLICT (idempotency_key) DO NOTHING;

  advance_refunded := private.release_paid_goods_deposit(
    return_order, actor_id, 'completed_physical_return', order_return.id
  ) > 0;

  IF return_order.cod_collection_amount > 0 AND EXISTS (
    SELECT 1
    FROM public.driver_wallet_transactions AS capture
    WHERE capture.order_id = p_order_id
      AND capture.driver_id = actor_id
      AND capture.transaction_type = 'cod_advance_capture'
      AND capture.status = 'completed'
  ) THEN
    INSERT INTO public.driver_wallet_transactions (
      driver_id, order_id, transaction_type, amount, available_delta,
      idempotency_key, completed_at, metadata
    ) VALUES (
      actor_id,
      p_order_id,
      'cod_release',
      return_order.driver_advance_amount,
      return_order.driver_advance_amount,
      'order:' || p_order_id::text || ':return_cod_release',
      clock_timestamp(),
      jsonb_build_object(
        'return_id', order_return.id,
        'reason', 'completed_physical_return'
      )
    ) ON CONFLICT (idempotency_key) DO NOTHING;
    advance_refunded := true;
  END IF;

  INSERT INTO public.order_status_logs (
    order_id, status, title, description, logged_by
  ) VALUES (
    p_order_id, 'returned'::public.order_status,
    'Hoàn hàng đã ghi nhận',
    'Kiện hàng đã được bàn giao cho ' || normalized_receiver
      || '. Cước giao và phí hoàn hàng đã được ghi nhận cho tài xế.',
    actor_id
  );

  INSERT INTO public.risk_report_events (
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (
    order_return.risk_report_id, actor_id, 'return_completed',
    'action_required', 'resolved',
    jsonb_build_object(
      'return_id', order_return.id,
      'receiver_name', normalized_receiver,
      'proof_storage_path', return_proof.storage_path,
      'driver_delivery_earning', delivery_earning,
      'return_fee_amount', order_return.driver_return_earning,
      'driver_total_earning',
        delivery_earning + order_return.driver_return_earning,
      'driver_advance_refunded', advance_refunded
    )
  );

  PERFORM private.enqueue_case_notification(
    return_order.customer_id,
    'Đã hoàn hàng',
    'Kiện hàng đã được bàn giao lại thành công.',
    'order_return_completed',
    return_order.id
  );
  PERFORM private.enqueue_case_notification(
    actor_id,
    'Hoàn hàng đã ghi nhận',
    'Cước giao và phí hoàn hàng đã được cộng vào Ví Tài Xế.',
    'order_return_completed',
    return_order.id
  );
  RETURN order_return;
END;
$function$;


CREATE OR REPLACE FUNCTION public.resume_risk_held_order(p_report_id uuid)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor_id uuid := private.require_risk_staff();
  report public.risk_reports%ROWTYPE;
  intervention public.risk_report_interventions%ROWTYPE;
  v_order public.orders%ROWTYPE;
  previous_report_status text;
  previous_driver_id uuid;
  excluded_drivers jsonb;
  v_now timestamptz;
BEGIN
  SELECT * INTO report FROM public.risk_reports
    WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Risk report not found' USING ERRCODE = 'P0002';
  END IF;
  IF report.assigned_to IS DISTINCT FROM actor_id THEN
    RAISE EXCEPTION 'Only the assigned staff member can resume the order'
      USING ERRCODE = '42501';
  END IF;
  SELECT * INTO intervention FROM public.risk_report_interventions
    WHERE risk_report_id = p_report_id FOR UPDATE;
  IF NOT FOUND OR intervention.order_id IS DISTINCT FROM report.order_id THEN
    RAISE EXCEPTION 'Order intervention not found' USING ERRCODE = '23514';
  END IF;
  SELECT * INTO v_order FROM public.orders
    WHERE id = report.order_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0002';
  END IF;

  -- A lost response/retry must not extend the next search or unassign its driver.
  IF intervention.state = 'released' AND EXISTS (
    SELECT 1 FROM public.risk_report_events event
    WHERE event.risk_report_id = p_report_id
      AND event.details->>'operation' = 'support_driver_reassignment'
      AND event.details->>'order_requeued' = 'true'
  ) THEN
    RETURN v_order;
  END IF;
  IF v_order.status <> 'risk_hold'::public.order_status
    OR v_order.driver_id IS NOT NULL
    OR intervention.state NOT IN ('held_before_pickup', 'released')
    OR intervention.driver_released_at IS NULL
    OR v_order.risk_hold_report_id IS DISTINCT FROM p_report_id THEN
    RAISE EXCEPTION 'Order is not ready to resume' USING ERRCODE = '23514';
  END IF;
  IF intervention.state = 'held_before_pickup'
    AND v_order.actual_picked_up_at IS NOT NULL THEN
    RAISE EXCEPTION 'Collected cargo must use the custody workflow'
      USING ERRCODE = '23514';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.risk_report_interventions other_intervention
    WHERE other_intervention.order_id = v_order.id
      AND other_intervention.risk_report_id <> p_report_id
      AND other_intervention.state IN (
        'held_before_pickup', 'return_required', 'handoff_required'
      )
  ) THEN
    RAISE EXCEPTION 'Another risk intervention still blocks this order'
      USING ERRCODE = '23514';
  END IF;

  v_now := clock_timestamp();
  previous_report_status := report.status;
  previous_driver_id := intervention.driver_id;
  excluded_drivers := COALESCE(v_order.rejected_by, '[]'::jsonb);
  IF jsonb_typeof(excluded_drivers) <> 'array' THEN
    RAISE EXCEPTION 'Order driver exclusions are invalid' USING ERRCODE = '23514';
  END IF;
  IF intervention.driver_id IS NOT NULL
    AND NOT (excluded_drivers ? intervention.driver_id::text) THEN
    excluded_drivers := excluded_drivers
      || jsonb_build_array(intervention.driver_id::text);
  END IF;

  -- Retain the pre-pickup participant so RLS delivers the cancellation notice.
  -- Completed physical handoffs keep the existing participant clearing behavior.
  UPDATE public.risk_report_interventions SET
    state = 'released',
    driver_id = CASE WHEN intervention.state = 'held_before_pickup'
      THEN intervention.driver_id ELSE NULL END,
    driver_released_at = COALESCE(driver_released_at, v_now),
    updated_at = v_now
  WHERE risk_report_id = p_report_id RETURNING * INTO intervention;

  UPDATE public.orders SET
    status = 'pending'::public.order_status,
    driver_id = NULL,
    risk_hold_report_id = NULL,
    offered_driver_id = NULL,
    offer_expires_at = NULL,
    assignment_expires_at = v_now + make_interval(mins=>private.business_number(v_order.business_policy,'assignment_minutes')::integer),
    assignment_timed_out_at = NULL,
    rejected_by = excluded_drivers,
    pickup_arrived_at = NULL,
    actual_picked_up_at = NULL,
    estimated_delivery_at = NULL,
    status_note = 'Đang tìm tài xế mới sau khi CSKH hủy nhiệm vụ tài xế cũ.',
    updated_at = v_now
  WHERE id = v_order.id RETURNING * INTO v_order;

  -- Existing closed reports stay closed when recovering a stranded old order.
  IF report.status = 'action_required' THEN
    UPDATE public.risk_reports SET
      status = 'investigating', updated_by = actor_id
    WHERE id = p_report_id RETURNING * INTO report;
  END IF;
  INSERT INTO public.order_status_logs(
    order_id, status, title, description, logged_by
  ) VALUES (
    v_order.id, 'pending'::public.order_status, 'Đang tìm tài xế mới',
    'CSKH đã gỡ tài xế cũ. Đơn bắt đầu lượt tìm tài xế mới theo thời hạn đã chốt.', actor_id
  );
  INSERT INTO public.risk_report_events(
    risk_report_id, actor_id, event_type, from_status, to_status, details
  ) VALUES (
    p_report_id, actor_id, 'intervention_changed',
    previous_report_status, report.status,
    jsonb_build_object(
      'state', 'released', 'operation', 'support_driver_reassignment',
      'order_requeued', true, 'released_driver_id', previous_driver_id,
      'assignment_expires_at', v_order.assignment_expires_at
    )
  );
  INSERT INTO public.notifications(user_id,title,body,type,is_read,order_id)
    VALUES(v_order.customer_id,'Đang tìm tài xế mới',
      format('Đơn %s đang tìm tài xế mới sau khi CSKH gỡ tài xế cũ.',
        v_order.tracking_code),'order_update',false,v_order.id);

  PERFORM private.dispatch_next_order_offer(v_order.id, 2000);
  SELECT * INTO v_order FROM public.orders WHERE id = v_order.id;
  RETURN v_order;
END;
$function$;


CREATE OR REPLACE FUNCTION public.cancel_driver_order(p_order_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_release bigint;
  v_locked_until timestamptz;
  v_now timestamptz;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_actor AND role = 'driver') THEN
    RAISE EXCEPTION 'DRIVER_ROLE_REQUIRED';
  END IF;
  IF p_reason IS NULL OR p_reason NOT IN ('store_closed', 'personal') THEN
    RAISE EXCEPTION 'CANCELLATION_REASON_INVALID';
  END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ORDER_NOT_FOUND'; END IF;
  -- Retry after a lost response: do not extend an already committed cooldown.
  IF p_reason = 'personal' AND v_order.driver_id IS DISTINCT FROM v_actor AND EXISTS (
    SELECT 1 FROM public.order_status_logs log
    WHERE log.order_id = p_order_id AND log.logged_by = v_actor
      AND log.title = 'Tài xế hủy nhận đơn' AND log.status = 'pending'
  ) THEN
    SELECT acceptance_locked_until INTO v_locked_until FROM public.drivers WHERE user_id = v_actor;
    RETURN jsonb_build_object('order_id', p_order_id, 'new_status', v_order.status,
      'locked_until', v_locked_until, 'server_now', clock_timestamp());
  END IF;
  IF v_order.driver_id IS DISTINCT FROM v_actor THEN RAISE EXCEPTION 'DRIVER_NOT_ASSIGNED'; END IF;
  IF p_reason = 'store_closed' AND v_order.status = 'cancelled'
    AND v_order.status_note = 'Quán đóng cửa' THEN
    RETURN jsonb_build_object('order_id', p_order_id, 'new_status', 'cancelled',
      'locked_until', NULL, 'server_now', clock_timestamp());
  END IF;
  IF v_order.status NOT IN ('assigned', 'picking_up') OR v_order.actual_picked_up_at IS NOT NULL THEN
    RAISE EXCEPTION 'ORDER_ALREADY_PICKED_UP';
  END IF;
  -- A submitted pickup proof also blocks abandonment until staff resolves custody.
  IF EXISTS (SELECT 1 FROM public.order_delivery_proofs
    WHERE order_id = p_order_id AND driver_id = v_actor AND stage = 'pickup') THEN
    RAISE EXCEPTION 'ORDER_ALREADY_PICKED_UP';
  END IF;
  IF EXISTS (SELECT 1 FROM public.risk_report_interventions WHERE order_id = p_order_id
    AND state IN ('return_required','handoff_required')) THEN
    RAISE EXCEPTION 'CUSTODY_ACTION_REQUIRED';
  END IF;
  v_now := clock_timestamp();
  IF p_reason = 'store_closed' AND (v_order.pickup_arrived_at IS NULL
    OR v_order.pickup_arrived_at + interval '10 minutes' > v_now) THEN
    RAISE EXCEPTION 'STORE_CANCELLATION_WAIT_REQUIRED';
  END IF;
  -- Lock in order -> driver -> wallet order, consistent with assignment.
  PERFORM 1 FROM public.drivers WHERE user_id = v_actor FOR UPDATE;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_actor::text, 0));
  SELECT COALESCE(sum(tx.held_delta),0)::bigint INTO v_release
  FROM public.driver_wallet_transactions tx
  WHERE tx.driver_id = v_actor AND tx.order_id = p_order_id AND tx.status = 'completed';
  IF v_release > 0 THEN
    INSERT INTO public.driver_wallet_transactions(
      driver_id,order_id,transaction_type,amount,available_delta,held_delta,idempotency_key,completed_at)
    VALUES (v_actor,p_order_id,'cod_release',v_release,v_release,-v_release,
      'order:' || p_order_id::text || ':driver:' || v_actor::text || ':cancel_release',v_now);
  END IF;
  IF p_reason = 'personal' THEN
    v_locked_until := clock_timestamp() + interval '30 minutes';
    UPDATE public.drivers SET acceptance_locked_until = v_locked_until, updated_at = clock_timestamp()
    WHERE user_id = v_actor;
    UPDATE public.orders SET driver_id = NULL, status = 'pending', pickup_arrived_at = NULL,
      offered_driver_id = NULL, offer_expires_at = NULL,
      assignment_expires_at = clock_timestamp() + make_interval(mins=>private.business_number(v_order.business_policy,'assignment_minutes')::integer), assignment_timed_out_at = NULL,
      estimated_pickup_at = NULL, estimated_delivery_at = NULL,
      rejected_by = CASE WHEN COALESCE(rejected_by,'[]'::jsonb) ? v_actor::text
        THEN rejected_by ELSE COALESCE(rejected_by,'[]'::jsonb) || jsonb_build_array(v_actor::text) END,
      status_note = 'Tài xế hủy vì lý do cá nhân. Đang tìm tài xế khác.'
    WHERE id = p_order_id;
    INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
    VALUES (p_order_id,'pending','Tài xế hủy nhận đơn',
      'Lý do cá nhân. Đơn quay về tìm tài xế; tài xế tạm khóa nhận đơn 30 phút.',v_actor);
    PERFORM private.dispatch_next_order_offer(p_order_id,2000);
    INSERT INTO public.notifications(user_id,title,body,type,is_read,order_id)
    VALUES (v_order.customer_id,'Đang tìm tài xế khác',
      'Tài xế đã hủy nhận đơn vì lý do cá nhân. Đơn của bạn đang tìm tài xế khác.',
      'order_update',false,p_order_id);
  ELSE
    UPDATE public.orders SET status = 'cancelled', status_note = 'Quán đóng cửa',
      cancelled_at = clock_timestamp(),
      payment_status = CASE WHEN delivery_fee_payer = 'sender' AND payment_status = 'paid'
        THEN 'refund_required' ELSE payment_status END
    WHERE id = p_order_id RETURNING * INTO v_order;
    IF v_order.payment_status = 'refund_required' THEN
      UPDATE public.order_payment_sessions SET status = 'refund_required', updated_at = clock_timestamp()
      WHERE order_id = p_order_id AND status = 'paid';
    END IF;
    INSERT INTO public.order_status_logs(order_id,status,title,description,logged_by)
    VALUES (p_order_id,'cancelled','Đơn hàng đã hủy',
      'Quán đóng cửa. Tài xế đã xác nhận đến điểm lấy và chờ đủ 10 phút.',v_actor);
    INSERT INTO public.notifications(user_id,title,body,type,is_read,order_id)
    VALUES (v_order.customer_id,'Đơn hàng đã hủy',
      'Quán đóng cửa sau khi tài xế đến điểm lấy và chờ đủ 10 phút.',
      'order_update',false,p_order_id);
  END IF;
  RETURN jsonb_build_object('order_id',p_order_id,
    'new_status', CASE WHEN p_reason = 'personal' THEN 'pending' ELSE 'cancelled' END,
    'locked_until',v_locked_until,'server_now',clock_timestamp());
END;
$function$;
