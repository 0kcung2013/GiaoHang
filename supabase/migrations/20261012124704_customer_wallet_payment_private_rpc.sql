-- Keep privileged ledger writes in the unexposed schema. The public API uses
-- caller privileges and delegates to the authenticated, role-checked command.
ALTER FUNCTION public.create_customer_order_with_wallet(jsonb, uuid) SET SCHEMA private;

CREATE FUNCTION public.create_customer_order_with_wallet(p_order_payload jsonb, p_request_id uuid)
RETURNS public.orders
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT private.create_customer_order_with_wallet(p_order_payload, p_request_id);
$function$;
REVOKE ALL ON FUNCTION public.create_customer_order_with_wallet(jsonb, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_customer_order_with_wallet(jsonb, uuid) TO authenticated;
-- ALTER FUNCTION preserves the original explicit EXECUTE grant on the private
-- command. Its auth.uid(), customer role, balance and request checks remain.
