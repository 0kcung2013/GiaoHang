-- Synthetic fixtures only; always execute in a transaction ending in ROLLBACK.
BEGIN;
DO $test$
DECLARE
  v_customer uuid := gen_random_uuid();
  v_driver uuid := gen_random_uuid();
  v_staff uuid := gen_random_uuid();
  v_seed_order uuid := gen_random_uuid();
  v_request uuid := gen_random_uuid();
  v_order public.orders%ROWTYPE;
  v_retry public.orders%ROWTYPE;
  v_payload jsonb;
  v_balance bigint;
  v_received bigint;
  v_count bigint;
  v_report uuid;
  v_scenario text;
BEGIN
  INSERT INTO public.users(id, email, full_name, role) VALUES
    (v_customer, v_customer::text || '@wallet-test.invalid', 'Wallet test customer', 'customer'),
    (v_driver, v_driver::text || '@wallet-test.invalid', 'Wallet test driver', 'driver'),
    (v_staff, v_staff::text || '@wallet-test.invalid', 'Wallet test support', 'support');
  INSERT INTO public.drivers(user_id, is_available, approval_status, current_lat, current_lng, location_updated_at)
    VALUES(v_driver, false, 'approved', 80, 160, clock_timestamp());
  INSERT INTO public.orders(id, customer_id, status, pickup_address, pickup_lat, pickup_lng,
    delivery_address, delivery_lat, delivery_lng, total_price, delivery_fee)
    VALUES(v_seed_order, v_customer, 'cancelled', 'Synthetic seed', 80, 160,
      'Synthetic seed delivery', 80.01, 160.01, 18000, 18000);
  INSERT INTO public.customer_wallet_transactions(customer_id, order_id, transaction_type,
    amount, available_delta, idempotency_key)
    VALUES(v_customer, v_seed_order, 'delivery_credit', 100000, 100000, 'wallet-test:' || v_customer::text);
  INSERT INTO public.driver_wallet_transactions(driver_id, transaction_type, amount,
    available_delta, provider, provider_txn_ref, idempotency_key, completed_at)
    VALUES(v_driver, 'vnpay_topup', 200000, 200000, 'vnpay', v_driver::text,
      'wallet-test:' || v_driver::text, clock_timestamp());
  v_payload := jsonb_build_object('pickup_address', 'Synthetic pickup', 'pickup_lat', 80,
    'pickup_lng', 160, 'delivery_address', 'Synthetic delivery', 'delivery_lat', 80.01,
    'delivery_lng', 160.01, 'delivery_fee', 18000, 'goods_value', 50000,
    'cod_collection_amount', 0, 'delivery_fee_payer', 'sender');
  PERFORM set_config('request.jwt.claim.sub', v_customer::text, true);
  SET LOCAL ROLE authenticated;
  SELECT * INTO v_order FROM public.create_customer_order_with_wallet(v_payload, v_request);
  SELECT * INTO v_retry FROM public.create_customer_order_with_wallet(v_payload, v_request);
  ASSERT v_order.id = v_retry.id AND v_order.payment_method = 'wallet' AND v_order.payment_status = 'paid',
    'Wallet retry created another order or did not activate payment';
  ASSERT v_order.driver_advance_amount = 50000 AND v_order.receiver_collection_amount = 0
    AND v_order.delivery_fee = 18000 AND v_order.total_price = 18000,
    'Wallet charge changed goods deposit or recipient collection';
  SELECT available_balance, total_received INTO v_balance, v_received FROM public.get_customer_wallet_summary();
  ASSERT v_balance = 82000 AND v_received = 100000, 'Incorrect customer wallet debit';
  ASSERT (SELECT count(*) FROM public.customer_wallet_transactions WHERE order_id = v_order.id) = 1,
    'Retry duplicated the customer debit';
  BEGIN
    PERFORM public.create_customer_order_with_wallet(v_payload || '{"goods_value":60000}', v_request);
    RAISE EXCEPTION 'Accepted different payload for existing request';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'WALLET_REQUEST_PAYLOAD_MISMATCH' THEN RAISE; END IF; END;
  BEGIN
    UPDATE public.orders SET payment_method = 'vnpay' WHERE id = v_order.id;
    RAISE EXCEPTION 'Client relabelled wallet as VNPAY';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'ORDER_PAYMENT_FIELDS_SERVER_MANAGED' THEN RAISE; END IF; END;
  BEGIN
    UPDATE public.orders SET customer_id = v_staff WHERE id = v_order.id;
    RAISE EXCEPTION 'Client reassigned customer wallet';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'WALLET_PAYMENT_COMMAND_REQUIRED' AND SQLSTATE <> '42501' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.create_customer_order_with_wallet(v_payload || '{"delivery_fee":90000}', gen_random_uuid());
    RAISE EXCEPTION 'Insufficient wallet created an order';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'CUSTOMER_WALLET_INSUFFICIENT_BALANCE' THEN RAISE; END IF; END;
  BEGIN
    PERFORM public.create_customer_order_with_wallet(v_payload || '{"goods_value":0}', gen_random_uuid());
    RAISE EXCEPTION 'Missing goods value created an order';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'PAID_GOODS_VALUE_REQUIRED' THEN RAISE; END IF; END;
  ASSERT (SELECT count(*) FROM public.orders WHERE customer_id = v_customer) = 2,
    'A failed wallet transaction left an order';
  PERFORM public.cancel_customer_order(v_order.id, v_customer, 'Synthetic cancel');
  RESET ROLE;
  UPDATE public.orders SET status_note = 'Retry after cancellation' WHERE id = v_order.id;
  ASSERT (SELECT payment_status FROM public.orders WHERE id = v_order.id) = 'refunded', 'Cancelled payment not refunded';
  ASSERT (SELECT count(*) FROM public.customer_wallet_transactions WHERE order_id = v_order.id
    AND transaction_type = 'delivery_fee_refund') = 1, 'Cancelled payment refunded twice';
  PERFORM set_config('request.jwt.claim.sub', v_customer::text, true);
  SET LOCAL ROLE authenticated;
  SELECT available_balance, total_received INTO v_balance, v_received FROM public.get_customer_wallet_summary();
  ASSERT v_balance = 100000 AND v_received = 100000, 'Refund inflated COD receipts';
  RESET ROLE;

  -- Each independent scenario rolls back its money and workflow changes.
  FOREACH v_scenario IN ARRAY ARRAY['timeout_retry', 'driver_reassignment', 'delivered', 'returned', 'legacy_vnpay'] LOOP
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', v_customer::text, true);
      SET LOCAL ROLE authenticated;
      SELECT * INTO v_order FROM public.create_customer_order_with_wallet(v_payload, gen_random_uuid());
      RESET ROLE;
      IF v_scenario = 'timeout_retry' THEN
        UPDATE public.orders SET assignment_timed_out_at = clock_timestamp(),
          assignment_expires_at = clock_timestamp() - interval '1 minute' WHERE id = v_order.id;
        ASSERT (SELECT payment_status FROM public.orders WHERE id = v_order.id) = 'refunded', 'Timeout kept the fee';
        SET LOCAL ROLE authenticated;
        PERFORM public.retry_order_assignment(v_order.id);
        RESET ROLE;
        ASSERT (SELECT payment_status FROM public.orders WHERE id = v_order.id) = 'paid', 'Retry did not pay the fee';
        ASSERT (SELECT sum(available_delta) FROM public.customer_wallet_transactions WHERE order_id = v_order.id) = -18000,
          'Retry charged two outstanding fees';
        UPDATE public.orders SET assignment_timed_out_at = clock_timestamp(),
          assignment_expires_at = clock_timestamp() - interval '1 minute' WHERE id = v_order.id;
        INSERT INTO public.customer_wallet_transactions(customer_id, order_id, transaction_type,
          amount, available_delta, idempotency_key) VALUES(v_customer, v_seed_order, 'adjustment_debit',
          99000, -99000, 'wallet-test-drain:' || v_order.id::text);
        SET LOCAL ROLE authenticated;
        BEGIN
          PERFORM public.retry_order_assignment(v_order.id);
          RAISE EXCEPTION 'Retry accepted insufficient balance';
        EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'CUSTOMER_WALLET_INSUFFICIENT_BALANCE' THEN RAISE; END IF; END;
        RESET ROLE;
        ASSERT (SELECT assignment_timed_out_at IS NOT NULL AND payment_status = 'refunded'
          FROM public.orders WHERE id = v_order.id), 'Failed retry reopened dispatch';
      ELSIF v_scenario = 'driver_reassignment' THEN
        UPDATE public.orders SET driver_id = v_driver, status = 'assigned' WHERE id = v_order.id;
        UPDATE public.orders SET driver_id = NULL, status = 'pending',
          assignment_expires_at = clock_timestamp() + interval '15 minutes' WHERE id = v_order.id;
        ASSERT (SELECT count(*) FROM public.customer_wallet_transactions WHERE order_id = v_order.id) = 1,
          'Reassignment released or recharged the fee';
      ELSIF v_scenario = 'legacy_vnpay' THEN
        SELECT * INTO v_retry FROM private.create_customer_order_from_payload(v_customer,
          v_payload || '{"paid_goods_deposit_version":1}', 'paid', clock_timestamp());
        ASSERT v_retry.payment_method = 'vnpay', 'Existing VNPAY contract changed';
        SET LOCAL ROLE authenticated;
        PERFORM public.cancel_customer_order(v_retry.id, v_customer);
        RESET ROLE;
        ASSERT (SELECT payment_status FROM public.orders WHERE id = v_retry.id) = 'refund_required',
          'VNPAY was incorrectly refunded into the wallet';
        ASSERT NOT EXISTS(SELECT 1 FROM public.customer_wallet_transactions WHERE order_id = v_retry.id),
          'Legacy VNPAY wrote a wallet payment';
      ELSE
        UPDATE public.orders SET driver_id = v_driver, status = 'picking_up' WHERE id = v_order.id;
        INSERT INTO public.order_delivery_proofs(order_id, driver_id, stage, storage_path, captured_lat, captured_lng)
          VALUES(v_order.id, v_driver, 'pickup', 'synthetic-wallet-pickup', 80, 160);
        PERFORM set_config('request.jwt.claim.sub', v_driver::text, true);
        SET LOCAL ROLE authenticated;
        PERFORM public.confirm_driver_pickup(v_order.id);
        PERFORM public.advance_driver_order_status(v_order.id);
        RESET ROLE;
        IF v_scenario = 'delivered' THEN
          INSERT INTO public.order_delivery_proofs(order_id, driver_id, stage, storage_path, captured_lat, captured_lng)
            VALUES(v_order.id, v_driver, 'delivery', 'synthetic-wallet-delivery', 80.01, 160.01);
          SET LOCAL ROLE authenticated;
          PERFORM public.advance_driver_order_status(v_order.id);
          PERFORM public.advance_driver_order_status(v_order.id);
          RESET ROLE;
          ASSERT (SELECT sum(available_delta) FROM public.driver_wallet_transactions WHERE driver_id = v_driver) = 218000,
            'Delivery paid the driver or returned the deposit incorrectly';
        ELSE
          v_report := gen_random_uuid();
          PERFORM set_config('request.jwt.claim.sub', v_staff::text, true);
          INSERT INTO public.risk_reports(id, order_id, reported_by, updated_by, assigned_to,
            category, severity, status, title, description, reporter_role_snapshot)
            VALUES(v_report, v_order.id, v_staff, v_staff, v_staff, 'cargo_issue', 'medium',
              'investigating', 'Synthetic wallet return', 'Synthetic regression', 'support');
          PERFORM set_config('request.jwt.claim.sub', '', true);
          UPDATE public.orders SET status = 'returning' WHERE id = v_order.id;
          INSERT INTO public.order_returns(order_id, risk_report_id, driver_id, status, destination_type,
            destination_address, destination_lat, destination_lng, route_origin_lat, route_origin_lng,
            route_distance_m, route_duration_s, quote_source, reason_code, fee_payer, driver_return_earning, approved_by)
            VALUES(v_order.id, v_report, v_driver, 'returning', 'sender', 'Synthetic return', 80, 160,
              80.01, 160.01, 1500, 300, 'osrm', 'test_return', 'platform', 9000, v_staff);
          UPDATE public.risk_report_interventions SET state = 'return_required', instruction = 'Synthetic return'
            WHERE risk_report_id = v_report;
          INSERT INTO public.order_delivery_proofs(order_id, driver_id, stage, storage_path, captured_lat, captured_lng)
            VALUES(v_order.id, v_driver, 'return', 'synthetic-wallet-return', 80, 160);
          PERFORM set_config('request.jwt.claim.sub', v_driver::text, true);
          SET LOCAL ROLE authenticated;
          PERFORM public.confirm_order_return(v_order.id, 'Synthetic receiver');
          PERFORM public.confirm_order_return(v_order.id, 'Synthetic receiver');
          RESET ROLE;
          ASSERT (SELECT sum(available_delta) FROM public.driver_wallet_transactions WHERE driver_id = v_driver) = 227000,
            'Return changed original fee, platform return fee or goods deposit';
        END IF;
        ASSERT (SELECT sum(available_delta) FROM public.customer_wallet_transactions WHERE order_id = v_order.id) = -18000,
          'Settlement charged the customer again';
        ASSERT (SELECT metadata->>'payment_state' FROM public.customer_wallet_transactions
          WHERE order_id = v_order.id AND transaction_type = 'delivery_fee_payment') = 'settled',
          'Settlement did not close the reserved fee';
      END IF;
      RAISE EXCEPTION 'ROLLBACK_SCENARIO' USING ERRCODE = 'PZ001';
    EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL;
    END;
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub', v_driver::text, true);
  SET LOCAL ROLE authenticated;
  BEGIN
    PERFORM public.create_customer_order_with_wallet(v_payload, gen_random_uuid());
    RAISE EXCEPTION 'Driver spent a customer wallet';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'CUSTOMER_ROLE_REQUIRED' THEN RAISE; END IF; END;
  RESET ROLE;
  ASSERT NOT has_function_privilege('anon', 'public.create_customer_order_with_wallet(jsonb,uuid)', 'EXECUTE'),
    'Anonymous caller has wallet debit permission';
END;
$test$;
ROLLBACK;
