-- A successfully verified AAL2 or recovery-code session must be sufficient
-- for collaboration. The JWT client_id claim is not an assurance signal and
-- can be present on legitimate browser sessions, so it must not override
-- the explicit session-verification gate.
drop policy if exists configkit_collab_documents_verified_session_gate on public.configkit_collab_documents;
create policy configkit_collab_documents_verified_session_gate
on public.configkit_collab_documents as restrictive for all to authenticated
using ((select private.configkit_collab_session_access_allowed()))
with check ((select private.configkit_collab_session_access_allowed()));

drop policy if exists configkit_collab_members_verified_session_gate on public.configkit_collab_members;
create policy configkit_collab_members_verified_session_gate
on public.configkit_collab_members as restrictive for all to authenticated
using ((select private.configkit_collab_session_access_allowed()))
with check ((select private.configkit_collab_session_access_allowed()));

drop policy if exists configkit_collab_invites_verified_session_gate on public.configkit_collab_invites;
create policy configkit_collab_invites_verified_session_gate
on public.configkit_collab_invites as restrictive for all to authenticated
using ((select private.configkit_collab_session_access_allowed()))
with check ((select private.configkit_collab_session_access_allowed()));

drop policy if exists configkit_collab_updates_verified_session_gate on public.configkit_collab_updates;
create policy configkit_collab_updates_verified_session_gate
on public.configkit_collab_updates as restrictive for all to authenticated
using ((select private.configkit_collab_session_access_allowed()))
with check ((select private.configkit_collab_session_access_allowed()));

drop policy if exists configkit_collab_comments_verified_session_gate on public.configkit_collab_comments;
create policy configkit_collab_comments_verified_session_gate
on public.configkit_collab_comments as restrictive for all to authenticated
using ((select private.configkit_collab_session_access_allowed()))
with check ((select private.configkit_collab_session_access_allowed()));

drop policy if exists configkit_collab_snapshots_verified_session_gate on public.configkit_collab_snapshots;
create policy configkit_collab_snapshots_verified_session_gate
on public.configkit_collab_snapshots as restrictive for all to authenticated
using ((select private.configkit_collab_session_access_allowed()))
with check ((select private.configkit_collab_session_access_allowed()));
