alter table public.users
  add column if not exists active_session_id uuid,
  add column if not exists active_session_updated_at timestamptz;

comment on column public.users.active_session_id is
  'Session ID from the authenticated JWT that currently owns this account.';

comment on column public.users.active_session_updated_at is
  'Time at which the active session marker was last claimed.';

create or replace function public.claim_active_session()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  current_session_id uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
begin
  if current_user_id is null or current_session_id is null then
    raise exception 'An authenticated session is required'
      using errcode = '42501';
  end if;

  update public.users
  set
    active_session_id = current_session_id,
    active_session_updated_at = now()
  where id = current_user_id;

  if not found then
    raise exception 'User profile does not exist'
      using errcode = 'P0002';
  end if;

  return current_session_id;
end;
$$;

revoke all on function public.claim_active_session() from public;
revoke all on function public.claim_active_session() from anon;
grant execute on function public.claim_active_session() to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'users'
  ) then
    alter publication supabase_realtime add table public.users;
  end if;
end;
$$;
