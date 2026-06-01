-- Allow authenticated drivers to progress only their assigned orders through
-- the Phase 1 delivery status flow. The policy scopes eligible rows; the
-- trigger below enforces exact one-step transitions and prevents unrelated
-- field changes by driver clients.

drop policy if exists orders_update_status_progress_for_drivers on public.orders;

create policy orders_update_status_progress_for_drivers
on public.orders
for update
to authenticated
using (
  driver_id = auth.uid()
  and status in (
    'assigned'::public.order_status,
    'picking_up'::public.order_status,
    'delivering'::public.order_status
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
  and status in (
    'picking_up'::public.order_status,
    'delivering'::public.order_status,
    'delivered'::public.order_status
  )
  and exists (
    select 1
    from public.users
    where users.id = auth.uid()
      and users.role = 'driver'::public.user_role
  )
);

create or replace function public.enforce_driver_order_status_progression()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.driver_id = auth.uid()
    and exists (
      select 1
      from public.users
      where users.id = auth.uid()
        and users.role = 'driver'::public.user_role
    )
  then
    if (to_jsonb(new) - 'status' - 'updated_at') <>
       (to_jsonb(old) - 'status' - 'updated_at') then
      raise exception 'Drivers may only update order status fields.';
    end if;

    if not (
      (old.status = 'assigned'::public.order_status
        and new.status = 'picking_up'::public.order_status)
      or (old.status = 'picking_up'::public.order_status
        and new.status = 'delivering'::public.order_status)
      or (old.status = 'delivering'::public.order_status
        and new.status = 'delivered'::public.order_status)
    ) then
      raise exception 'Invalid driver order status transition.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_driver_order_status_progression on public.orders;

create trigger enforce_driver_order_status_progression
before update on public.orders
for each row
execute function public.enforce_driver_order_status_progression();
