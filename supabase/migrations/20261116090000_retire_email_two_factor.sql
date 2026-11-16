-- Retire custom email-based second-factor verification.
-- Keep the legacy helper name because existing restrictive policies and RPCs
-- reference it, but email_2fa_settings and email verification sessions no
-- longer grant or deny access. Native Supabase AAL2 and recovery-code sessions
-- remain supported.
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
  recovery_codes_enabled boolean := false;
begin
  if current_user_id is null then
    return false;
  end if;

  select exists (
    select 1
      from private.recovery_code_sets r
     where r.user_id = current_user_id
  ) into recovery_codes_enabled;

  if not recovery_codes_enabled then
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

  return exists (
    select 1
      from private.recovery_verified_sessions v
     where v.session_id = current_session_id
       and v.user_id = current_user_id
       and v.expires_at > pg_catalog.now()
  );
end;
$$;

revoke all on function private.email_2fa_access_allowed() from public, anon;
grant execute on function private.email_2fa_access_allowed() to authenticated;
