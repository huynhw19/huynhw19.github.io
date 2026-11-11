create policy recovery_code_sets_service_role_all
  on private.recovery_code_sets for all to service_role
  using (true) with check (true);
create policy recovery_codes_service_role_all
  on private.recovery_codes for all to service_role
  using (true) with check (true);
create policy recovery_code_attempts_service_role_all
  on private.recovery_code_attempts for all to service_role
  using (true) with check (true);
create policy recovery_verified_sessions_service_role_all
  on private.recovery_verified_sessions for all to service_role
  using (true) with check (true);

create or replace function public.get_recovery_code_status(
  p_user_id uuid,
  p_session_id uuid
)
returns table(enabled boolean, remaining integer, verified boolean)
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  return query
    select
      exists(select 1 from private.recovery_code_sets s where s.user_id = p_user_id),
      (select pg_catalog.count(*)::integer from private.recovery_codes c
        where c.user_id = p_user_id and c.used_at is null),
      exists(select 1 from private.recovery_verified_sessions v
        where v.user_id = p_user_id and v.session_id = p_session_id
          and v.expires_at > pg_catalog.now());
end;
$$;

create or replace function public.clear_recovery_codes(p_user_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  delete from private.recovery_codes where user_id = p_user_id;
  delete from private.recovery_code_sets where user_id = p_user_id;
  delete from private.recovery_code_attempts where user_id = p_user_id;
end;
$$;

revoke all on function public.get_recovery_code_status(uuid, uuid) from public, anon, authenticated;
revoke all on function public.clear_recovery_codes(uuid) from public, anon, authenticated;
grant execute on function public.get_recovery_code_status(uuid, uuid) to service_role;
grant execute on function public.clear_recovery_codes(uuid) to service_role;
