create index if not exists builder_discussions_creator_profile_idx
  on public.builder_discussions (user_id, created_at desc);
create index if not exists mobileconfig_posts_creator_profile_idx
  on public.mobileconfig_posts (user_id, created_at desc);
create index if not exists configkit_templates_creator_profile_idx
  on public.configkit_templates (creator_id, created_at desc)
  where status='published' and moderation_status='visible';
create index if not exists community_books_creator_profile_idx
  on public.community_books (author_id, updated_at desc)
  where status='published';
