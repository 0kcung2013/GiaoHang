-- Rollback-only: no configuration change or Broadcast is committed.
begin;
do $$
declare
  before_count bigint;
  next_revision bigint;
  after_count bigint;
begin
  select count(*) into before_count from realtime.messages
  where topic='business-settings' and event='settings_changed';

  update public.system_settings
  set value=jsonb_set(value, '{revision}', to_jsonb((value->>'revision')::bigint+1))
  where key='business_settings'
  returning (value->>'revision')::bigint into next_revision;

  select count(*) into after_count from realtime.messages
  where topic='business-settings' and event='settings_changed';
  assert after_count=before_count+1, 'A changed revision must emit exactly one event';
  assert exists (
    select 1 from realtime.messages
    where topic='business-settings' and event='settings_changed' and not private
      and payload - 'id'=jsonb_build_object('revision', next_revision)
  ), 'Public Broadcast must contain only the revision plus Realtime transport ID';

  update public.system_settings set value=value where key='business_settings';
  select count(*) into after_count from realtime.messages
  where topic='business-settings' and event='settings_changed';
  assert after_count=before_count+1, 'An unchanged value must not emit an event';
  assert not has_function_privilege('anon', 'public.broadcast_business_settings_revision()', 'execute');
  assert not has_function_privilege('authenticated', 'public.broadcast_business_settings_revision()', 'execute');
end;
$$;
rollback;
select 'business_settings_realtime_regression passed (rolled back)' as result;
