-- The compatibility RPC returns a constant and does not need elevated rights.
ALTER FUNCTION public.get_platform_fee_amount() SECURITY INVOKER;
