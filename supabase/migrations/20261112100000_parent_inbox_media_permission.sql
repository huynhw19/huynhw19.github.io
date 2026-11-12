-- Parent inbox media-sharing permission.
-- New child profiles default to media sharing off until a parent enables it.
alter table public.family_children
  add column if not exists media_sharing_enabled boolean not null default false;

drop policy if exists "Kids can upload media to approved chats" on storage.objects;
create policy "Kids can upload media to approved chats"
on storage.objects for insert to authenticated
with check (
  bucket_id='kids-chat-media'
  and array_length(storage.foldername(name),1)=2
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and (storage.foldername(name))[2] ~* '^[0-9a-f-]{36}$'
  and private.can_access_kids_friendship(((storage.foldername(name))[1])::uuid)
  and private.is_kids_child(((storage.foldername(name))[2])::uuid)
  and exists (
    select 1
    from public.family_children c
    where c.id=((storage.foldername(name))[2])::uuid
      and c.media_sharing_enabled=true
  )
);
