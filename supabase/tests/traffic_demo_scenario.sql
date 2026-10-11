-- All business test rows are rolled back.
BEGIN;
DO $test$
DECLARE
  customer uuid;
  payload jsonb;
  created public.orders%ROWTYPE;
  rejected boolean := false;
BEGIN
  SELECT id INTO customer FROM public.users WHERE role::text='customer' LIMIT 1;
  IF customer IS NULL THEN RAISE EXCEPTION 'A customer fixture is required'; END IF;
  payload := jsonb_build_object('pickup_address','Test pickup','pickup_lat',10.7849,
    'pickup_lng',106.6684,'delivery_address','Test delivery','delivery_lat',10.793838,
    'delivery_lng',106.651842,'delivery_fee',33000,'goods_value',0,
    'cod_collection_amount',0,'delivery_fee_payer','recipient','item_weight_kg',1);
  SELECT * INTO created FROM private.create_customer_order_from_payload(
    customer,payload||'{"traffic_demo_key":"peak"}'::jsonb,'not_required');
  IF created.traffic_demo_key <> 'peak' THEN RAISE EXCEPTION 'Peak was not persisted'; END IF;
  SELECT * INTO created FROM private.create_customer_order_from_payload(
    customer,payload||'{"traffic_demo_key":"off_peak"}'::jsonb,'not_required');
  IF created.traffic_demo_key <> 'off_peak' THEN RAISE EXCEPTION 'Off-peak was not persisted'; END IF;
  SELECT * INTO created FROM private.create_customer_order_from_payload(customer,payload,'not_required');
  IF created.traffic_demo_key IS NOT NULL THEN RAISE EXCEPTION 'Ordinary order opted into demo'; END IF;
  BEGIN
    PERFORM private.create_customer_order_from_payload(
      customer,payload||'{"traffic_demo_key":"other"}'::jsonb,'not_required');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'TRAFFIC_DEMO_INVALID' THEN RAISE; END IF;
    rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'Invalid demo accepted'; END IF;
END;
$test$;
SELECT 'traffic demo scenario persistence and validation passed' AS result;
ROLLBACK;
