alter table public.configkit_shortcuts
  add column if not exists is_shared boolean not null default false,
  add column if not exists share_token uuid;
create unique index if not exists configkit_shortcuts_share_token_uidx
  on public.configkit_shortcuts(share_token) where share_token is not null;
alter table public.configkit_shortcuts
  drop constraint if exists configkit_shortcuts_share_state_check;
alter table public.configkit_shortcuts
  add constraint configkit_shortcuts_share_state_check
  check ((is_shared = true and share_token is not null and kind = 'apple_recipe') or (is_shared = false and share_token is null));
grant select on public.configkit_shortcuts to anon;
drop policy if exists "Public can view explicitly shared Apple recipes" on public.configkit_shortcuts;
create policy "Public can view explicitly shared Apple recipes"
on public.configkit_shortcuts for select to anon
using (kind = 'apple_recipe' and is_shared = true and share_token is not null);
