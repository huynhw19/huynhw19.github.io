-- A removed Community Book is final for its author; only the site administrator can restore it.
drop policy if exists community_books_update_author_or_admin on public.community_books;
create policy community_books_update_author_or_admin on public.community_books for update to authenticated
using ((author_id=(select auth.uid()) and status<>'removed' and exists (
 select 1 from public.community_book_authors a where a.user_id=(select auth.uid()) and a.status='approved'
)) or (select private.configkit_is_site_admin()))
with check ((select private.configkit_is_site_admin()) or
 (author_id=(select auth.uid()) and status<>'removed' and exists (
  select 1 from public.community_book_authors a where a.user_id=(select auth.uid()) and a.status='approved'
 )));
