create table if not exists public.education_slideshows (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 160),
  description text not null default '' check (char_length(description) <= 2000),
  slides jsonb not null default '[]'::jsonb
    check (jsonb_typeof(slides) = 'array' and jsonb_array_length(slides) <= 40),
  status text not null default 'draft' check (status in ('draft','published')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists education_slideshows_user_created_idx
  on public.education_slideshows (user_id, created_at desc);
alter table public.education_slideshows enable row level security;
drop policy if exists "Teachers manage their own slideshows" on public.education_slideshows;
create policy "Teachers manage their own slideshows"
  on public.education_slideshows for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
drop policy if exists "Linked students can view published slideshows" on public.education_slideshows;
create policy "Linked students can view published slideshows"
  on public.education_slideshows for select to authenticated
  using (
    status = 'published' and exists (
      select 1 from public.education_students student
      where student.student_user_id = (select auth.uid())
        and student.user_id = education_slideshows.user_id
    )
  );
grant select, insert, update, delete on public.education_slideshows to authenticated;
