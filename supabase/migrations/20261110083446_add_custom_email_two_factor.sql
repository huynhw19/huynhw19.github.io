create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create table if not exists public.email_2fa_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.email_2fa_challenges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null,
  purpose text not null check (purpose in ('login','enroll')),
  code_hash text not null,
  link_hash text not null,
  attempts integer not null default 0 check (attempts between 0 and 5),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  consumed_at timestamptz
);
create index if not exists email_2fa_challenges_user_session_created_idx
  on public.email_2fa_challenges(user_id, session_id, created_at desc);
create table if not exists public.email_2fa_verified_sessions (
  session_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  verified_at timestamptz not null default now(),
  expires_at timestamptz not null
);

alter table public.email_2fa_settings enable row level security;
alter table public.email_2fa_challenges enable row level security;
alter table public.email_2fa_verified_sessions enable row level security;
revoke all on public.email_2fa_settings, public.email_2fa_challenges, public.email_2fa_verified_sessions from public, anon, authenticated;
grant all on public.email_2fa_settings, public.email_2fa_challenges, public.email_2fa_verified_sessions to service_role;

create or replace function private.email_2fa_access_allowed()
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  current_session_id uuid;
  email_factor_enabled boolean := false;
begin
  if current_user_id is null then
    return false;
  end if;

  select coalesce(s.enabled, false)
    into email_factor_enabled
    from public.email_2fa_settings s
    where s.user_id = current_user_id;

  if not email_factor_enabled then
    return true;
  end if;

  begin
    current_session_id := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  exception when others then
    return false;
  end;

  if current_session_id is null then
    return false;
  end if;

  return exists (
    select 1
    from public.email_2fa_verified_sessions v
    where v.session_id = current_session_id
      and v.user_id = current_user_id
      and v.expires_at > pg_catalog.now()
  );
end;
$$;

revoke all on function private.email_2fa_access_allowed() from public, anon;
grant execute on function private.email_2fa_access_allowed() to authenticated;

do $$
declare
  t record;
begin
  for t in
    select n.nspname as schema_name, c.relname as table_name
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r','p')
  loop
    execute pg_catalog.format('alter table %I.%I enable row level security', t.schema_name, t.table_name);
    execute pg_catalog.format('drop policy if exists %I on %I.%I', 'email_2fa_session_gate', t.schema_name, t.table_name);
    execute pg_catalog.format(
      'create policy %I on %I.%I as restrictive for all to authenticated using (private.email_2fa_access_allowed()) with check (private.email_2fa_access_allowed())',
      'email_2fa_session_gate', t.schema_name, t.table_name
    );
  end loop;
end;
$$;

do $$
begin
  if pg_catalog.to_regclass('storage.objects') is not null then
    execute 'drop policy if exists email_2fa_session_gate on storage.objects';
    execute 'create policy email_2fa_session_gate on storage.objects as restrictive for all to authenticated using (private.email_2fa_access_allowed()) with check (private.email_2fa_access_allowed())';
  end if;
end;
$$;
