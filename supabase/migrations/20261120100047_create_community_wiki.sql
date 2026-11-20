-- ConfigKit Community Wiki: public reading, signed-in authoring, owner moderation.
create table if not exists public.community_wiki_pages (
 id uuid primary key default gen_random_uuid(), author_id uuid not null references auth.users(id) on delete cascade,
 title text not null check(char_length(btrim(title)) between 4 and 140),
 slug text not null unique check(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) between 4 and 180),
 summary text not null default '' check(char_length(summary)<=500),
 category text not null default 'General' check(char_length(btrim(category)) between 2 and 48),
 content text not null check(char_length(btrim(content)) between 80 and 30000),
 status text not null default 'published' check(status in ('draft','published','archived','removed')),
 moderation_status text not null default 'visible' check(moderation_status in ('visible','hidden')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), published_at timestamptz default now(),
 configkit_search_vector tsvector generated always as (
  setweight(to_tsvector('simple',coalesce(title,'')),'A') ||
  setweight(to_tsvector('simple',coalesce(summary,'')),'B') ||
  setweight(to_tsvector('simple',coalesce(category,'')),'C') ||
  setweight(to_tsvector('simple',coalesce(content,'')),'D')
 ) stored
);
create index if not exists community_wiki_pages_search_idx on public.community_wiki_pages using gin(configkit_search_vector);
create index if not exists community_wiki_pages_public_idx on public.community_wiki_pages(status,moderation_status,published_at desc);
create index if not exists community_wiki_pages_author_idx on public.community_wiki_pages(author_id,updated_at desc);
alter table public.community_wiki_pages enable row level security;
drop policy if exists community_wiki_pages_public_read on public.community_wiki_pages;
drop policy if exists community_wiki_pages_anon_read on public.community_wiki_pages;
create policy community_wiki_pages_anon_read on public.community_wiki_pages for select to anon using(status='published' and moderation_status='visible');
drop policy if exists community_wiki_pages_authenticated_read on public.community_wiki_pages;
create policy community_wiki_pages_authenticated_read on public.community_wiki_pages for select to authenticated using((status='published' and moderation_status='visible') or (select auth.uid())=author_id or (select private.configkit_is_site_admin()));
drop policy if exists community_wiki_pages_author_insert on public.community_wiki_pages;
create policy community_wiki_pages_author_insert on public.community_wiki_pages for insert to authenticated with check(author_id=(select auth.uid()) and moderation_status='visible' and status in('draft','published') and (status<>'published' or published_at is not null));
drop policy if exists community_wiki_pages_author_update on public.community_wiki_pages;
create policy community_wiki_pages_author_update on public.community_wiki_pages for update to authenticated using(author_id=(select auth.uid()) and status in('draft','published','archived') and moderation_status='visible') with check(author_id=(select auth.uid()) and status in('draft','published','archived') and moderation_status='visible');
drop policy if exists community_wiki_pages_admin_update on public.community_wiki_pages;
create policy community_wiki_pages_admin_update on public.community_wiki_pages for update to authenticated using((select private.configkit_is_site_admin())) with check((select private.configkit_is_site_admin()));
drop policy if exists community_wiki_pages_author_delete on public.community_wiki_pages;
create policy community_wiki_pages_author_delete on public.community_wiki_pages for delete to authenticated using(author_id=(select auth.uid()) and status in('draft','archived'));
revoke all on public.community_wiki_pages from public,anon,authenticated;
grant select on public.community_wiki_pages to anon,authenticated;
grant insert,delete on public.community_wiki_pages to authenticated;
grant update(title,slug,summary,category,content,status,updated_at,published_at) on public.community_wiki_pages to authenticated;
grant update(status,moderation_status,updated_at) on public.community_wiki_pages to authenticated;

create table if not exists public.community_wiki_reports (
 id uuid primary key default gen_random_uuid(), page_id uuid not null references public.community_wiki_pages(id) on delete cascade,
 reporter_id uuid not null references auth.users(id) on delete cascade,
 reason text not null check(reason in('unsafe','spam','harassment','copyright','misinformation','other')),
 details text not null default '' check(char_length(details)<=1200),
 status text not null default 'open' check(status in('open','reviewing','resolved','dismissed')),
 admin_note text not null default '' check(char_length(admin_note)<=1200),
 created_at timestamptz not null default now(), resolved_at timestamptz, unique(page_id,reporter_id)
);
create index if not exists community_wiki_reports_queue_idx on public.community_wiki_reports(status,created_at desc);
alter table public.community_wiki_reports enable row level security;
drop policy if exists community_wiki_reports_insert_self on public.community_wiki_reports;
create policy community_wiki_reports_insert_self on public.community_wiki_reports for insert to authenticated with check(reporter_id=(select auth.uid()) and status='open' and admin_note='' and resolved_at is null and exists(select 1 from public.community_wiki_pages p where p.id=page_id and p.status='published' and p.moderation_status='visible'));
drop policy if exists community_wiki_reports_read_reporter_admin on public.community_wiki_reports;
create policy community_wiki_reports_read_reporter_admin on public.community_wiki_reports for select to authenticated using(reporter_id=(select auth.uid()) or (select private.configkit_is_site_admin()));
drop policy if exists community_wiki_reports_admin_update on public.community_wiki_reports;
create policy community_wiki_reports_admin_update on public.community_wiki_reports for update to authenticated using((select private.configkit_is_site_admin())) with check((select private.configkit_is_site_admin()));
revoke all on public.community_wiki_reports from public,anon,authenticated;
grant select,insert on public.community_wiki_reports to authenticated;
grant update(status,admin_note,resolved_at) on public.community_wiki_reports to authenticated;

create or replace function private.community_wiki_touch_updated_at() returns trigger language plpgsql set search_path='' as $$
begin new.updated_at:=now(); if new.status='published' and old.status<>'published' then new.published_at:=now(); end if; return new; end;
$$;
revoke all on function private.community_wiki_touch_updated_at() from public,anon,authenticated;
drop trigger if exists community_wiki_pages_touch_updated_at on public.community_wiki_pages;
create trigger community_wiki_pages_touch_updated_at before update on public.community_wiki_pages for each row execute function private.community_wiki_touch_updated_at();
comment on table public.community_wiki_pages is 'Community-authored ConfigKit wiki articles. Public reads are limited to published, visible articles.';
comment on table public.community_wiki_reports is 'Private member reports for Community Wiki articles; only reporter and ConfigKit site admin can read.';
