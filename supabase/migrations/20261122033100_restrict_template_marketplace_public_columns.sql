revoke select on table public.configkit_templates from anon;
grant select (id,creator_name,title,description,category,template_format,file_name,template_content,tags,status,moderation_status,download_count,is_official,created_at,updated_at)
  on table public.configkit_templates to anon;
grant select on table public.configkit_templates to authenticated;
