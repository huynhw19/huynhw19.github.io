create table if not exists public.family_kids_resources (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid not null references auth.users(id) on delete cascade,
  child_id uuid not null references public.family_children(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 160),
  description text not null default '' check (char_length(description) <= 2000),
  resource_type text not null check (resource_type in ('website','video','book','worksheet','activity')),
  subject text not null default '' check (char_length(subject) <= 80),
  age_group text not null default '' check (age_group in ('','3-5','6-8','9-10','11-13','14-17')),
  resource_url text,
  status text not null default 'draft' check (status in ('draft','published','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint family_kids_resources_https_url check (resource_url is null or resource_url ~ '^https://')
);
create index if not exists family_kids_resources_child_status_idx on public.family_kids_resources(child_id,status,created_at desc);
create index if not exists family_kids_resources_parent_idx on public.family_kids_resources(parent_id,created_at desc);
alter table public.family_kids_resources enable row level security;
create policy "Parents and assigned children can view kids resources" on public.family_kids_resources for select to authenticated using (exists(select 1 from public.family_children c where c.id=family_kids_resources.child_id and c.parent_id=family_kids_resources.parent_id and (c.parent_id=(select auth.uid()) or (c.child_user_id=(select auth.uid()) and family_kids_resources.status='published'))));
create policy "Parents can create kids resources" on public.family_kids_resources for insert to authenticated with check (parent_id=(select auth.uid()) and exists(select 1 from public.family_children c where c.id=family_kids_resources.child_id and c.parent_id=(select auth.uid())));
create policy "Parents can update kids resources" on public.family_kids_resources for update to authenticated using (parent_id=(select auth.uid()) and exists(select 1 from public.family_children c where c.id=family_kids_resources.child_id and c.parent_id=(select auth.uid()))) with check (parent_id=(select auth.uid()) and exists(select 1 from public.family_children c where c.id=family_kids_resources.child_id and c.parent_id=(select auth.uid())));
create policy "Parents can delete kids resources" on public.family_kids_resources for delete to authenticated using (parent_id=(select auth.uid()) and exists(select 1 from public.family_children c where c.id=family_kids_resources.child_id and c.parent_id=(select auth.uid())));
grant select,insert,update,delete on public.family_kids_resources to authenticated;
revoke all on public.family_kids_resources from anon;
