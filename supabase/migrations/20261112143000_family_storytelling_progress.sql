create table if not exists public.family_storytelling_progress (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.family_children(id) on delete cascade,
  content_type text not null check (content_type in ('story','activity')),
  content_id integer not null check (content_id between 1 and 5000),
  content_title text not null,
  age_band text not null check (age_band in ('3-5','6-8','9-10')),
  completed boolean not null default false,
  favourite boolean not null default false,
  ending text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (child_id, content_type, content_id)
);

alter table public.family_storytelling_progress enable row level security;

drop policy if exists "Parents can view children's storytelling progress" on public.family_storytelling_progress;
create policy "Parents can view children's storytelling progress"
on public.family_storytelling_progress
for select to authenticated
using (
  exists (
    select 1 from public.family_children c
    where c.id = family_storytelling_progress.child_id
      and c.parent_id = (select auth.uid())
  )
);

drop policy if exists "Family members can save storytelling progress" on public.family_storytelling_progress;
create policy "Family members can save storytelling progress"
on public.family_storytelling_progress
for insert to authenticated
with check (
  exists (
    select 1 from public.family_children c
    where c.id = family_storytelling_progress.child_id
      and (c.child_user_id = (select auth.uid()) or c.parent_id = (select auth.uid()))
  )
);

drop policy if exists "Family members can update storytelling progress" on public.family_storytelling_progress;
create policy "Family members can update storytelling progress"
on public.family_storytelling_progress
for update to authenticated
using (
  exists (
    select 1 from public.family_children c
    where c.id = family_storytelling_progress.child_id
      and (c.child_user_id = (select auth.uid()) or c.parent_id = (select auth.uid()))
  )
)
with check (
  exists (
    select 1 from public.family_children c
    where c.id = family_storytelling_progress.child_id
      and (c.child_user_id = (select auth.uid()) or c.parent_id = (select auth.uid()))
  )
);

grant select, insert, update on public.family_storytelling_progress to authenticated;
revoke all on public.family_storytelling_progress from anon;
create index if not exists family_storytelling_progress_parent_lookup_idx
  on public.family_storytelling_progress(child_id, updated_at desc);
