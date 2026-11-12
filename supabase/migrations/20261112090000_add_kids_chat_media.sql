-- Private media sharing for parent-approved Kids Messages conversations.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('kids-chat-media','kids-chat-media',false,15728640,array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm','video/quicktime'])
on conflict (id) do update set public=false,file_size_limit=15728640,allowed_mime_types=excluded.allowed_mime_types;

alter table public.kids_messages add column if not exists media_path text;
alter table public.kids_messages add column if not exists media_type text;
alter table public.kids_messages add column if not exists media_name text;

do $$ begin
  if not exists (select 1 from pg_constraint where conname='kids_messages_media_type_check') then
    alter table public.kids_messages add constraint kids_messages_media_type_check
      check (media_type is null or media_type in ('image','video'));
  end if;
end $$;

create policy "Kids can upload media to approved chats"
on storage.objects for insert to authenticated
with check (
  bucket_id='kids-chat-media'
  and array_length(storage.foldername(name),1)=2
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and (storage.foldername(name))[2] ~* '^[0-9a-f-]{36}$'
  and private.can_access_kids_friendship(((storage.foldername(name))[1])::uuid)
  and private.is_kids_child(((storage.foldername(name))[2])::uuid)
);

create policy "Kids can view media in approved chats"
on storage.objects for select to authenticated
using (
  bucket_id='kids-chat-media'
  and array_length(storage.foldername(name),1)=2
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and private.can_access_kids_friendship(((storage.foldername(name))[1])::uuid)
);
