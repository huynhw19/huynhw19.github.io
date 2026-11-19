-- Tighten review ownership and add administrator-only review moderation and review reports.
drop policy if exists community_book_reviews_update_self on public.community_book_reviews;
create policy community_book_reviews_update_self on public.community_book_reviews for update to authenticated
using (user_id=(select auth.uid()))
with check (user_id=(select auth.uid()) and moderation_status='visible' and exists (
 select 1 from public.community_books b where b.id=book_id and b.status='published' and b.author_id<>(select auth.uid())
));
drop policy if exists community_book_reviews_admin_update on public.community_book_reviews;
create policy community_book_reviews_admin_update on public.community_book_reviews for update to authenticated
using ((select private.configkit_is_site_admin())) with check ((select private.configkit_is_site_admin()));

alter table public.community_book_reports alter column book_id drop not null;
alter table public.community_book_reports add column if not exists review_id uuid references public.community_book_reviews(id) on delete cascade;
alter table public.community_book_reports drop constraint if exists community_book_reports_target_check;
alter table public.community_book_reports add constraint community_book_reports_target_check
check ((book_id is null) <> (review_id is null));
drop policy if exists community_book_reports_insert_self on public.community_book_reports;
create policy community_book_reports_insert_self on public.community_book_reports for insert to authenticated
with check (
 reporter_id=(select auth.uid()) and status='open' and admin_note='' and
 ((book_id is not null and exists(select 1 from public.community_books b where b.id=book_id and b.status='published'))
  or
  (review_id is not null and exists(select 1 from public.community_book_reviews r join public.community_books b on b.id=r.book_id where r.id=review_id and r.moderation_status='visible' and b.status='published')))
);
