create or replace function private.configkit_collab_session_access_allowed()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $function$
  with claims as (
    select auth.jwt() as jwt
  ),
  methods as (
    select lower(coalesce(entry ->> 'method', entry #>> '{}')) as method
    from claims
    cross join lateral jsonb_array_elements(
      case
        when jsonb_typeof(claims.jwt -> 'amr') = 'array'
          then claims.jwt -> 'amr'
        else '[]'::jsonb
      end
    ) as entry
    union all
    select lower(coalesce(entry ->> 'method', entry #>> '{}')) as method
    from claims
    cross join lateral jsonb_array_elements(
      case
        when jsonb_typeof(claims.jwt -> 'amr_methods') = 'array'
          then claims.jwt -> 'amr_methods'
        when jsonb_typeof(claims.jwt -> 'amr_methods') = 'string'
          then jsonb_build_array(claims.jwt -> 'amr_methods')
        else '[]'::jsonb
      end
    ) as entry
  )
  select private.email_2fa_access_allowed()
    or exists (
      select 1
      from methods
      where method = any (array['magiclink', 'passkey', 'webauthn'])
    );
$function$;
