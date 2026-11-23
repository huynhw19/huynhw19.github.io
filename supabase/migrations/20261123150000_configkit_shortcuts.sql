create table if not exists public.configkit_shortcuts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 100),
  description text not null default '' check (char_length(description) <= 500),
  kind text not null default 'link' check (kind in ('link','apple_recipe')),
  url text,
  icon text not null default '↗' check (char_length(icon) between 1 and 8),
  color text not null default '#226b51' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  category text not null default 'General' check (char_length(category) between 1 and 40),
  folder text not null default 'My shortcuts' check (char_length(folder) between 1 and 60),
  is_favorite boolean not null default false,
  sort_order integer not null default 0,
  recipe jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint configkit_shortcuts_kind_payload_check check (
    (kind = 'link' and url is not null and url ~* '^(https?://|mailto:|tel:)')
    or (kind = 'apple_recipe' and url is null)
  )
);
create index if not exists configkit_shortcuts_user_order_idx on public.configkit_shortcuts(user_id, sort_order, created_at desc);
create index if not exists configkit_shortcuts_user_kind_idx on public.configkit_shortcuts(user_id, kind, is_favorite);
alter table public.configkit_shortcuts enable row level security;
revoke all on public.configkit_shortcuts from public, anon, authenticated;
grant select, insert, update, delete on public.configkit_shortcuts to authenticated;
drop policy if exists "Users manage their own ConfigKit shortcuts" on public.configkit_shortcuts;
create policy "Users manage their own ConfigKit shortcuts" on public.configkit_shortcuts
for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists "ConfigKit shortcuts require verified session" on public.configkit_shortcuts;
create policy "ConfigKit shortcuts require verified session" on public.configkit_shortcuts
as restrictive for all to authenticated using (private.email_2fa_access_allowed()) with check (private.email_2fa_access_allowed());
drop policy if exists "ConfigKit shortcuts block OAuth client tokens" on public.configkit_shortcuts;
create policy "ConfigKit shortcuts block OAuth client tokens" on public.configkit_shortcuts
as restrictive for all to authenticated using ((select auth.jwt() ->> 'client_id') is null) with check ((select auth.jwt() ->> 'client_id') is null);
