create table if not exists public.configkit_trusted_devices (
  session_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  device_name text not null default 'Trusted device',
  trusted_at timestamptz not null default now(),
  constraint configkit_trusted_devices_session_user_unique unique (session_id, user_id)
);

alter table public.configkit_trusted_devices enable row level security;
revoke all on public.configkit_trusted_devices from anon, authenticated;
grant select on public.configkit_trusted_devices to authenticated;

drop policy if exists configkit_trusted_devices_select_own on public.configkit_trusted_devices;
create policy configkit_trusted_devices_select_own
  on public.configkit_trusted_devices
  for select to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.is_current_device_trusted()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.configkit_trusted_devices d
    join auth.sessions s on s.id = d.session_id and s.user_id = d.user_id
    where d.user_id = (select auth.uid())
      and d.session_id::text = (select auth.jwt() ->> 'session_id')
  );
$$;

create or replace function public.trust_current_device()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_session_id uuid := nullif((select auth.jwt() ->> 'session_id'), '')::uuid;
  v_device_name text;
begin
  if v_user_id is null or v_session_id is null then
    raise exception 'An active sign-in session is required' using errcode = '28000';
  end if;
  if (select auth.jwt() ->> 'aal') is distinct from 'aal2' then
    raise exception 'Complete two-factor verification before trusting this device' using errcode = '42501';
  end if;

  select coalesce(nullif(d.device_name, ''), 'Trusted device')
    into v_device_name
  from public.configkit_device_sessions d
  join auth.sessions s on s.id = d.session_id and s.user_id = d.user_id
  where d.user_id = v_user_id and d.session_id = v_session_id;

  if not found then
    raise exception 'This device session could not be verified. Refresh the page and try again' using errcode = '22023';
  end if;

  insert into public.configkit_trusted_devices(session_id, user_id, device_name)
  values (v_session_id, v_user_id, v_device_name)
  on conflict (session_id) do update
    set device_name = excluded.device_name, trusted_at = now()
    where public.configkit_trusted_devices.user_id = excluded.user_id;

  return true;
end;
$$;

create or replace function public.untrust_current_device()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_session_id uuid := nullif((select auth.jwt() ->> 'session_id'), '')::uuid;
  v_deleted integer := 0;
begin
  if v_user_id is null or v_session_id is null then
    raise exception 'An active sign-in session is required' using errcode = '28000';
  end if;

  delete from public.configkit_trusted_devices
  where user_id = v_user_id and session_id = v_session_id;
  get diagnostics v_deleted = row_count;
  return v_deleted > 0;
end;
$$;

revoke all on function public.is_current_device_trusted() from public, anon;
revoke all on function public.trust_current_device() from public, anon;
revoke all on function public.untrust_current_device() from public, anon;
grant execute on function public.is_current_device_trusted() to authenticated;
grant execute on function public.trust_current_device() to authenticated;
grant execute on function public.untrust_current_device() to authenticated;
