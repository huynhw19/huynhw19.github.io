create or replace function private.configkit_collab_can_edit_topic(p_topic text)
returns boolean language plpgsql stable security definer set search_path = ''
as $$
declare v_document_id uuid;
begin
  if p_topic is null or p_topic !~ '^collab:[0-9a-fA-F-]{36}$' then return false; end if;
  begin v_document_id := pg_catalog.substr(p_topic, 8)::uuid;
  exception when others then return false;
  end;
  return private.configkit_collab_can_edit(v_document_id);
end;
$$;

revoke all on function private.configkit_collab_can_edit_topic(text) from public, anon;
grant execute on function private.configkit_collab_can_edit_topic(text) to authenticated;

drop policy if exists "ConfigKit collaborators can send private presence and broadcasts" on realtime.messages;
create policy "ConfigKit collaborators can send private presence and broadcasts"
on realtime.messages for insert to authenticated
with check (
  (extension = 'presence' and private.configkit_collab_can_access_topic(realtime.topic()))
  or (extension = 'broadcast' and private.configkit_collab_can_edit_topic(realtime.topic()))
);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='configkit_collab_comments'
  ) then
    alter publication supabase_realtime add table public.configkit_collab_comments;
  end if;
end;
$$;
