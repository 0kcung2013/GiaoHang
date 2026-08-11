-- Durable, order-scoped chat with 14-day terminal retention and immutable
-- message snapshots for operational risk reports.

create schema if not exists private;
revoke all on schema private from public;

create table public.order_messages (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null
    references public.orders(id) on delete cascade,
  sender_id uuid not null
    references public.users(id) on delete restrict,
  message_type text not null
    check (message_type in ('text', 'quick_reply', 'system')),
  body text not null
    check (char_length(trim(body)) between 1 and 1000),
  client_message_id uuid not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  constraint order_messages_sender_client_unique
    unique (sender_id, client_message_id)
);

create table public.order_message_reads (
  order_id uuid not null
    references public.orders(id) on delete cascade,
  user_id uuid not null
    references public.users(id) on delete cascade,
  last_read_message_id uuid
    references public.order_messages(id) on delete set null,
  last_read_at timestamptz not null default now(),
  primary key (order_id, user_id)
);

create table public.risk_report_message_evidence (
  id uuid primary key default gen_random_uuid(),
  risk_report_id uuid not null
    references public.risk_reports(id) on delete cascade,
  source_message_id uuid
    references public.order_messages(id) on delete set null,
  order_id uuid not null
    references public.orders(id) on delete restrict,
  sender_id uuid not null
    references public.users(id) on delete restrict,
  message_type text not null
    check (message_type in ('text', 'quick_reply', 'system')),
  body_snapshot text not null
    check (char_length(trim(body_snapshot)) between 1 and 1000),
  sent_at_snapshot timestamptz not null,
  added_by uuid not null
    references public.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint risk_report_message_source_unique
    unique (risk_report_id, source_message_id)
);

create index order_messages_order_created_idx
  on public.order_messages(order_id, created_at desc, id desc);
create index order_messages_expires_idx
  on public.order_messages(expires_at)
  where expires_at is not null;
create index order_messages_sender_idx
  on public.order_messages(sender_id);
create index order_message_reads_user_idx
  on public.order_message_reads(user_id);
create index order_message_reads_last_message_idx
  on public.order_message_reads(last_read_message_id)
  where last_read_message_id is not null;
create index risk_message_evidence_report_created_idx
  on public.risk_report_message_evidence(risk_report_id, created_at desc);
create index risk_message_evidence_source_idx
  on public.risk_report_message_evidence(source_message_id)
  where source_message_id is not null;
create index risk_message_evidence_order_idx
  on public.risk_report_message_evidence(order_id);
create index risk_message_evidence_sender_idx
  on public.risk_report_message_evidence(sender_id);
create index risk_message_evidence_added_by_idx
  on public.risk_report_message_evidence(added_by);

alter table public.order_messages enable row level security;
alter table public.order_message_reads enable row level security;
alter table public.risk_report_message_evidence enable row level security;

revoke all on public.order_messages from anon, authenticated;
revoke all on public.order_message_reads from anon, authenticated;
revoke all on public.risk_report_message_evidence from anon, authenticated;

grant select on public.order_messages to authenticated;
grant insert (
  order_id,
  sender_id,
  message_type,
  body,
  client_message_id
) on public.order_messages to authenticated;
grant select, insert, update on public.order_message_reads to authenticated;
grant select on public.risk_report_message_evidence to authenticated;

create or replace function private.is_order_chat_participant(
  p_order_id uuid,
  p_active_only boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.orders as o
      where o.id = p_order_id
        and (
          o.customer_id = (select auth.uid())
          or o.driver_id = (select auth.uid())
        )
        and (
          not p_active_only
          or o.status in (
            'assigned'::public.order_status,
            'picking_up'::public.order_status,
            'delivering'::public.order_status
          )
        )
    );
$$;

create or replace function private.can_review_order_chat(p_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.users as actor
      where actor.id = (select auth.uid())
        and actor.role in (
          'support'::public.user_role,
          'admin'::public.user_role
        )
    )
    and exists (
      select 1
      from public.risk_reports as rr
      where rr.order_id = p_order_id
    );
$$;

revoke all on function private.is_order_chat_participant(uuid, boolean)
  from public, anon, authenticated, service_role;
revoke all on function private.can_review_order_chat(uuid)
  from public, anon, authenticated, service_role;
grant usage on schema private to authenticated;
grant execute on function private.is_order_chat_participant(uuid, boolean)
  to authenticated;
grant execute on function private.can_review_order_chat(uuid)
  to authenticated;

create policy order_messages_authorized_select
on public.order_messages
for select
to authenticated
using (
  (select private.is_order_chat_participant(order_id, false))
  or (select private.can_review_order_chat(order_id))
);

create policy order_messages_participant_insert
on public.order_messages
for insert
to authenticated
with check (
  sender_id = (select auth.uid())
  and expires_at is null
  and message_type in ('text', 'quick_reply')
  and (select private.is_order_chat_participant(order_id, true))
);

create policy order_message_reads_participant_select
on public.order_message_reads
for select
to authenticated
using (
  user_id = (select auth.uid())
  and (select private.is_order_chat_participant(order_id, false))
);

create policy order_message_reads_participant_insert
on public.order_message_reads
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and (select private.is_order_chat_participant(order_id, false))
);

create policy order_message_reads_participant_update
on public.order_message_reads
for update
to authenticated
using (
  user_id = (select auth.uid())
  and (select private.is_order_chat_participant(order_id, false))
)
with check (
  user_id = (select auth.uid())
  and (select private.is_order_chat_participant(order_id, false))
);

create policy risk_message_evidence_staff_select
on public.risk_report_message_evidence
for select
to authenticated
using ((select private.can_review_order_chat(order_id)));

create or replace function public.attach_risk_report_message_evidence(
  p_risk_report_id uuid,
  p_message_ids uuid[]
)
returns setof public.risk_report_message_evidence
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  report_order_id uuid;
  requested_count integer;
  matched_count integer;
begin
  if actor_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.users as actor
    where actor.id = actor_id
      and actor.role in (
        'support'::public.user_role,
        'admin'::public.user_role
      )
  ) then
    raise exception 'Only Support or Admin can attach message evidence'
      using errcode = '42501';
  end if;

  select rr.order_id
  into report_order_id
  from public.risk_reports as rr
  where rr.id = p_risk_report_id;

  if report_order_id is null then
    raise exception 'Risk report not found' using errcode = 'P0002';
  end if;

  select count(distinct message_id)
  into requested_count
  from unnest(coalesce(p_message_ids, array[]::uuid[])) as message_id;

  if requested_count < 1 or requested_count > 20 then
    raise exception 'Select between 1 and 20 messages'
      using errcode = '22023';
  end if;

  select count(*)
  into matched_count
  from public.order_messages as message
  where message.order_id = report_order_id
    and message.id = any(p_message_ids);

  if matched_count <> requested_count then
    raise exception 'Every message must belong to the risk report order'
      using errcode = '23514';
  end if;

  insert into public.risk_report_message_evidence (
    risk_report_id,
    source_message_id,
    order_id,
    sender_id,
    message_type,
    body_snapshot,
    sent_at_snapshot,
    added_by
  )
  select
    p_risk_report_id,
    message.id,
    message.order_id,
    message.sender_id,
    message.message_type,
    message.body,
    message.created_at,
    actor_id
  from public.order_messages as message
  where message.order_id = report_order_id
    and message.id = any(p_message_ids)
  on conflict (risk_report_id, source_message_id) do nothing;

  update public.risk_reports
  set updated_by = actor_id,
      updated_at = now()
  where id = p_risk_report_id;

  return query
  select evidence.*
  from public.risk_report_message_evidence as evidence
  where evidence.risk_report_id = p_risk_report_id
  order by evidence.sent_at_snapshot, evidence.id;
end;
$$;

revoke all on function public.attach_risk_report_message_evidence(uuid, uuid[])
  from public, anon, authenticated, service_role;
grant execute on function public.attach_risk_report_message_evidence(uuid, uuid[])
  to authenticated;

create or replace function private.set_order_message_expiry()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  terminal_at timestamptz;
begin
  if new.status in (
    'delivered'::public.order_status,
    'cancelled'::public.order_status
  ) and old.status not in (
    'delivered'::public.order_status,
    'cancelled'::public.order_status
  ) then
    terminal_at := case
      when new.status = 'delivered'::public.order_status
        then coalesce(new.actual_delivered_at, clock_timestamp())
      else coalesce(new.cancelled_at, clock_timestamp())
    end;

    update public.order_messages
    set expires_at = terminal_at + interval '14 days'
    where order_id = new.id
      and expires_at is null;
  end if;
  return new;
end;
$$;

revoke all on function private.set_order_message_expiry()
  from public, anon, authenticated, service_role;

create trigger orders_set_message_expiry
after update of status on public.orders
for each row
when (old.status is distinct from new.status)
execute function private.set_order_message_expiry();

create or replace function private.cleanup_expired_order_messages(
  p_batch_size integer default 1000
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer;
begin
  if p_batch_size < 1 or p_batch_size > 10000 then
    raise exception 'Batch size must be between 1 and 10000'
      using errcode = '22023';
  end if;

  with expired as (
    select message.id, message.order_id
    from public.order_messages as message
    where message.expires_at <= now()
    order by message.expires_at, message.id
    limit p_batch_size
    for update skip locked
  ), deleted as (
    delete from public.order_messages as message
    using expired
    where message.id = expired.id
    returning message.order_id
  ), cleaned_reads as (
    delete from public.order_message_reads as reads
    where reads.order_id in (select distinct order_id from deleted)
      and not exists (
        select 1
        from public.order_messages as remaining
        where remaining.order_id = reads.order_id
      )
    returning reads.order_id
  )
  select count(*) into deleted_count from deleted;

  return deleted_count;
end;
$$;

revoke all on function private.cleanup_expired_order_messages(integer)
  from public, anon, authenticated, service_role;

create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'cleanup-expired-order-messages',
  '15 3 * * *',
  'select private.cleanup_expired_order_messages(1000);'
);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'order_messages'
  ) then
    alter publication supabase_realtime add table public.order_messages;
  end if;
end;
$$;

comment on table public.order_messages is
  'Durable customer-driver messages scoped to one order.';
comment on table public.order_message_reads is
  'Per-participant read cursor for an order conversation.';
comment on table public.risk_report_message_evidence is
  'Immutable message snapshots retained as operational risk evidence.';
