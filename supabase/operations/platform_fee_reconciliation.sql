-- Read-only checks for new fee snapshots. Each discrepancy query must be empty.
-- 1. Snapshot arithmetic; rounding to the nearest VND, independently from COD.
SELECT id,tracking_code,'snapshot_mismatch' AS issue FROM public.orders
WHERE business_policy->>'platform_fee_version'='1' AND (
 customer_platform_fee_amount<>round(delivery_fee*customer_platform_fee_rate_bps/10000.0)::bigint OR
 platform_fee_amount<>round(delivery_fee*platform_fee_rate_bps/10000.0)::bigint OR
 driver_net_earning<>round(delivery_fee)::bigint-platform_fee_amount OR
 total_price<>delivery_fee+cod_collection_amount+customer_platform_fee_amount OR
 receiver_collection_amount<>cod_collection_amount+CASE WHEN delivery_fee_payer='recipient'
   THEN round(delivery_fee)::bigint+customer_platform_fee_amount ELSE 0 END);

-- 2. Actual cash fee remittances: the driver collected gross money physically.
SELECT o.id,o.tracking_code,'cash_fee_mismatch' AS issue FROM public.orders o
LEFT JOIN LATERAL(SELECT COALESCE(sum(-available_delta) FILTER(WHERE transaction_type='platform_fee_capture'),0) AS driver_fee,
 COALESCE(sum(-available_delta) FILTER(WHERE transaction_type='customer_platform_fee_capture'),0) AS customer_fee
 FROM public.driver_wallet_transactions t WHERE t.order_id=o.id AND t.driver_id=o.driver_id AND t.status='completed') ledger ON true
WHERE o.business_policy->>'platform_fee_version'='1' AND o.status='delivered'
 AND o.delivery_fee_payer='recipient' AND (ledger.driver_fee<>o.platform_fee_amount OR ledger.customer_fee<>o.customer_platform_fee_amount);

-- 3. Delivery earnings are net, never gross plus a second fee debit for prepaid.
SELECT o.id,o.tracking_code,'net_earning_mismatch' AS issue FROM public.orders o
LEFT JOIN LATERAL(SELECT COALESCE(sum(amount),0) AS earned,COALESCE(sum(available_delta),0) AS credited
 FROM public.driver_wallet_transactions t WHERE t.order_id=o.id AND t.driver_id=o.driver_id
 AND t.status='completed' AND t.transaction_type=CASE WHEN o.delivery_fee_payer='sender' THEN 'prepaid_earning' ELSE 'cod_settlement' END) ledger ON true
WHERE o.business_policy->>'platform_fee_version'='1' AND o.status='delivered' AND
 (ledger.earned<>o.driver_net_earning OR (o.delivery_fee_payer='sender' AND ledger.credited<>o.driver_net_earning));

-- 4. Returned prepaid orders refund only the customer's platform fee.
SELECT o.id,o.tracking_code,'return_fee_refund_mismatch' AS issue FROM public.orders o
LEFT JOIN LATERAL(SELECT COALESCE(sum(available_delta),0) AS refunded FROM public.customer_wallet_transactions t
 WHERE t.order_id=o.id AND t.status='completed' AND t.metadata->>'reason'='returned_platform_fee') ledger ON true
WHERE o.business_policy->>'platform_fee_version'='1' AND o.status='returned' AND o.delivery_fee_payer='sender'
 AND ledger.refunded<>o.customer_platform_fee_amount;

-- 5. Successful late receipts are credited exactly once even without an order.
SELECT s.id,s.provider_txn_ref,'late_payment_refund_mismatch' AS issue FROM public.order_payment_sessions s
LEFT JOIN LATERAL(SELECT COALESCE(sum(available_delta),0) AS refunded,count(*) AS entries
 FROM public.customer_wallet_transactions t WHERE t.payment_session_id=s.id AND t.status='completed') ledger ON true
WHERE s.order_payload->'_business_policy'->>'platform_fee_version'='1' AND s.status='refunded' AND s.order_id IS NULL
 AND (ledger.refunded<>s.amount OR ledger.entries<>1);

-- Fee revenue by terminal status. These are recognized fees, not bank balances.
SELECT status,count(*) AS orders,sum(platform_fee_amount) AS driver_fees,
 sum(CASE WHEN status='delivered' THEN customer_platform_fee_amount ELSE 0 END) AS customer_fees,
 sum(platform_fee_amount+CASE WHEN status='delivered' THEN customer_platform_fee_amount ELSE 0 END) AS recognized_platform_fees
FROM public.orders WHERE business_policy->>'platform_fee_version'='1' AND status IN ('delivered','returned') GROUP BY status;
