drop policy if exists community_book_author_profiles_oauth_session_gate on public.community_book_author_profiles;
create policy community_book_author_profiles_oauth_session_gate on public.community_book_author_profiles as restrictive for all to authenticated
using ((auth.jwt()->>'client_id' is null) and private.email_2fa_access_allowed())
with check ((auth.jwt()->>'client_id' is null) and private.email_2fa_access_allowed());
