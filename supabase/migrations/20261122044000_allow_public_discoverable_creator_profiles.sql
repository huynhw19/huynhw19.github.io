revoke all on table public.community_profiles from anon;
grant select (
  user_id, display_name, avatar_url, bio, is_discoverable, current_work,
  website_url, github_url, linkedin_url, x_url, instagram_url,
  youtube_url, facebook_url, updated_at
) on table public.community_profiles to anon;
drop policy if exists "Public can view discoverable creator profiles" on public.community_profiles;
create policy "Public can view discoverable creator profiles"
  on public.community_profiles for select to anon
  using (is_discoverable = true);
grant select (creator_id) on table public.configkit_templates to anon;
