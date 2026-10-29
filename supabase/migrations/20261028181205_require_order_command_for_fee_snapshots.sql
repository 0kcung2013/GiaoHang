-- A caller-supplied legacy policy must never bypass the fee command boundary.
-- Trusted RPCs still create legacy orders for already-paid pre-rollout sessions.
CREATE OR REPLACE FUNCTION private.guard_platform_fee_snapshot() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $fn$
DECLARE policy jsonb; customer_fee bigint; driver_fee bigint;
BEGIN
 IF TG_OP='INSERT' THEN
   IF current_user NOT IN ('postgres','service_role','supabase_admin') THEN
     RAISE EXCEPTION 'ORDER_FINANCE_COMMAND_REQUIRED' USING ERRCODE='42501'; END IF;
   IF NEW.business_policy->>'platform_fee_version' IS DISTINCT FROM '1' THEN RETURN NEW; END IF;
   policy:=private.order_fee_policy(NEW.customer_id,NEW.business_policy);
   customer_fee:=private.customer_platform_fee(NEW.delivery_fee,policy);
   driver_fee:=private.driver_platform_fee(NEW.delivery_fee,policy);
   NEW.business_policy:=policy;
   NEW.customer_platform_fee_rate_bps:=(policy->'values'->>CASE WHEN policy->>'customer_type'='business'
     THEN 'customer_business_fee_bps' ELSE 'customer_individual_fee_bps' END)::integer;
   NEW.customer_platform_fee_amount:=customer_fee;
   NEW.platform_fee_rate_bps:=(policy->'values'->>'driver_platform_fee_bps')::integer;
   NEW.platform_fee_amount:=driver_fee;
   NEW.driver_net_earning:=round(NEW.delivery_fee)::bigint-driver_fee;
   NEW.total_price:=NEW.delivery_fee+NEW.cod_collection_amount+customer_fee;
   NEW.receiver_collection_amount:=NEW.cod_collection_amount+CASE WHEN NEW.delivery_fee_payer='recipient'
     THEN round(NEW.delivery_fee)::bigint+customer_fee ELSE 0 END;
 ELSE
   IF OLD.business_policy->>'platform_fee_version' IS DISTINCT FROM '1' THEN RETURN NEW; END IF;
   IF ROW(NEW.customer_id,NEW.delivery_fee,NEW.total_price,NEW.cod_collection_amount,NEW.goods_value,
      NEW.driver_advance_amount,NEW.receiver_collection_amount,NEW.driver_net_earning,NEW.delivery_fee_payer,
      NEW.platform_fee_rate_bps,NEW.platform_fee_amount,NEW.customer_platform_fee_rate_bps,NEW.customer_platform_fee_amount)
     IS DISTINCT FROM ROW(OLD.customer_id,OLD.delivery_fee,OLD.total_price,OLD.cod_collection_amount,OLD.goods_value,
      OLD.driver_advance_amount,OLD.receiver_collection_amount,OLD.driver_net_earning,OLD.delivery_fee_payer,
      OLD.platform_fee_rate_bps,OLD.platform_fee_amount,OLD.customer_platform_fee_rate_bps,OLD.customer_platform_fee_amount)
   THEN RAISE EXCEPTION 'ORDER_FINANCE_SNAPSHOT_IMMUTABLE' USING ERRCODE='42501'; END IF;
   IF current_user NOT IN ('postgres','service_role','supabase_admin') AND
      ROW(NEW.status,NEW.driver_id,NEW.actual_picked_up_at,NEW.actual_delivered_at,NEW.payment_method,NEW.payment_status)
      IS DISTINCT FROM ROW(OLD.status,OLD.driver_id,OLD.actual_picked_up_at,OLD.actual_delivered_at,OLD.payment_method,OLD.payment_status)
   THEN RAISE EXCEPTION 'ORDER_FINANCE_COMMAND_REQUIRED' USING ERRCODE='42501'; END IF;
 END IF;
 RETURN NEW;
END;
$fn$;
