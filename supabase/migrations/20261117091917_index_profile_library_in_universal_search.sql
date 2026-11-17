-- Add private Profile Library items to Universal Search. SECURITY INVOKER preserves the caller's RLS policies.
create or replace function public.configkit_universal_search(p_query text,p_category text default null,p_limit integer default 40)
returns table(id text,category text,title text,description text,href text,updated_at timestamptz,relevance real)
language sql stable security invoker set search_path = ''
as $function$
with input as (
 select pg_catalog.websearch_to_tsquery('simple',pg_catalog.left(pg_catalog.btrim(coalesce(p_query,'')),120)) as query
), matches as (
 select a.id::text,'app'::text as category,a.name::text as title,pg_catalog.left(coalesce(a.description,''),260)::text as description,'configkit-app-store.html'::text as href,a.updated_at,pg_catalog.ts_rank_cd(a.configkit_search_vector,i.query) as relevance from public.configkit_apps a cross join input i where a.configkit_search_vector @@ i.query
 union all
 select t.id::text,'tool',t.name,pg_catalog.left(coalesce(t.summary,t.description,''),260),'community-tools.html',t.updated_at,pg_catalog.ts_rank_cd(t.configkit_search_vector,i.query) from public.configkit_tools t cross join input i where t.configkit_search_vector @@ i.query
 union all
 select p.user_id::text,'profile',p.display_name,pg_catalog.left(coalesce(p.bio,p.current_work,''),260),'community.html',p.updated_at,pg_catalog.ts_rank_cd(p.configkit_search_vector,i.query) from public.community_profiles p cross join input i where p.configkit_search_vector @@ i.query
 union all
 select d.id::text,'discussion',d.title,pg_catalog.left(coalesce(d.body,''),260),'builder-discussion.html',d.created_at,pg_catalog.ts_rank_cd(d.configkit_search_vector,i.query) from public.builder_discussions d cross join input i where d.configkit_search_vector @@ i.query
 union all
 select m.id::text,'profile-post',m.title,pg_catalog.left(coalesce(m.description,m.filename,''),260),'community.html',m.created_at,pg_catalog.ts_rank_cd(m.configkit_search_vector,i.query) from public.mobileconfig_posts m cross join input i where m.configkit_search_vector @@ i.query
 union all
 select v.id::text,'video',v.title,pg_catalog.left(coalesce(v.description,''),260),'video-studio.html',v.updated_at,pg_catalog.ts_rank_cd(v.configkit_search_vector,i.query) from public.configkit_videos v cross join input i where v.configkit_search_vector @@ i.query
 union all
 select g.id::text,'group',g.name,'ConfigKit group','groups.html',g.created_at,pg_catalog.ts_rank_cd(g.configkit_search_vector,i.query) from public.configkit_groups g cross join input i where g.configkit_search_vector @@ i.query
 union all
 select e.id::text,'event',e.title,pg_catalog.left(pg_catalog.concat_ws(' · ',e.description,e.location),260),'events.html',e.updated_at,pg_catalog.ts_rank_cd(e.configkit_search_vector,i.query) from public.community_events e cross join input i where e.configkit_search_vector @@ i.query
 union all
 select game.id::text,'game',game.title,pg_catalog.left(pg_catalog.concat_ws(' · ',game.description,game.category),260),'community-games.html',game.updated_at,pg_catalog.ts_rank_cd(game.configkit_search_vector,i.query) from public.community_games game cross join input i where game.configkit_search_vector @@ i.query
 union all
 select b.id::text,'book',b.title,pg_catalog.left(coalesce(b.description,''),260),'Education-dashboard.html',b.updated_at,pg_catalog.ts_rank_cd(b.configkit_search_vector,i.query) from public.education_books b cross join input i where b.configkit_search_vector @@ i.query
 union all
 select d.id::text,'document',d.title,pg_catalog.left(coalesce(d.content,''),260),'Education-dashboard.html',d.updated_at,pg_catalog.ts_rank_cd(d.configkit_search_vector,i.query) from public.education_documents d cross join input i where d.configkit_search_vector @@ i.query
 union all
 select s.id::text,'slideshow',s.title,pg_catalog.left(coalesce(s.description,''),260),'Education-dashboard.html',s.updated_at,pg_catalog.ts_rank_cd(s.configkit_search_vector,i.query) from public.education_slideshows s cross join input i where s.configkit_search_vector @@ i.query
 union all
 select f.id::text,'file',f.name,pg_catalog.concat_ws(' · ',f.mime_type,pg_catalog.pg_size_pretty(f.size_bytes)),'drive.html',f.updated_at,pg_catalog.ts_rank_cd(f.configkit_search_vector,i.query) from public.drive_items f cross join input i where f.item_type='file' and f.deleted_at is null and f.configkit_search_vector @@ i.query
 union all
 select s.id::text,'saved-profile',s.profile_name,pg_catalog.concat_ws(' · ',s.filename,s.tool),'dashboard.html#saved-profiles',s.created_at,pg_catalog.ts_rank_cd(s.configkit_search_vector,i.query) from public.saved_profiles s cross join input i where s.configkit_search_vector @@ i.query
 union all
 select item.id::text,'store-item',item.title,pg_catalog.left(pg_catalog.concat_ws(' · ',item.description,item.category),260),'community-store.html',item.updated_at,pg_catalog.ts_rank_cd(item.configkit_search_vector,i.query) from public.community_store_items item cross join input i where item.configkit_search_vector @@ i.query
 union all
 select gp.id::text,'group-resource',gp.title,pg_catalog.left(pg_catalog.concat_ws(' · ',gp.description,gp.filename),260),'groups.html',gp.updated_at,pg_catalog.ts_rank_cd(gp.configkit_search_vector,i.query) from public.configkit_group_profiles gp cross join input i where gp.configkit_search_vector @@ i.query
 union all
 select gc.id::text,'group-comment',gp.title,pg_catalog.left(gc.body,260),'groups.html',gc.created_at,pg_catalog.ts_rank_cd(gc.configkit_search_vector,i.query) from public.configkit_group_comments gc join public.configkit_group_profiles gp on gp.id=gc.profile_id cross join input i where gc.configkit_search_vector @@ i.query
 union all
 select p.id::text,'library-profile',p.name,pg_catalog.left(coalesce(p.description,''),260),'profile-library.html',p.updated_at,pg_catalog.ts_rank_cd(p.configkit_search_vector,i.query) from public.configkit_profiles p cross join input i where p.configkit_search_vector @@ i.query
)
select m.id,m.category,m.title,m.description,m.href,m.updated_at,m.relevance
from matches m cross join input i
where pg_catalog.numnode(i.query)>0 and (p_category is null or p_category='all' or m.category=p_category)
order by m.relevance desc,m.updated_at desc nulls last
limit least(greatest(coalesce(p_limit,40),1),50);
$function$;
revoke all on function public.configkit_universal_search(text,text,integer) from public,anon;
grant execute on function public.configkit_universal_search(text,text,integer) to authenticated;
