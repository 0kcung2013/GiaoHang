-- Retire the platform fee for all newly created orders while preserving
-- historical order and wallet snapshots for auditability.

INSERT INTO public.system_settings (key, value, updated_at)
VALUES ('platform_fee_amount', to_jsonb(0), clock_timestamp())
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value, updated_at = EXCLUDED.updated_at;

UPDATE public.system_settings
SET value = to_jsonb(0), updated_at = clock_timestamp()
WHERE key = 'platform_fee_rate_bps';

ALTER TABLE public.orders
  ALTER COLUMN platform_fee_rate_bps SET DEFAULT 0,
  ALTER COLUMN platform_fee_amount SET DEFAULT 0;

-- Keep the RPC for compatibility with already deployed clients. It now
-- reports zero, which also makes create_customer_order stop charging the fee.
CREATE OR REPLACE FUNCTION public.get_platform_fee_amount()
RETURNS bigint
LANGUAGE sql
IMMUTABLE
SECURITY INVOKER
SET search_path = ''
AS $function$
  SELECT 0::bigint;
$function$;

REVOKE ALL ON FUNCTION public.get_platform_fee_amount()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_platform_fee_amount()
  TO authenticated;

-- Unclaimed orders have no wallet holds, so their customer totals can be
-- updated safely. Assigned and historical orders keep their original snapshot.
UPDATE public.orders
SET
  total_price = greatest(
    0,
    round(total_price)::bigint - platform_fee_amount
  ),
  platform_fee_rate_bps = 0,
  platform_fee_amount = 0,
  receiver_collection_amount = CASE
    WHEN payment_mode = 'cod' THEN greatest(
      0,
      receiver_collection_amount - platform_fee_amount
    )
    ELSE 0
  END,
  updated_at = clock_timestamp()
WHERE driver_id IS NULL
  AND status IN (
    'pending'::public.order_status,
    'confirmed'::public.order_status
  )
  AND platform_fee_amount > 0;
