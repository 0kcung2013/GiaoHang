-- Declared kg travels through COD and paid-order creation. All fixtures roll back.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT set_config('giaohang.road_dispatch_requested','yes',true);
SELECT set_config('request.jwt.claims','{}',true);
DO $$
DECLARE
  c uuid;
  base jsonb;
  payload jsonb;
  created public.orders%ROWTYPE;
  created_id uuid;
  invalid text;
  session_id uuid;
  txn_ref text;
BEGIN
  SELECT id INTO STRICT c FROM public.users WHERE role='customer' LIMIT 1;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated')::text,true);
  base:=jsonb_build_object(
    'pickup_address','Cargo test pickup','pickup_lat',10.78,'pickup_lng',106.68,
    'delivery_address','Cargo test delivery','delivery_lat',10.8,'delivery_lng',106.7,
    'item_name','Weight regression package','item_category','other',
    'recipient_name','Weight test recipient','recipient_phone','0900000000',
    'delivery_fee',25000,'goods_value',200000,'cod_collection_amount',150000,
    'delivery_fee_payer','recipient','item_weight_kg',2.75
  );
  SELECT order_id INTO created_id FROM public.create_customer_order_v2(base);
  SELECT * INTO created FROM public.orders WHERE id=created_id;
  ASSERT created.item_weight_kg=2.75, 'COD RPC dropped declared weight';
  ASSERT created.goods_value=200000 AND created.cod_collection_amount=150000
    AND created.receiver_collection_amount=175000, 'Weight changed the payment snapshot';

  FOREACH invalid IN ARRAY ARRAY['0','-1','NaN','Infinity','abc','1.2345'] LOOP
    payload:=base||jsonb_build_object('item_weight_kg',invalid);
    BEGIN
      PERFORM public.create_customer_order_v2(payload);
      RAISE EXCEPTION 'Accepted invalid kg: %',invalid;
    EXCEPTION WHEN check_violation THEN
      IF SQLERRM<>'ITEM_WEIGHT_INVALID' THEN RAISE; END IF;
    END;
    BEGIN
      UPDATE public.orders SET item_weight_kg=invalid::numeric WHERE id=created_id;
      RAISE EXCEPTION 'Accepted invalid kg through direct write: %',invalid;
    EXCEPTION WHEN check_violation OR invalid_text_representation THEN NULL;
    END;
  END LOOP;
  SELECT order_id INTO created_id FROM public.create_customer_order_v2(base-'item_weight_kg');
  ASSERT (SELECT item_weight_kg IS NULL FROM public.orders WHERE id=created_id),
    'Old clients were assigned a fabricated weight';

  -- Payment sessions preserve the payload and reject invalid weight before payment.
  payload:=base||jsonb_build_object('delivery_fee_payer','sender','cod_collection_amount',0);
  txn_ref:='TEST-WEIGHT-'||gen_random_uuid();
  SELECT p.session_id INTO session_id FROM public.create_customer_order_payment_session(c,payload,txn_ref) p;
  ASSERT (SELECT (order_payload->>'item_weight_kg')::numeric=2.75
    FROM public.order_payment_sessions WHERE id=session_id), 'Payment session dropped kg';
  BEGIN
    PERFORM public.create_customer_order_payment_session(c,
      payload||jsonb_build_object('item_weight_kg',-1),'TEST-WEIGHT-'||gen_random_uuid());
    RAISE EXCEPTION 'Opened payment session with invalid kg';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'ITEM_WEIGHT_INVALID' THEN RAISE; END IF;
  END;
  SELECT order_payload INTO payload FROM public.order_payment_sessions WHERE id=session_id;
  created:=private.create_customer_order_from_payload(c,payload,'paid',clock_timestamp());
  ASSERT created.item_weight_kg=2.75 AND created.payment_status='paid',
    'Paid order creation dropped kg';
  ASSERT created.driver_advance_amount=200000, 'Weight changed paid-goods deposit policy';
END;
$$;
SELECT 'cargo weight regression passed; fixtures rolled back' AS result;
ROLLBACK;
