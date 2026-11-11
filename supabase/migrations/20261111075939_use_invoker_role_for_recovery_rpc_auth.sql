create or replace function public.replace_recovery_codes(p_user_id uuid,p_code_hashes text[])
returns integer
language plpgsql
set search_path = ''
as $$
declare inserted_count integer;
begin
  if current_user not in ('service_role','postgres') then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  if p_user_id is null or p_code_hashes is null
     or pg_catalog.cardinality(p_code_hashes) <> 10
     or exists (select 1 from pg_catalog.unnest(p_code_hashes) as h where h !~ '^[0-9a-f]{64}$')
     or (select pg_catalog.count(distinct h) from pg_catalog.unnest(p_code_hashes) as h) <> 10 then
    raise exception 'Invalid recovery code batch' using errcode = '22023';
  end if;
  delete from private.recovery_codes where user_id = p_user_id;
  insert into private.recovery_codes(user_id,code_hash)
    select p_user_id,h from pg_catalog.unnest(p_code_hashes) as h;
  get diagnostics inserted_count = row_count;
  insert into private.recovery_code_sets(user_id,created_at)
    values (p_user_id,pg_catalog.now())
    on conflict (user_id) do update set created_at = excluded.created_at;
  delete from private.recovery_code_attempts where user_id = p_user_id;
  return inserted_count;
end;
$$;

create or replace function public.consume_recovery_code(p_user_id uuid,p_session_id uuid,p_code_hash text)
returns text
language plpgsql
set search_path = ''
as $$
declare current_attempts integer; consumed_id uuid; now_at timestamptz := pg_catalog.now();
begin
  if current_user not in ('service_role','postgres') then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  if p_user_id is null or p_session_id is null or p_code_hash is null
     or p_code_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid recovery code request' using errcode = '22023';
  end if;
  insert into private.recovery_code_attempts(user_id,session_id,window_started_at,attempts)
    values (p_user_id,p_session_id,now_at,1)
    on conflict (user_id,session_id) do update
      set attempts = case
            when private.recovery_code_attempts.window_started_at <= now_at - interval '15 minutes' then 1
            else private.recovery_code_attempts.attempts + 1 end,
          window_started_at = case
            when private.recovery_code_attempts.window_started_at <= now_at - interval '15 minutes' then now_at
            else private.recovery_code_attempts.window_started_at end
    returning attempts into current_attempts;
  if current_attempts > 10 then return 'rate_limited'; end if;
  update private.recovery_codes set used_at = now_at
   where id = (
     select id from private.recovery_codes
      where user_id = p_user_id and code_hash = p_code_hash and used_at is null
      order by created_at limit 1 for update skip locked
   ) and used_at is null
  returning id into consumed_id;
  if consumed_id is null then return 'invalid'; end if;
  insert into private.recovery_verified_sessions(session_id,user_id,verified_at,expires_at)
    values (p_session_id,p_user_id,now_at,now_at + interval '8 hours')
    on conflict (session_id) do update
      set user_id = excluded.user_id, verified_at = excluded.verified_at, expires_at = excluded.expires_at;
  return 'success';
end;
$$;

create or replace function public.get_recovery_code_status(p_user_id uuid,p_session_id uuid)
returns table(enabled boolean,remaining integer,verified boolean)
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('service_role','postgres') then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  return query select
    exists(select 1 from private.recovery_code_sets s where s.user_id = p_user_id),
    (select pg_catalog.count(*)::integer from private.recovery_codes c where c.user_id = p_user_id and c.used_at is null),
    exists(select 1 from private.recovery_verified_sessions v where v.user_id = p_user_id and v.session_id = p_session_id and v.expires_at > pg_catalog.now());
end;
$$;

create or replace function public.clear_recovery_codes(p_user_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('service_role','postgres') then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  delete from private.recovery_codes where user_id = p_user_id;
  delete from private.recovery_code_sets where user_id = p_user_id;
  delete from private.recovery_code_attempts where user_id = p_user_id;
end;
$$;
