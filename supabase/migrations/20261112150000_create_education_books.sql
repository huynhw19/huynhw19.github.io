create table if not exists public.education_books (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  student_id uuid references public.education_students(id) on delete set null,
  title text not null check (char_length(btrim(title)) between 1 and 160),
  description text not null default '' check (char_length(description) <= 2000),
  chapters jsonb not null default '[]'::jsonb
    check (jsonb_typeof(chapters) = 'array' and jsonb_array_length(chapters) between 1 and 50),
  status text not null default 'draft' check (status in ('draft','published','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists education_books_user_updated_idx
  on public.education_books(user_id,updated_at desc);
create index if not exists education_books_student_status_idx
  on public.education_books(student_id,status);
alter table public.education_books enable row level security;
drop policy if exists "Teachers manage their own books" on public.education_books;
create policy "Teachers manage their own books"
  on public.education_books for all to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and (student_id is null or exists (
      select 1 from public.education_students s
      where s.id = education_books.student_id and s.user_id = (select auth.uid())
    ))
  );
drop policy if exists "Linked students can view published books" on public.education_books;
create policy "Linked students can view published books"
  on public.education_books for select to authenticated
  using (
    status = 'published' and exists (
      select 1 from public.education_students s
      where s.user_id = education_books.user_id
        and s.student_user_id = (select auth.uid())
        and (education_books.student_id is null or s.id = education_books.student_id)
    )
  );
grant select,insert,update,delete on public.education_books to authenticated;
revoke all on public.education_books from anon;
