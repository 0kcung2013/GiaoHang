-- Keep enum additions isolated: PostgreSQL cannot safely use new enum values
-- in the same migration transaction that creates them.
ALTER TYPE public.order_status
  ADD VALUE IF NOT EXISTS 'return_approved';

ALTER TYPE public.order_status
  ADD VALUE IF NOT EXISTS 'returning';

ALTER TYPE public.order_status
  ADD VALUE IF NOT EXISTS 'returned';
