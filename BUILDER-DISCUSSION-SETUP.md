# Set up the builder discussion

The discussion page is available to signed-in users and stores posts/comments in the Supabase project used for OAuth. It requires the public Supabase URL/key in `auth-config.js` and the schema below. Do not put a service-role key in browser code.

## Create the tables

In the Supabase SQL Editor, run:

```sql
create table if not exists public.builder_discussions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  body text not null check (char_length(body) between 1 and 5000),
  created_at timestamptz not null default now()
);

create table if not exists public.builder_discussion_comments (
  id uuid primary key default gen_random_uuid(),
  discussion_id uuid not null references public.builder_discussions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);

alter table public.builder_discussions enable row level security;
alter table public.builder_discussion_comments enable row level security;

grant select, insert on public.builder_discussions to authenticated;
grant select, insert on public.builder_discussion_comments to authenticated;

create policy "Signed-in users can read discussions"
  on public.builder_discussions for select to authenticated using (true);
create policy "Users can create discussions as themselves"
  on public.builder_discussions for insert to authenticated with check (auth.uid() = user_id);
create policy "Signed-in users can read comments"
  on public.builder_discussion_comments for select to authenticated using (true);
create policy "Users can comment as themselves"
  on public.builder_discussion_comments for insert to authenticated with check (
    auth.uid() = user_id and exists (
      select 1 from public.builder_discussions d where d.id = discussion_id
    )
  );
```

Then deploy the site and sign in. The account panel on `login.html` will show an **Open builder discussion** link. Signed-in users can start discussions, comment, and refresh to see new activity. For moderation, review Supabase's dashboard and consider adding admin-only removal policies before opening the feature broadly.
