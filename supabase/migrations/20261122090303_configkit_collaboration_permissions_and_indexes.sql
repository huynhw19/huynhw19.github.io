create index if not exists configkit_collab_documents_owner_idx on public.configkit_collab_documents(owner_id);
create index if not exists configkit_collab_members_invited_by_idx on public.configkit_collab_members(invited_by);
create index if not exists configkit_collab_invites_invited_by_idx on public.configkit_collab_invites(invited_by);
create index if not exists configkit_collab_invites_accepted_by_idx on public.configkit_collab_invites(accepted_by);
create index if not exists configkit_collab_updates_user_idx on public.configkit_collab_updates(user_id);
create index if not exists configkit_collab_comments_user_idx on public.configkit_collab_comments(user_id);
create index if not exists configkit_collab_snapshots_user_idx on public.configkit_collab_snapshots(user_id);

revoke update on public.configkit_collab_documents from authenticated;
grant update(title,updated_at) on public.configkit_collab_documents to authenticated;
revoke update on public.configkit_collab_members from authenticated;
grant update(role) on public.configkit_collab_members to authenticated;
revoke update on public.configkit_collab_invites from authenticated;
grant update(revoked_at) on public.configkit_collab_invites to authenticated;
drop policy if exists "Authors and owners can edit collaboration comments" on public.configkit_collab_comments;
revoke update on public.configkit_collab_comments from authenticated;
