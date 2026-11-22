create or replace function private.configkit_collab_session_access_allowed()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select private.email_2fa_access_allowed()
    or exists (
      select 1
      from jsonb_array_elements(coalesce((select auth.jwt() -> 'amr'), '[]'::jsonb)) as method
      where method ->> 'method' = any (array['magiclink','passkey','webauthn'])
    );
$$;

revoke all on function private.configkit_collab_session_access_allowed() from public, anon;
grant execute on function private.configkit_collab_session_access_allowed() to authenticated;

drop policy if exists configkit_collab_documents_verified_session_gate on public.configkit_collab_documents;
create policy configkit_collab_documents_verified_session_gate
on public.configkit_collab_documents as restrictive for all to authenticated
using ((select auth.jwt() ->> 'client_id') is null and (select private.configkit_collab_session_access_allowed()))
with check ((select auth.jwt() ->> 'client_id') is null and (select private.configkit_collab_session_access_allowed()));

drop policy if exists configkit_collab_members_verified_session_gate on public.configkit_collab_members;
create policy configkit_collab_members_verified_session_gate
on public.configkit_collab_members as restrictive for all to authenticated
using ((select auth.jwt() ->> 'client_id') is null and (select private.configkit_collab_session_access_allowed()))
with check ((select auth.jwt() ->> 'client_id') is null and (select private.configkit_collab_session_access_allowed()));

drop policy if exists configkit_collab_invites_verified_session_gate on public.configkit_collab_invites;
create policy configkit_collab_invites_verified_session_gate
on public.configkit_collab_invites as restrictive for all to authenticated
using ((select auth.jwt() ->> 'client_id') is null and (select private.configkit_collab_session_access_allowed()))
with check ((select auth.jwt() ->> 'client_id') is null and (select private.configkit_collab_session_access_allowed()));

drop policy if exists configkit_collab_updates_verified_session_gate on public.configkit_collab_updates;
create policy configkit_collab_updates_verified_session_gate
on public.configkit_collab_updates as restrictive for all to authenticated
using ((select auth.jwt() ->> 'client_id') is null and (select private.configkit_collab_session_access_allowed()))
with check ((select auth.jwt() ->> 'client_id') is null and (select private.configkit_collab_session_access_allowed()));

drop policy if exists configkit_collab_comments_verified_session_gate on public.configkit_collab_comments;
create policy configkit_collab_comments_verified_session_gate
on public.configkit_collab_comments as restrictive for all to authenticated
using ((select auth.jwt() ->> 'client_id') is null and (select private.configkit_collab_session_access_allowed()))
with check ((select auth.jwt() ->> 'client_id') is null and (select private.configkit_collab_session_access_allowed()));

drop policy if exists configkit_collab_snapshots_verified_session_gate on public.configkit_collab_snapshots;
create policy configkit_collab_snapshots_verified_session_gate
on public.configkit_collab_snapshots as restrictive for all to authenticated
using ((select auth.jwt() ->> 'client_id') is null and (select private.configkit_collab_session_access_allowed()))
with check ((select auth.jwt() ->> 'client_id') is null and (select private.configkit_collab_session_access_allowed()));
