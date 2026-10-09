-- Synthetic fixtures only. Run with the migration inside BEGIN/ROLLBACK to
-- verify before deployment; no real orders, payments or wallet entries remain.
BEGIN;
DO $test$
DECLARE
  v_customer uuid := gen_random_uuid();
  v_driver uuid := gen_random_uuid();
  v_other_driver uuid := gen_random_uuid();
  v_staff uuid := gen_random_uuid();
  v_order_id uuid;
  v_report_id uuid;
  v_payload jsonb;
  v_session record;
  v_order public.orders%ROWTYPE;
  v_scenario text;
  v_available bigint;
  v_held bigint;
  v_confirmed_at timestamptz;
  v_expected_available bigint;
BEGIN
  INSERT INTO public.users(id,email,full_name,role) VALUES
    (v_customer,v_customer::text||'@deposit-test.invalid','Deposit customer','customer'),
    (v_driver,v_driver::text||'@deposit-test.invalid','Deposit driver','driver'),
    (v_other_driver,v_other_driver::text||'@deposit-test.invalid','Other driver','driver'),
    (v_staff,v_staff::text||'@deposit-test.invalid','Deposit support','support');
  INSERT INTO public.drivers(user_id,is_available,approval_status,current_lat,current_lng,location_updated_at)
    VALUES (v_driver,false,'approved',80,160,clock_timestamp()),
      (v_other_driver,false,'approved',80,160,clock_timestamp());
  INSERT INTO public.driver_wallet_transactions(driver_id,transaction_type,amount,
      available_delta,provider,provider_txn_ref,idempotency_key,completed_at)
    VALUES (v_driver,'vnpay_topup',500000,500000,'vnpay',v_driver::text,
      'deposit-test:'||v_driver::text,clock_timestamp());

  v_payload := jsonb_build_object('pickup_address','Synthetic pickup',
    'pickup_lat',80,'pickup_lng',160,'delivery_address','Synthetic delivery',
    'delivery_lat',80.01,'delivery_lng',160.01,'delivery_fee',25000,
    'delivery_fee_payer','sender','cod_collection_amount',0,'goods_value',120000);

  -- New sessions validate goods value before any payment is taken.
  BEGIN
    PERFORM public.create_customer_order_payment_session(v_customer,
      v_payload||jsonb_build_object('goods_value',0),gen_random_uuid()::text);
    RAISE EXCEPTION 'Accepted missing paid goods value';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'PAID_GOODS_VALUE_REQUIRED' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.create_customer_order_payment_session(v_customer,
      v_payload||jsonb_build_object('goods_value',2000001),gen_random_uuid()::text);
    RAISE EXCEPTION 'Accepted excessive paid goods value';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'PAID_GOODS_VALUE_REQUIRED' THEN RAISE; END IF;
  END;
  SELECT * INTO v_session FROM public.create_customer_order_payment_session(
    v_customer,v_payload,gen_random_uuid()::text);
  ASSERT v_session.amount = 25000, 'Deposit was added to the VNPAY charge';
  SELECT order_payload INTO v_payload FROM public.order_payment_sessions WHERE id=v_session.session_id;
  ASSERT v_payload->>'paid_goods_deposit_version' = '1', 'Missing server policy marker';
  SELECT * INTO v_order FROM private.create_customer_order_from_payload(v_customer,v_payload,'paid',clock_timestamp());
  ASSERT v_order.driver_advance_amount = 120000 AND v_order.receiver_collection_amount = 0
    AND v_order.total_price = 25000 AND v_order.driver_net_earning = 25000,
    'New paid goods snapshot is incorrect';
  -- An already pending legacy invoice completes with its original snapshot.
  SELECT * INTO v_order FROM private.create_customer_order_from_payload(v_customer,
    (v_payload-'paid_goods_deposit_version')||jsonb_build_object('goods_value',0),'paid',clock_timestamp());
  ASSERT v_order.driver_advance_amount = 0, 'Legacy invoice was retroactively charged';

  FOREACH v_scenario IN ARRAY ARRAY['accept','accept_insufficient','delivered','insufficient','proof_failure',
    'foreign_driver','cancel_before_pickup','physical_return','handoff',
    'legacy_prepaid','cod_sender'] LOOP
    BEGIN
      PERFORM set_config('request.jwt.claim.sub','',true);
      v_order_id := gen_random_uuid();
      INSERT INTO public.orders(id,customer_id,driver_id,status,pickup_address,pickup_lat,pickup_lng,
        delivery_address,delivery_lat,delivery_lng,tracking_code,delivery_fee_payer,
        payment_mode,payment_status,paid_at,goods_value,cod_collection_amount,
        driver_advance_amount,driver_net_earning,receiver_collection_amount,delivery_fee,total_price)
      VALUES(v_order_id,v_customer,
        CASE WHEN v_scenario IN ('accept','accept_insufficient') THEN NULL ELSE v_driver END,
        CASE WHEN v_scenario IN ('accept','accept_insufficient') THEN 'pending'::public.order_status
          ELSE 'picking_up'::public.order_status END,'Synthetic pickup',80,160,
        'Synthetic delivery',80.01,160.01,'TEST-DEPOSIT-'||v_order_id::text,
        'sender','prepaid','paid',clock_timestamp(),
        CASE WHEN v_scenario='cod_sender' THEN 0 ELSE 120000 END,
        CASE WHEN v_scenario='cod_sender' THEN 120000 ELSE 0 END,
        CASE WHEN v_scenario='legacy_prepaid' THEN 0 ELSE 120000 END,25000,
        CASE WHEN v_scenario='cod_sender' THEN 120000 ELSE 0 END,25000,
        CASE WHEN v_scenario='cod_sender' THEN 145000 ELSE 25000 END);
      IF v_scenario NOT IN ('accept','accept_insufficient') THEN
        INSERT INTO public.order_delivery_proofs(order_id,driver_id,stage,storage_path,captured_lat,captured_lng)
        VALUES(v_order_id,v_driver,'pickup','synthetic-deposit-proof',
          CASE WHEN v_scenario='proof_failure' THEN 81 ELSE 80 END,160);
      END IF;

      IF v_scenario IN ('accept','accept_insufficient') THEN
        UPDATE public.drivers SET is_available=true WHERE user_id=v_driver;
        UPDATE public.orders SET offered_driver_id=v_driver,
          offer_expires_at=clock_timestamp()+interval '1 minute',
          assignment_expires_at=clock_timestamp()+interval '5 minutes',
          assignment_timed_out_at=NULL WHERE id=v_order_id;
        IF v_scenario='accept_insufficient' THEN
          INSERT INTO public.driver_wallet_transactions(driver_id,transaction_type,amount,available_delta,idempotency_key)
            VALUES(v_driver,'platform_fee_capture',490000,-490000,'deposit-accept-insufficient:'||v_order_id::text);
        END IF;
        PERFORM set_config('request.jwt.claim.sub',v_driver::text,true);
        SET LOCAL ROLE authenticated;
        IF v_scenario='accept_insufficient' THEN
          BEGIN
            PERFORM public.accept_order(v_order_id);
            RAISE EXCEPTION 'Accepted a deposit without wallet balance';
          EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'INSUFFICIENT_WALLET_BALANCE' THEN RAISE; END IF; END;
          ASSERT (SELECT driver_id IS NULL AND status='pending' FROM public.orders WHERE id=v_order_id),
            'Rejected acceptance assigned the order';
        ELSE
          PERFORM public.accept_order(v_order_id);
          ASSERT (SELECT driver_id=v_driver AND status='assigned' FROM public.orders WHERE id=v_order_id),
            'Paid goods acceptance did not assign the order';
        END IF;
        SELECT available_balance,held_balance INTO v_available,v_held FROM public.get_driver_wallet_summary();
        ASSERT v_available=(CASE WHEN v_scenario='accept' THEN 500000 ELSE 10000 END)
          AND v_held=0, 'Acceptance changed the wallet';
        ASSERT NOT EXISTS(SELECT 1 FROM public.driver_wallet_transactions WHERE order_id=v_order_id),
          'Acceptance reserved a deposit before custody';
        RESET ROLE;
      ELSIF v_scenario='cancel_before_pickup' THEN
        PERFORM set_config('request.jwt.claim.sub',v_customer::text,true);
        SET LOCAL ROLE authenticated;
        PERFORM public.cancel_customer_order(v_order_id,v_customer,'Test cancellation');
        RESET ROLE;
        ASSERT NOT EXISTS (SELECT 1 FROM public.driver_wallet_transactions WHERE order_id=v_order_id),
          'Cancellation before custody changed the wallet';
      ELSIF v_scenario='foreign_driver' THEN
        PERFORM set_config('request.jwt.claim.sub',v_other_driver::text,true);
        SET LOCAL ROLE authenticated;
        BEGIN
          PERFORM public.confirm_driver_pickup(v_order_id);
          RAISE EXCEPTION 'Other driver reserved a deposit';
        EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'DRIVER_NOT_ASSIGNED' THEN RAISE; END IF; END;
        ASSERT NOT EXISTS (SELECT 1 FROM public.driver_wallet_transactions WHERE order_id=v_order_id),
          'Other driver can read the assigned wallet';
        RESET ROLE;
      ELSE
        IF v_scenario='insufficient' THEN
          INSERT INTO public.driver_wallet_transactions(driver_id,transaction_type,amount,available_delta,idempotency_key)
            VALUES(v_driver,'platform_fee_capture',490000,-490000,'deposit-insufficient:'||v_order_id::text);
        END IF;
        PERFORM set_config('request.jwt.claim.sub',v_driver::text,true);
        SET LOCAL ROLE authenticated;
        -- Client updates cannot rewrite the deposit or bypass wallet RPCs.
        IF v_scenario='delivered' THEN
          BEGIN
            UPDATE public.orders SET driver_advance_amount=0 WHERE id=v_order_id;
            RAISE EXCEPTION 'Client bypassed deposit snapshot';
          EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'ORDER_FINANCE_SERVER_MANAGED' THEN RAISE; END IF; END;
          BEGIN
            UPDATE public.orders SET status='delivered' WHERE id=v_order_id;
            RAISE EXCEPTION 'Client bypassed deposit settlement';
          EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'GOODS_DEPOSIT_COMMAND_REQUIRED' THEN RAISE; END IF; END;
        END IF;
        IF v_scenario IN ('insufficient','proof_failure') THEN
          BEGIN
            PERFORM public.confirm_driver_pickup(v_order_id);
            RAISE EXCEPTION 'Expected pickup rejection';
          EXCEPTION WHEN OTHERS THEN
            IF SQLERRM <> (CASE WHEN v_scenario='insufficient'
                THEN 'INSUFFICIENT_WALLET_BALANCE_AT_PICKUP' ELSE 'PICKUP_OUTSIDE_GEOFENCE' END)
              THEN RAISE; END IF;
          END;
          ASSERT (SELECT actual_picked_up_at IS NULL FROM public.orders WHERE id=v_order_id),
            'Rejected pickup still committed custody';
          ASSERT NOT EXISTS(SELECT 1 FROM public.driver_wallet_transactions WHERE order_id=v_order_id),
            'Rejected pickup still committed a wallet debit';
        ELSE
          v_confirmed_at := public.confirm_driver_pickup(v_order_id);
          ASSERT public.confirm_driver_pickup(v_order_id) = v_confirmed_at, 'Pickup retry reset custody';
          SELECT available_balance,held_balance INTO v_available,v_held FROM public.get_driver_wallet_summary();
          ASSERT v_available = CASE WHEN v_scenario IN ('legacy_prepaid','cod_sender') THEN 500000 ELSE 380000 END,
            'Incorrect pickup available balance';
          ASSERT v_held = CASE WHEN v_scenario IN ('legacy_prepaid','cod_sender') THEN 0 ELSE 120000 END,
            'Incorrect pickup held balance';
          PERFORM public.advance_driver_order_status(v_order_id);
          SELECT available_balance,held_balance INTO v_available,v_held FROM public.get_driver_wallet_summary();
          ASSERT v_available = CASE WHEN v_scenario='legacy_prepaid' THEN 500000 ELSE 380000 END,
            'Start delivery debited paid goods twice';
          ASSERT v_held = CASE WHEN v_scenario IN ('legacy_prepaid','cod_sender') THEN 0 ELSE 120000 END,
            'Start delivery consumed the deposit';
          RESET ROLE;

          IF v_scenario IN ('physical_return','handoff') THEN
            v_report_id := gen_random_uuid();
            PERFORM set_config('request.jwt.claim.sub',v_staff::text,true);
            INSERT INTO public.risk_reports(id,order_id,reported_by,updated_by,assigned_to,
              category,severity,status,title,description,reporter_role_snapshot)
              VALUES(v_report_id,v_order_id,v_staff,v_staff,v_staff,'cargo_issue','medium',
                'investigating','Synthetic deposit custody','Synthetic deposit regression','support');
            IF v_scenario='physical_return' THEN
              PERFORM set_config('request.jwt.claim.sub','',true);
              UPDATE public.orders SET status='returning' WHERE id=v_order_id;
              INSERT INTO public.order_returns(order_id,risk_report_id,driver_id,status,destination_type,
                destination_address,destination_lat,destination_lng,route_origin_lat,route_origin_lng,
                route_distance_m,route_duration_s,quote_source,reason_code,fee_payer,
                driver_return_earning,approved_by)
              VALUES(v_order_id,v_report_id,v_driver,'returning','sender','Synthetic return',80,160,
                80.01,160.01,1500,300,'osrm','test_return','platform',12500,v_staff);
              UPDATE public.risk_report_interventions SET state='return_required',instruction='Synthetic return'
                WHERE risk_report_id=v_report_id;
              INSERT INTO public.order_delivery_proofs(order_id,driver_id,stage,storage_path,captured_lat,captured_lng)
                VALUES(v_order_id,v_driver,'return','synthetic-deposit-return',80,160);
              PERFORM set_config('request.jwt.claim.sub',v_driver::text,true);
              SET LOCAL ROLE authenticated;
              PERFORM public.confirm_order_return(v_order_id,'Test receiver');
              PERFORM public.confirm_order_return(v_order_id,'Test receiver');
              v_expected_available := 537500;
            ELSE
              UPDATE public.risk_report_interventions SET state='handoff_required',instruction='Synthetic handoff'
                WHERE risk_report_id=v_report_id;
              -- Requesting staff action alone must retain the deposit.
              ASSERT (SELECT sum(held_delta) FROM public.driver_wallet_transactions
                WHERE order_id=v_order_id) = 120000, 'Pending handoff released principal';
              SET LOCAL ROLE authenticated;
              PERFORM public.confirm_risk_custody_resolved(v_report_id,'Physical handoff confirmed');
              RESET ROLE;
              PERFORM set_config('request.jwt.claim.sub',v_driver::text,true);
              SET LOCAL ROLE authenticated;
              v_expected_available := 500000;
            END IF;
          ELSE
            PERFORM set_config('request.jwt.claim.sub','',true);
            INSERT INTO public.order_delivery_proofs(order_id,driver_id,stage,storage_path,captured_lat,captured_lng)
              VALUES(v_order_id,v_driver,'delivery','synthetic-deposit-delivery',80.01,160.01);
            PERFORM set_config('request.jwt.claim.sub',v_driver::text,true);
            SET LOCAL ROLE authenticated;
            PERFORM public.advance_driver_order_status(v_order_id);
            IF v_scenario='delivered' THEN
              PERFORM public.advance_driver_order_status(v_order_id);
            END IF;
            v_expected_available := CASE WHEN v_scenario='cod_sender' THEN 405000 ELSE 525000 END;
          END IF;
          SELECT available_balance,held_balance INTO v_available,v_held FROM public.get_driver_wallet_summary();
          ASSERT v_available = v_expected_available AND v_held = 0, 'Incorrect completion balances';
          IF v_scenario NOT IN ('legacy_prepaid','cod_sender') THEN
            ASSERT (SELECT count(*) FROM public.driver_wallet_transactions WHERE order_id=v_order_id
              AND transaction_type='cod_release' AND metadata->>'purpose'='paid_goods_deposit') = 1,
              'Refund missing or duplicated';
          END IF;
          RESET ROLE;
          IF v_scenario='cod_sender' THEN
            ASSERT (SELECT sum(amount) FROM public.customer_wallet_transactions WHERE order_id=v_order_id) = 120000,
              'Sender-paid COD was not settled';
          ELSE
            ASSERT NOT EXISTS (SELECT 1 FROM public.customer_wallet_transactions WHERE order_id=v_order_id),
              'Deposit was credited to the customer';
          END IF;
        END IF;
        RESET ROLE;
      END IF;
      RAISE EXCEPTION 'Rollback synthetic scenario' USING ERRCODE='Z0001';
    EXCEPTION WHEN SQLSTATE 'Z0001' THEN NULL;
    END;
  END LOOP;
  ASSERT NOT has_function_privilege('authenticated',
    'private.hold_paid_goods_deposit(public.orders,uuid)','execute'),
    'Client can call the internal wallet helper';
  ASSERT NOT has_function_privilege('anon','public.confirm_driver_pickup(uuid)','execute'),
    'Anonymous pickup permission changed';
END;
$test$;
ROLLBACK;
