-- Permit Supabase-verified passkey/WebAuthn sessions through the
-- ConfigKit verified-session gate. Preserve AAL2 and recovery-code checks.
create or replace function private.email_2fa_access_allowed()
returns boolean
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  current_user_id uuid := auth.uid();
  current_session_id uuid;
  recovery_codes_enabled boolean := false;
  auth_methods jsonb := coalesce(auth.jwt() -> 'amr', '[]'::jsonb);
begin
  if current_user_id is null then return false; end if;

  select exists (
    select 1 from private.recovery_code_sets r
    where r.user_id = current_user_id
  ) into recovery_codes_enabled;

  if not recovery_codes_enabled then return true; end if;

  -- Accept only passkey/WebAuthn methods asserted in the signed Supabase JWT.
  if jsonb_typeof(auth_methods) = 'array' and exists (
    select 1
    from jsonb_array_elements(auth_methods) as methods(value)
    where lower(coalesce(methods.value ->> 'method', methods.value #>> '{}'))
      in ('passkey', 'webauthn')
  ) then
    return true;
  end if;

  if coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2' then return true; end if;

  begin
    current_session_id := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  exception when others then
    return false;
  end;

  if current_session_id is null then return false; end if;

  return exists (
    select 1 from private.recovery_verified_sessions v
    where v.session_id = current_session_id
      and v.user_id = current_user_id
      and v.expires_at > pg_catalog.now()
  );
end;
$function$;
