-- Commit the enum value before later migrations use it in SQL statements.
ALTER TYPE public.order_status ADD VALUE IF NOT EXISTS 'risk_hold';
