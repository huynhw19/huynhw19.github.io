create schema if not exists private;

create table if not exists private.recovery_code_sets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists private.recovery_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  code_hash text not null,
  created_at timestamptz not null default now(),
  used_at timestamptz,
  constraint recovery_codes_hash_format check (code_hash ~ '^[0-9a-f]{64}$'),
  constraint recovery_codes_user_hash_unique unique (user_id, code_hash)
);
create index if not exists recovery_codes_user_unused_idx
  on private.recovery_codes(user_id, created_at)
  where used_at is null;

create table if not exists private.recovery_code_attempts (
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null,
  window_started_at timestamptz not null default now(),
  attempts integer not null default 0 check (attempts >= 0),
  primary key (user_id, session_id)
);

create table if not exists private.recovery_verified_sessions (
  session_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  verified_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index if not exists recovery_verified_sessions_user_idx
  on private.recovery_verified_sessions(user_id, expires_at);

alter table private.recovery_code_sets enable row level security;
alter table private.recovery_codes enable row level security;
alter table private.recovery_code_attempts enable row level security;
alter table private.recovery_verified_sessions enable row level security;

revoke all on private.recovery_code_sets, private.recovery_codes,
  private.recovery_code_attempts, private.recovery_verified_sessions
  from public, anon, authenticated;
grant usage on schema private to service_role;
grant all on private.recovery_code_sets, private.recovery_codes,
  private.recovery_code_attempts, private.recovery_verified_sessions
  to service_role;

create or replace function public.replace_recovery_codes(
  p_user_id uuid,
  p_code_hashes text[]
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  inserted_count integer;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  if p_user_id is null or p_code_hashes is null
     or pg_catalog.cardinality(p_code_hashes) <> 10
     or exists (
       select 1 from pg_catalog.unnest(p_code_hashes) as h
       where h !~ '^[0-9a-f]{64}$'
     )
     or (select pg_catalog.count(distinct h) from pg_catalog.unnest(p_code_hashes) as h) <> 10 then
    raise exception 'Invalid recovery code batch' using errcode = '22023';
  end if;

  delete from private.recovery_codes where user_id = p_user_id;
  insert into private.recovery_codes(user_id, code_hash)
    select p_user_id, h from pg_catalog.unnest(p_code_hashes) as h;
  get diagnostics inserted_count = row_count;

  insert into private.recovery_code_sets(user_id, created_at)
    values (p_user_id, pg_catalog.now())
    on conflict (user_id) do update set created_at = excluded.created_at;

  delete from private.recovery_code_attempts where user_id = p_user_id;
  return inserted_count;
end;
$$;

create or replace function public.consume_recovery_code(
  p_user_id uuid,
  p_session_id uuid,
  p_code_hash text
)
returns text
language plpgsql
set search_path = ''
as $$
declare
  current_attempts integer;
  consumed_id uuid;
  now_at timestamptz := pg_catalog.now();
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  if p_user_id is null or p_session_id is null or p_code_hash is null
     or p_code_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid recovery code request' using errcode = '22023';
  end if;

  insert into private.recovery_code_attempts(user_id, session_id, window_started_at, attempts)
    values (p_user_id, p_session_id, now_at, 1)
    on conflict (user_id, session_id) do update
      set attempts = case
            when private.recovery_code_attempts.window_started_at <= now_at - interval '15 minutes' then 1
            else private.recovery_code_attempts.attempts + 1
          end,
          window_started_at = case
            when private.recovery_code_attempts.window_started_at <= now_at - interval '15 minutes' then now_at
            else private.recovery_code_attempts.window_started_at
          end
    returning attempts into current_attempts;

  if current_attempts > 10 then
    return 'rate_limited';
  end if;

  update private.recovery_codes
     set used_at = now_at
   where id = (
     select id
       from private.recovery_codes
      where user_id = p_user_id
        and code_hash = p_code_hash
        and used_at is null
      order by created_at
      limit 1
      for update skip locked
   )
     and used_at is null
  returning id into consumed_id;

  if consumed_id is null then
    return 'invalid';
  end if;

  insert into private.recovery_verified_sessions(session_id, user_id, verified_at, expires_at)
    values (p_session_id, p_user_id, now_at, now_at + interval '8 hours')
    on conflict (session_id) do update
      set user_id = excluded.user_id,
          verified_at = excluded.verified_at,
          expires_at = excluded.expires_at;

  return 'success';
end;
$$;

revoke all on function public.replace_recovery_codes(uuid, text[]) from public, anon, authenticated;
revoke all on function public.consume_recovery_code(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.replace_recovery_codes(uuid, text[]) to service_role;
grant execute on function public.consume_recovery_code(uuid, uuid, text) to service_role;

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
  recovery_codes_enabled boolean := false;
begin
  if current_user_id is null then
    return false;
  end if;

  select coalesce(s.enabled, false)
    into email_factor_enabled
    from public.email_2fa_settings s
   where s.user_id = current_user_id;

  select exists (
    select 1 from private.recovery_code_sets r
     where r.user_id = current_user_id
  ) into recovery_codes_enabled;

  if not email_factor_enabled and not recovery_codes_enabled then
    return true;
  end if;

  if coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2' then
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

  if email_factor_enabled and exists (
    select 1 from public.email_2fa_verified_sessions v
     where v.session_id = current_session_id
       and v.user_id = current_user_id
       and v.expires_at > pg_catalog.now()
  ) then
    return true;
  end if;

  if recovery_codes_enabled and exists (
    select 1 from private.recovery_verified_sessions v
     where v.session_id = current_session_id
       and v.user_id = current_user_id
       and v.expires_at > pg_catalog.now()
  ) then
    return true;
  end if;

  return false;
end;
$$;

revoke all on function private.email_2fa_access_allowed() from public, anon;
grant execute on function private.email_2fa_access_allowed() to authenticated;
