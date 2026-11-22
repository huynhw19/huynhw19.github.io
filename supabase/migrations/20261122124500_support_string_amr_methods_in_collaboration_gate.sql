create or replace function private.configkit_collab_session_access_allowed()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $function$
  select private.email_2fa_access_allowed()
    or exists (
      select 1
      from jsonb_array_elements(coalesce((select auth.jwt() -> 'amr'), '[]'::jsonb)) as method
      where lower(coalesce(method ->> 'method', method #>> '{}')) = any (array['magiclink','passkey','webauthn'])
    );
$function$;
