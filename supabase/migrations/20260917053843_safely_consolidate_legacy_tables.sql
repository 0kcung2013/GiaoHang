-- Consolidate only the two proven legacy tables. Every destructive step is
-- preceded by a data-copy assertion and uses RESTRICT instead of CASCADE.

do $migration$
declare
  conflicting_ids bigint;
  missing_points bigint;
begin
  if to_regclass('public.locations') is not null then
    if to_regclass('public.driver_locations') is null then
      raise exception 'public.driver_locations is required before consolidating locations';
    end if;

    select count(*)
    into conflicting_ids
    from public.locations legacy
    join public.driver_locations current on current.id = legacy.id
    where current.driver_id is distinct from legacy.driver_id
       or current.lat is distinct from legacy.lat
       or current.lng is distinct from legacy.lng
       or current.created_at is distinct from legacy.timestamp;

    if conflicting_ids > 0 then
      raise exception 'Cannot consolidate locations: % conflicting IDs', conflicting_ids;
    end if;

    insert into public.driver_locations (
      id, driver_id, lat, lng, heading, speed, is_active, created_at
    )
    select
      legacy.id,
      legacy.driver_id,
      legacy.lat,
      legacy.lng,
      null,
      null,
      false,
      legacy.timestamp
    from public.locations legacy
    where not exists (
      select 1
      from public.driver_locations current
      where current.id = legacy.id
    )
      and not exists (
        select 1
        from public.driver_locations current
        where current.driver_id = legacy.driver_id
          and current.lat = legacy.lat
          and current.lng = legacy.lng
          and current.created_at = legacy.timestamp
      );

    select count(*)
    into missing_points
    from public.locations legacy
    where not exists (
      select 1
      from public.driver_locations current
      where current.driver_id = legacy.driver_id
        and current.lat = legacy.lat
        and current.lng = legacy.lng
        and current.created_at = legacy.timestamp
    );

    if missing_points > 0 then
      raise exception 'Cannot drop locations: % rows were not preserved', missing_points;
    end if;

    execute 'drop table public.locations restrict';
  end if;
end;
$migration$;

comment on table public.driver_locations is
  'Canonical GPS history log. Includes data migrated from legacy public.locations.';

do $migration$
declare
  conflicting_ids bigint;
  missing_notes bigint;
begin
  if to_regclass('public.risk_report_notes') is not null then
    select count(*)
    into conflicting_ids
    from public.risk_report_notes note
    join public.risk_report_messages message on message.id = note.id;

    if conflicting_ids > 0 then
      raise exception 'Cannot consolidate risk notes: % conflicting message IDs', conflicting_ids;
    end if;

    insert into public.risk_report_messages (
      id,
      risk_report_id,
      sender_id,
      sender_role_snapshot,
      visibility,
      body,
      created_at
    )
    select
      note.id,
      note.risk_report_id,
      note.author_id,
      author.role::text,
      'internal',
      note.body,
      note.created_at
    from public.risk_report_notes note
    join public.users author on author.id = note.author_id;

    select count(*)
    into missing_notes
    from public.risk_report_notes note
    where not exists (
      select 1
      from public.risk_report_messages message
      where message.id = note.id
        and message.risk_report_id = note.risk_report_id
        and message.sender_id = note.author_id
        and message.visibility = 'internal'
        and message.body = note.body
        and message.created_at = note.created_at
    );

    if missing_notes > 0 then
      raise exception 'Cannot consolidate risk_report_notes: % rows were not preserved', missing_notes;
    end if;
  end if;
end;
$migration$;

-- Keep risk_report_notes temporarily for compatibility with already deployed
-- clients. New clients read internal messages; the RPC writes both shapes with
-- the same ID so the legacy table can be removed in a later release.
create or replace function public.add_risk_report_note(
  p_report_id uuid,
  p_body text
)
returns public.risk_report_notes
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := private.require_risk_staff();
  actor_role public.user_role;
  report public.risk_reports%rowtype;
  created_message public.risk_report_messages%rowtype;
  created_note public.risk_report_notes%rowtype;
  message_id uuid := gen_random_uuid();
  normalized_body text := trim(coalesce(p_body, ''));
begin
  if char_length(normalized_body) not between 3 and 4000 then
    raise exception 'Note must contain between 3 and 4000 characters'
      using errcode = '22023';
  end if;

  select role into actor_role
  from public.users
  where id = actor_id;

  select * into report
  from public.risk_reports
  where id = p_report_id
  for update;

  if not found then
    raise exception 'Risk report not found' using errcode = 'P0002';
  end if;

  if report.assigned_to is distinct from actor_id then
    raise exception 'Only the assigned staff member can add internal notes'
      using errcode = '42501';
  end if;

  insert into public.risk_report_messages (
    id,
    risk_report_id,
    sender_id,
    sender_role_snapshot,
    visibility,
    body
  ) values (
    message_id,
    p_report_id,
    actor_id,
    actor_role::text,
    'internal',
    normalized_body
  )
  returning * into created_message;

  insert into public.risk_report_notes (
    id,
    risk_report_id,
    author_id,
    body,
    created_at
  ) values (
    message_id,
    p_report_id,
    actor_id,
    normalized_body,
    created_message.created_at
  )
  returning * into created_note;

  insert into public.risk_report_events (
    risk_report_id,
    actor_id,
    event_type,
    from_status,
    to_status,
    details
  ) values (
    p_report_id,
    actor_id,
    'note_added',
    report.status,
    report.status,
    jsonb_build_object(
      'note_id', created_message.id,
      'message_id', created_message.id
    )
  );

  return created_note;
end;
$$;

revoke all on function public.add_risk_report_note(uuid, text) from public;
revoke all on function public.add_risk_report_note(uuid, text) from anon;
grant execute on function public.add_risk_report_note(uuid, text) to authenticated;
