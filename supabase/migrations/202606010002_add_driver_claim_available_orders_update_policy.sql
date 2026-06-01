-- Allow authenticated drivers to claim only currently unassigned orders that
-- are ready for assignment. Existing customer and assigned-driver update
-- policies remain unchanged.

drop policy if exists orders_update_claim_available_for_drivers on public.orders;

create policy orders_update_claim_available_for_drivers
on public.orders
for update
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
)
with check (
  driver_id = auth.uid()
  and status = 'assigned'::public.order_status
  and exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role = 'driver'::public.user_role
  )
);
