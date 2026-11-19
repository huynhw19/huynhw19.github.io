-- Community Book: curated author applications, publishing, reading, reviews and moderation.
-- The verified ConfigKit site owner is the sole editorial administrator.
create or replace function private.configkit_is_site_admin()
returns boolean
language sql stable security definer
set search_path = ''
as $function$
  select (select auth.uid()) = 'dc7d85d3-e40c-4002-87ea-8df7f904a3ed'::uuid;
$function$;
revoke all on function private.configkit_is_site_admin() from public, anon;
grant execute on function private.configkit_is_site_admin() to authenticated;

create table if not exists public.community_book_authors (
  user_id uuid primary key references auth.users(id) on delete cascade,
  pen_name text not null check (char_length(btrim(pen_name)) between 2 and 80),
  biography text not null check (char_length(btrim(biography)) between 20 and 1200),
  genres text[] not null default '{}'::text[] check (cardinality(genres) between 1 and 5),
  writing_sample text not null check (char_length(btrim(writing_sample)) between 100 and 5000),
  status text not null default 'pending' check (status in ('pending','approved','rejected','changes_requested','suspended')),
  admin_note text not null default '' check (char_length(admin_note) <= 1200),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null
);
alter table public.community_book_authors enable row level security;
drop policy if exists community_book_authors_insert_self on public.community_book_authors;
create policy community_book_authors_insert_self on public.community_book_authors for insert to authenticated
with check (user_id=(select auth.uid()) and status='pending' and admin_note='' and reviewed_at is null and reviewed_by is null);
drop policy if exists community_book_authors_read_self_or_admin on public.community_book_authors;
create policy community_book_authors_read_self_or_admin on public.community_book_authors for select to authenticated
using (user_id=(select auth.uid()) or (select private.configkit_is_site_admin()));
drop policy if exists community_book_authors_admin_update on public.community_book_authors;
create policy community_book_authors_admin_update on public.community_book_authors for update to authenticated
using ((select private.configkit_is_site_admin())) with check ((select private.configkit_is_site_admin()));
drop policy if exists community_book_authors_delete_pending_self on public.community_book_authors;
create policy community_book_authors_delete_pending_self on public.community_book_authors for delete to authenticated
using (user_id=(select auth.uid()) and status in ('pending','changes_requested'));
revoke all on public.community_book_authors from anon, public;
grant select,insert,delete on public.community_book_authors to authenticated;
grant update(status,admin_note,reviewed_at,reviewed_by) on public.community_book_authors to authenticated;

create table if not exists public.community_books (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 2 and 160),
  summary text not null default '' check (char_length(summary) <= 1800),
  genre text not null check (char_length(btrim(genre)) between 2 and 48),
  age_guidance text not null default 'General' check (age_guidance in ('General','Teen','Mature')),
  cover_url text not null default '' check (char_length(cover_url) <= 500),
  chapters jsonb not null default '[]'::jsonb
    check (jsonb_typeof(chapters)='array' and jsonb_array_length(chapters) between 1 and 80),
  status text not null default 'draft' check (status in ('draft','published','archived','removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  configkit_search_vector tsvector generated always as
    (setweight(to_tsvector('simple',coalesce(title,'')),'A') ||
     setweight(to_tsvector('simple',coalesce(summary,'')),'B') ||
     setweight(to_tsvector('simple',coalesce(genre,'')),'C')) stored
);
create index if not exists community_books_search_idx on public.community_books using gin(configkit_search_vector);
create index if not exists community_books_public_idx on public.community_books(status,updated_at desc);
create index if not exists community_books_author_idx on public.community_books(author_id,updated_at desc);
alter table public.community_books enable row level security;
drop policy if exists community_books_read_public_author_admin on public.community_books;
create policy community_books_read_public_author_admin on public.community_books for select to authenticated
using (status='published' or author_id=(select auth.uid()) or (select private.configkit_is_site_admin()));
drop policy if exists community_books_insert_approved_author on public.community_books;
create policy community_books_insert_approved_author on public.community_books for insert to authenticated
with check (author_id=(select auth.uid()) and status='draft' and exists (
  select 1 from public.community_book_authors a where a.user_id=(select auth.uid()) and a.status='approved'
));
drop policy if exists community_books_update_author_or_admin on public.community_books;
create policy community_books_update_author_or_admin on public.community_books for update to authenticated
using ((author_id=(select auth.uid()) and exists (select 1 from public.community_book_authors a where a.user_id=(select auth.uid()) and a.status='approved')) or (select private.configkit_is_site_admin()))
with check ((select private.configkit_is_site_admin()) or
  (author_id=(select auth.uid()) and status<>'removed' and exists (select 1 from public.community_book_authors a where a.user_id=(select auth.uid()) and a.status='approved')));
drop policy if exists community_books_delete_author_or_admin on public.community_books;
create policy community_books_delete_author_or_admin on public.community_books for delete to authenticated
using ((author_id=(select auth.uid()) and status in ('draft','archived')) or (select private.configkit_is_site_admin()));
revoke all on public.community_books from anon, public;
grant select,insert,update,delete on public.community_books to authenticated;

create table if not exists public.community_book_reviews (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.community_books(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  body text not null default '' check (char_length(body) <= 1600),
  moderation_status text not null default 'visible' check (moderation_status in ('visible','hidden')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(book_id,user_id)
);
create index if not exists community_book_reviews_book_idx on public.community_book_reviews(book_id,created_at desc);
alter table public.community_book_reviews enable row level security;
drop policy if exists community_book_reviews_read on public.community_book_reviews;
create policy community_book_reviews_read on public.community_book_reviews for select to authenticated
using ((select private.configkit_is_site_admin()) or (moderation_status='visible' and exists (select 1 from public.community_books b where b.id=book_id and b.status='published')));
drop policy if exists community_book_reviews_insert on public.community_book_reviews;
create policy community_book_reviews_insert on public.community_book_reviews for insert to authenticated
with check (user_id=(select auth.uid()) and moderation_status='visible' and exists (
  select 1 from public.community_books b where b.id=book_id and b.status='published' and b.author_id<>(select auth.uid())
));
drop policy if exists community_book_reviews_update_self on public.community_book_reviews;
create policy community_book_reviews_update_self on public.community_book_reviews for update to authenticated
using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()) and moderation_status='visible');
drop policy if exists community_book_reviews_delete_self_admin on public.community_book_reviews;
create policy community_book_reviews_delete_self_admin on public.community_book_reviews for delete to authenticated
using (user_id=(select auth.uid()) or (select private.configkit_is_site_admin()));
revoke all on public.community_book_reviews from anon, public;
grant select,insert,update,delete on public.community_book_reviews to authenticated;

create or replace function private.configkit_guard_book_review_moderation()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
 if new.moderation_status is distinct from old.moderation_status and not (select private.configkit_is_site_admin()) then
   raise exception 'Only ConfigKit administrators can moderate book reviews.';
 end if;
 return new;
end;
$function$;
drop trigger if exists community_book_review_moderation_guard on public.community_book_reviews;
create trigger community_book_review_moderation_guard before update on public.community_book_reviews
for each row execute function private.configkit_guard_book_review_moderation();

create table if not exists public.community_book_favourites (
  book_id uuid not null references public.community_books(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(book_id,user_id)
);
alter table public.community_book_favourites enable row level security;
drop policy if exists community_book_favourites_owner_all on public.community_book_favourites;
drop policy if exists community_book_favourites_read_self on public.community_book_favourites;
drop policy if exists community_book_favourites_insert_published on public.community_book_favourites;
drop policy if exists community_book_favourites_delete_self on public.community_book_favourites;
create policy community_book_favourites_read_self on public.community_book_favourites for select to authenticated
using (user_id=(select auth.uid()));
create policy community_book_favourites_insert_published on public.community_book_favourites for insert to authenticated
with check (user_id=(select auth.uid()) and exists(select 1 from public.community_books b where b.id=book_id and b.status='published'));
create policy community_book_favourites_delete_self on public.community_book_favourites for delete to authenticated
using (user_id=(select auth.uid()));
revoke all on public.community_book_favourites from anon, public;
grant select,insert,delete on public.community_book_favourites to authenticated;

create table if not exists public.community_book_reports (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.community_books(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (reason in ('copyright','unsafe','spam','harassment','other')),
  details text not null default '' check (char_length(details) <= 1200),
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  admin_note text not null default '' check (char_length(admin_note) <= 1200),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
alter table public.community_book_reports enable row level security;
drop policy if exists community_book_reports_insert_self on public.community_book_reports;
create policy community_book_reports_insert_self on public.community_book_reports for insert to authenticated
with check (reporter_id=(select auth.uid()) and status='open' and admin_note='' and exists(select 1 from public.community_books b where b.id=book_id and b.status='published'));
drop policy if exists community_book_reports_admin_all on public.community_book_reports;
create policy community_book_reports_admin_all on public.community_book_reports for all to authenticated
using ((select private.configkit_is_site_admin())) with check ((select private.configkit_is_site_admin()));
revoke all on public.community_book_reports from anon, public;
grant insert,select,update,delete on public.community_book_reports to authenticated;

-- Prevent OAuth client tokens and sessions failing the existing email/2FA gate from accessing new community tables.
do $block$
declare t text;
begin
 foreach t in array array['community_book_authors','community_books','community_book_reviews','community_book_favourites','community_book_reports'] loop
  execute format('drop policy if exists community_books_oauth_session_gate on public.%I',t);
  execute format('create policy community_books_oauth_session_gate on public.%I as restrictive for all to authenticated using ((auth.jwt()->>''client_id'' is null) and private.email_2fa_access_allowed()) with check ((auth.jwt()->>''client_id'' is null) and private.email_2fa_access_allowed())',t);
 end loop;
end;
$block$;
