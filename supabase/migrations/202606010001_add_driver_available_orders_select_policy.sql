-- Allow authenticated drivers to view only unassigned orders that are ready
-- to be accepted. Existing customer and assigned-driver SELECT policies remain
-- unchanged.

drop policy if exists orders_select_available_for_drivers on public.orders;

create policy orders_select_available_for_drivers
on public.orders
for select
to authenticated
using (
  driver_id is null
  and status in (
    'pending'::public.order_status,
    'confirmed'::public.order_status
  )
  and exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role = 'driver'::public.user_role
  )
);
