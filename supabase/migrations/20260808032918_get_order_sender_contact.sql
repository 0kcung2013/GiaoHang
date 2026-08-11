-- Expose only the sender fields needed by the assigned driver. Direct reads
-- from public.users remain protected by users_select_own.
create or replace function public.get_order_sender_contact(p_order_id uuid)
returns table (
  contact_name text,
  contact_phone text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    sender.full_name as contact_name,
    sender.phone as contact_phone
  from public.orders as delivery_order
  inner join public.users as sender
    on sender.id = delivery_order.customer_id
  where delivery_order.id = p_order_id
    and delivery_order.driver_id = (select auth.uid())
    and delivery_order.status in (
      'assigned'::public.order_status,
      'picking_up'::public.order_status,
      'delivering'::public.order_status
    )
    and exists (
      select 1
      from public.users as caller
      where caller.id = (select auth.uid())
        and caller.role = 'driver'::public.user_role
    )
  limit 1;
$$;

revoke all on function public.get_order_sender_contact(uuid)
from public, anon;

grant execute on function public.get_order_sender_contact(uuid)
to authenticated;
