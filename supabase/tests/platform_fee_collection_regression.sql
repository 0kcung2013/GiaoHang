-- Synthetic fixtures and all money/configuration changes are rolled back.
BEGIN;
UPDATE public.system_settings SET value=(value||'{"platform_fee_version":1}'::jsonb)
 ||jsonb_build_object('values',(value->'values')||'{"customer_individual_fee_bps":500,"customer_business_fee_bps":300,"driver_platform_fee_bps":1000}'::jsonb)
WHERE key='business_settings';
DO $test$
DECLARE c uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); staff uuid:=gen_random_uuid(); seed uuid:=gen_random_uuid();
 o public.orders; again public.orders; p jsonb; session_row record; activated record; rev bigint;
 request_id uuid:=gen_random_uuid(); scenario text; pickup_code text; report_id uuid; balance bigint;
BEGIN
 INSERT INTO public.users(id,email,full_name,role,customer_type) VALUES
 (c,c||'@fee-test.invalid','Fee customer','customer','individual'),
 (d,d||'@fee-test.invalid','Fee driver','driver',NULL),
 (staff,staff||'@fee-test.invalid','Fee support','support',NULL);
 INSERT INTO public.drivers(user_id,is_available,approval_status,current_lat,current_lng,location_updated_at)
 VALUES(d,false,'approved',80,160,clock_timestamp());
 INSERT INTO public.orders(id,customer_id,status,pickup_address,pickup_lat,pickup_lng,delivery_address,delivery_lat,delivery_lng,delivery_fee,total_price,business_policy)
 VALUES(seed,c,'cancelled','Seed',80,160,'Seed delivery',80.01,160.01,18000,18000,private.legacy_business_settings());
 INSERT INTO public.customer_wallet_transactions(customer_id,order_id,transaction_type,amount,available_delta,idempotency_key)
 VALUES(c,seed,'delivery_credit',100000,100000,seed::text);
 INSERT INTO public.driver_wallet_transactions(driver_id,transaction_type,amount,available_delta,provider,provider_txn_ref,idempotency_key,completed_at)
 VALUES(d,'vnpay_topup',200000,200000,'vnpay',d::text,d::text,clock_timestamp());
 rev:=(private.current_business_settings()->>'revision')::bigint;
 p:=jsonb_build_object('pickup_address','Pickup','pickup_lat',80,'pickup_lng',160,'delivery_address','Delivery','delivery_lat',80.01,'delivery_lng',160.01,
   'delivery_fee',18000,'goods_value',50000,'cod_collection_amount',0,'delivery_fee_payer','sender',
   'quoted_distance_m',2000,'settings_revision',rev,'quoted_customer_fee',900);
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 BEGIN
   PERFORM public.create_customer_order_with_wallet(p||'{"quoted_customer_fee":0}',gen_random_uuid());
   RAISE EXCEPTION 'Accepted forged fee quote';
 EXCEPTION WHEN invalid_parameter_value THEN ASSERT SQLERRM='SETTINGS_QUOTE_FEE_MISMATCH'; END;
 SELECT * INTO o FROM public.create_customer_order_with_wallet(p,request_id);
 SELECT * INTO again FROM public.create_customer_order_with_wallet(p,request_id);
 ASSERT o.id=again.id,'Duplicate wallet order';
 ASSERT o.total_price=18900 AND o.customer_platform_fee_amount=900 AND o.platform_fee_amount=1800
   AND o.driver_net_earning=16200 AND o.receiver_collection_amount=0,'Wallet snapshot mismatch';
 ASSERT (SELECT sum(available_delta) FROM public.customer_wallet_transactions WHERE customer_id=c)=81100,'Wallet not charged';
 SET LOCAL ROLE authenticated;
 BEGIN
   INSERT INTO public.orders(customer_id,status,pickup_address,pickup_lat,pickup_lng,delivery_address,delivery_lat,delivery_lng,
     delivery_fee,total_price,business_policy)
   VALUES(c,'pending','Bypass pickup',80,160,'Bypass delivery',80.01,160.01,18000,18000,
     '{"revision":-1,"values":{"assignment_minutes":15}}'::jsonb);
   RAISE EXCEPTION 'Client bypassed fees with a legacy policy';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
   UPDATE public.orders SET customer_platform_fee_amount=0 WHERE id=o.id;
   RAISE EXCEPTION 'Customer rewrote fee snapshot';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 RESET ROLE;
 PERFORM public.cancel_customer_order(o.id,c,'Synthetic cancel');
 UPDATE public.orders SET status_note='Retry same cancellation' WHERE id=o.id;
 ASSERT (SELECT sum(available_delta) FROM public.customer_wallet_transactions WHERE customer_id=c)=100000,'Wallet full refund mismatch';
 ASSERT (SELECT count(*) FROM public.customer_wallet_transactions WHERE order_id=o.id AND transaction_type='delivery_fee_refund')=1,'Duplicate full refund';
 FOREACH scenario IN ARRAY ARRAY['wallet_timeout_retry','vnpay_cancel','vnpay_timeout_retry','vnpay_late','vnpay_expired','session_snapshot',
   'cash_delivered','prepaid_delivered','cash_returned','prepaid_returned','cash_full_fee','cash_debt'] LOOP
   BEGIN
     PERFORM set_config('request.jwt.claim.sub',c::text,true);
     IF scenario IN ('vnpay_cancel','vnpay_timeout_retry','vnpay_late','vnpay_expired','session_snapshot') THEN
       SELECT * INTO session_row FROM public.create_customer_order_payment_session(c,p,gen_random_uuid()::text);
       ASSERT session_row.amount=18900,'VNPAY amount omits fee';
       IF scenario IN ('vnpay_late','vnpay_expired') THEN
         UPDATE public.order_payment_sessions SET expires_at=clock_timestamp()-interval '1 minute',
           status=CASE WHEN scenario='vnpay_expired' THEN 'expired' ELSE 'pending' END WHERE id=session_row.session_id;
         SELECT * INTO activated FROM public.complete_customer_order_payment(session_row.txn_ref,'synthetic',true,'00');
         PERFORM public.complete_customer_order_payment(session_row.txn_ref,'synthetic',true,'00');
         ASSERT activated.order_id IS NULL AND activated.status='refunded','Late receipt activated an order';
         ASSERT (SELECT count(*) FROM public.customer_wallet_transactions WHERE payment_session_id=session_row.session_id)=1,'Late receipt refunded twice';
         ASSERT (SELECT sum(available_delta) FROM public.customer_wallet_transactions WHERE customer_id=c)=118900,'Late receipt lost money';
       ELSE
         IF scenario='session_snapshot' THEN
           UPDATE public.users SET customer_type='business',business_name='Changed shop',business_address='123 Changed address' WHERE id=c;
           UPDATE public.system_settings SET value=value||jsonb_build_object('values',(value->'values')||'{"customer_individual_fee_bps":9000,"driver_platform_fee_bps":9000}') WHERE key='business_settings';
         END IF;
         SELECT * INTO activated FROM public.complete_customer_order_payment(session_row.txn_ref,'synthetic',true,'00');
         SELECT * INTO o FROM public.orders WHERE id=activated.order_id;
         ASSERT o.customer_platform_fee_amount=900 AND o.platform_fee_amount=1800 AND o.driver_net_earning=16200,'Pending session fee changed';
         PERFORM public.complete_customer_order_payment(session_row.txn_ref,'synthetic',true,'00');
         IF scenario='vnpay_timeout_retry' THEN
           UPDATE public.orders SET assignment_timed_out_at=clock_timestamp(),assignment_expires_at=clock_timestamp()-interval '1 minute' WHERE id=o.id;
           PERFORM public.retry_order_assignment(o.id);
           SELECT * INTO o FROM public.orders WHERE id=o.id;
           ASSERT o.payment_method='wallet' AND o.payment_status='paid','VNPAY retry did not spend refunded wallet credit';
           ASSERT (SELECT sum(available_delta) FROM public.customer_wallet_transactions WHERE customer_id=c)=100000,'VNPAY retry double charge';
         ELSE
           PERFORM public.cancel_customer_order(o.id,c,'VNPAY cancel');
           ASSERT (SELECT payment_status FROM public.orders WHERE id=o.id)='refunded','VNPAY cancellation not refunded';
           ASSERT (SELECT sum(available_delta) FROM public.customer_wallet_transactions WHERE customer_id=c)=118900,'VNPAY cancellation refund mismatch';
         END IF;
       END IF;
     ELSE
       IF scenario IN ('cash_delivered','cash_returned','cash_full_fee','cash_debt') THEN
         IF scenario='cash_full_fee' THEN
           UPDATE public.system_settings SET value=value||jsonb_build_object('values',(value->'values')||'{"customer_individual_fee_bps":10000,"driver_platform_fee_bps":10000}') WHERE key='business_settings';
         END IF;
         SELECT * INTO o FROM private.create_customer_order_from_payload(c,p||jsonb_build_object('delivery_fee_payer','recipient',
           'cod_collection_amount',20000,'quoted_customer_fee',CASE WHEN scenario='cash_full_fee' THEN 18000 ELSE 900 END),'not_required',NULL);
       ELSE
         SELECT * INTO o FROM public.create_customer_order_with_wallet(p,gen_random_uuid());
       END IF;
       IF scenario='wallet_timeout_retry' THEN
         UPDATE public.orders SET assignment_timed_out_at=clock_timestamp(),assignment_expires_at=clock_timestamp()-interval '1 minute' WHERE id=o.id;
         PERFORM public.retry_order_assignment(o.id);
         ASSERT (SELECT sum(available_delta) FROM public.customer_wallet_transactions WHERE customer_id=c)=81100,'Wallet retry fee mismatch';
         UPDATE public.orders SET assignment_timed_out_at=clock_timestamp(),assignment_expires_at=clock_timestamp()-interval '1 minute' WHERE id=o.id;
         ASSERT (SELECT sum(available_delta) FROM public.customer_wallet_transactions WHERE customer_id=c)=100000,'Second timeout kept fee';
       ELSE
         UPDATE public.orders SET driver_id=d,status='picking_up' WHERE id=o.id;
         INSERT INTO public.order_delivery_proofs(order_id,driver_id,stage,storage_path,captured_lat,captured_lng)
         VALUES(o.id,d,'pickup','synthetic-fee-pickup',80,160);
         pickup_code:=public.get_customer_pickup_code(o.id)->>'code';
         PERFORM set_config('request.jwt.claim.sub',d::text,true);
         PERFORM public.confirm_driver_pickup_code(o.id,pickup_code);
         IF scenario IN ('cash_returned','prepaid_returned') THEN
           report_id:=gen_random_uuid();
           PERFORM set_config('request.jwt.claim.sub',staff::text,true);
           INSERT INTO public.risk_reports(id,order_id,reported_by,updated_by,assigned_to,category,severity,status,title,description,reporter_role_snapshot)
           VALUES(report_id,o.id,staff,staff,staff,'cargo_issue','medium','investigating','Fee return','Synthetic regression return','support');
           PERFORM set_config('request.jwt.claim.sub','',true);
           UPDATE public.orders SET status='returning' WHERE id=o.id;
           INSERT INTO public.order_returns(order_id,risk_report_id,driver_id,status,destination_type,destination_address,destination_lat,destination_lng,
             route_origin_lat,route_origin_lng,route_distance_m,route_duration_s,quote_source,reason_code,fee_payer,driver_return_earning,approved_by)
           VALUES(o.id,report_id,d,'returning','sender','Return',80,160,80.01,160.01,1500,300,'osrm','test','platform',9000,staff);
           UPDATE public.risk_report_interventions SET state='return_required',instruction='Synthetic return' WHERE risk_report_id=report_id;
           INSERT INTO public.order_delivery_proofs(order_id,driver_id,stage,storage_path,captured_lat,captured_lng)
           VALUES(o.id,d,'return','synthetic-fee-return',80,160);
           PERFORM set_config('request.jwt.claim.sub',d::text,true);
           PERFORM public.confirm_order_return(o.id,'Receiver');
           PERFORM public.confirm_order_return(o.id,'Receiver');
           ASSERT (SELECT sum(available_delta) FROM public.driver_wallet_transactions WHERE driver_id=d)=225200,'Return net earning mismatch';
           ASSERT (SELECT sum(available_delta) FROM public.customer_wallet_transactions WHERE customer_id=c)=
             CASE WHEN scenario='prepaid_returned' THEN 82000 ELSE 100000 END,'Return customer fee not waived/refunded';
         ELSE
           IF scenario='cash_debt' THEN
             INSERT INTO public.driver_wallet_transactions(driver_id,order_id,transaction_type,amount,available_delta,idempotency_key,completed_at)
             VALUES(d,o.id,'platform_fee_capture',180000,-180000,'synthetic-drain:'||o.id::text,clock_timestamp());
           END IF;
           INSERT INTO public.order_delivery_proofs(order_id,driver_id,stage,storage_path,captured_lat,captured_lng)
           VALUES(o.id,d,'delivery','synthetic-fee-delivery',80.01,160.01);
           PERFORM public.advance_driver_order_status(o.id);
           PERFORM public.advance_driver_order_status(o.id);
           SELECT sum(available_delta) INTO balance FROM public.driver_wallet_transactions WHERE driver_id=d;
           ASSERT balance=CASE scenario WHEN 'cash_delivered' THEN 177300 WHEN 'cash_full_fee' THEN 144000
             WHEN 'cash_debt' THEN -2700 ELSE 216200 END,'Driver wallet/net mismatch';
           ASSERT (SELECT today_income FROM public.get_driver_wallet_summary())=CASE WHEN scenario='cash_full_fee' THEN 0 ELSE 16200 END,'Gross reported as net income';
           ASSERT (SELECT count(*) FROM public.driver_wallet_transactions WHERE order_id=o.id AND transaction_type='customer_platform_fee_capture')=
             CASE WHEN scenario='prepaid_delivered' THEN 0 ELSE 1 END,'Customer cash fee duplicated or withheld twice';
           IF scenario='cash_debt' THEN
             SELECT * INTO again FROM private.create_customer_order_from_payload(c,
               p||'{"delivery_fee_payer":"recipient","cod_collection_amount":0,"goods_value":0}', 'not_required',NULL);
             UPDATE public.drivers SET is_available=true WHERE user_id=d;
             UPDATE public.orders SET offered_driver_id=d,offer_expires_at=clock_timestamp()+interval '30 seconds' WHERE id=again.id;
             BEGIN
               PERFORM public.accept_order(again.id);
               RAISE EXCEPTION 'Debt accepted a zero-COD order';
             EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM='INSUFFICIENT_WALLET_BALANCE'; END;
           END IF;
         END IF;
       END IF;
     END IF;
     RAISE EXCEPTION 'ROLLBACK_SCENARIO' USING ERRCODE='PZ001';
   EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL;
   END;
 END LOOP;
 -- Business classification selects its own rate; earlier orders remain fixed.
 UPDATE public.users SET customer_type='business',business_name='Shop',business_address='123 Business address' WHERE id=c;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 SELECT * INTO o FROM public.create_customer_order_with_wallet(p||'{"quoted_customer_fee":540}',gen_random_uuid());
 ASSERT o.customer_platform_fee_rate_bps=300 AND o.customer_platform_fee_amount=540,'Business rate ignored';
 ASSERT NOT has_function_privilege('authenticated','private.settle_platform_fees()','EXECUTE'),'Settlement helper exposed';
 ASSERT NOT has_function_privilege('anon','public.complete_customer_order_payment(text,text,boolean,text)','EXECUTE'),'Payment callback exposed';
END;
$test$;
SELECT 'platform_fee_collection_passed' AS result;
ROLLBACK;
