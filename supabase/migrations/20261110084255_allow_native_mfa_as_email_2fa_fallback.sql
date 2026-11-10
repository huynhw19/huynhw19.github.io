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

  -- A native Supabase AAL2 session (TOTP/phone/WebAuthn MFA) is an accepted
  -- alternative to the custom email factor.
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
    from public.email_2fa_verified_sessions v
    where v.session_id = current_session_id
      and v.user_id = current_user_id
      and v.expires_at > pg_catalog.now()
  );
end;
$$;
