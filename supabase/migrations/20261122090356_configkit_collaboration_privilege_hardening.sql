revoke all on table
  public.configkit_collab_documents,
  public.configkit_collab_members,
  public.configkit_collab_invites,
  public.configkit_collab_updates,
  public.configkit_collab_comments,
  public.configkit_collab_snapshots
from anon, authenticated;

grant select, insert, delete on public.configkit_collab_documents to authenticated;
grant update(title,updated_at) on public.configkit_collab_documents to authenticated;
grant select, insert, delete on public.configkit_collab_members to authenticated;
grant update(role) on public.configkit_collab_members to authenticated;
grant select, insert, delete on public.configkit_collab_invites to authenticated;
grant update(revoked_at) on public.configkit_collab_invites to authenticated;
grant select, insert on public.configkit_collab_updates to authenticated;
grant select, insert, delete on public.configkit_collab_comments to authenticated;
grant select, insert, delete on public.configkit_collab_snapshots to authenticated;

revoke all on function private.configkit_collab_add_owner_member() from public, anon, authenticated;
revoke all on function private.configkit_collab_touch_document() from public, anon, authenticated;
