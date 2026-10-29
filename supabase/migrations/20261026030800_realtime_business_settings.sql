-- Public signal contains only a revision. Clients refetch via existing APIs;
-- no settings values, history, actor, or audit reasons are broadcast publicly.
create or replace function public.broadcast_business_settings_revision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(
    jsonb_build_object('revision', new.value->'revision'),
    'settings_changed',
    'business-settings',
    false
  );
  return new;
end;
$$;

revoke all on function public.broadcast_business_settings_revision() from public, anon, authenticated;

create trigger broadcast_business_settings_revision
after update on public.system_settings
for each row
when (new.key = 'business_settings' and old.value is distinct from new.value)
execute function public.broadcast_business_settings_revision();

comment on function public.broadcast_business_settings_revision() is
'Internal trigger: committed revision-only signal for authenticated settings and public contact refresh.';
