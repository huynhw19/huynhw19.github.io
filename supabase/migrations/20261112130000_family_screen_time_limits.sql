alter table public.family_children
  add column if not exists daily_screen_time_limit_minutes integer
  check (daily_screen_time_limit_minutes is null or daily_screen_time_limit_minutes between 1 and 1440);

create table if not exists public.family_screen_time_usage (
  child_id uuid not null references public.family_children(id) on delete cascade,
  usage_date date not null,
  seconds_used integer not null default 0 check (seconds_used >= 0),
  last_seen_at timestamptz not null default now(),
  current_activity text not null default 'kids_zone'
    check (current_activity in ('kids_zone','kids_messages')),
  primary key (child_id, usage_date)
);

alter table public.family_screen_time_usage enable row level security;

drop policy if exists "Parents can view their children's screen time" on public.family_screen_time_usage;
create policy "Parents can view their children's screen time"
on public.family_screen_time_usage
for select to authenticated
using (
  exists (
    select 1 from public.family_children c
    where c.id = family_screen_time_usage.child_id
      and c.parent_id = (select auth.uid())
  )
);

grant select on public.family_screen_time_usage to authenticated;
revoke insert, update, delete on public.family_screen_time_usage from anon, authenticated;

create index if not exists family_screen_time_usage_last_seen_idx
  on public.family_screen_time_usage(last_seen_at desc);

create or replace function public.kids_screen_time_heartbeat(
  p_child_id uuid,
  p_activity text
)
returns table(allowed boolean, used_seconds integer, limit_minutes integer, activity_date date)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_limit integer;
  v_date date := (pg_catalog.now() at time zone 'UTC')::date;
  v_used integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_activity not in ('kids_zone','kids_messages') then
    raise exception 'Invalid activity' using errcode = '22023';
  end if;

  select c.daily_screen_time_limit_minutes
    into v_limit
    from public.family_children c
   where c.id = p_child_id
     and (c.child_user_id = auth.uid() or c.parent_id = auth.uid());

  if not found then
    raise exception 'Child profile not found for this session' using errcode = '42501';
  end if;

  insert into public.family_screen_time_usage as usage (
    child_id, usage_date, seconds_used, last_seen_at, current_activity
  )
  values (p_child_id, v_date, 0, pg_catalog.now(), p_activity)
  on conflict (child_id, usage_date) do update
    set seconds_used = usage.seconds_used +
          case
            when usage.last_seen_at >= pg_catalog.now() - interval '2 minutes'
              then least(90, greatest(0, floor(extract(epoch from (pg_catalog.now() - usage.last_seen_at)))::integer))
            else 0
          end,
        last_seen_at = pg_catalog.now(),
        current_activity = excluded.current_activity
  returning usage.seconds_used
       into v_used;

  return query select
    (v_limit is null or v_used < v_limit * 60),
    v_used,
    v_limit,
    v_date;
end;
$function$;

revoke all on function public.kids_screen_time_heartbeat(uuid,text) from public, anon;
grant execute on function public.kids_screen_time_heartbeat(uuid,text) to authenticated;