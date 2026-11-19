-- Parent-controlled association between a family child profile and a teacher's Education student record.
create table if not exists public.kids_education_links (
 id uuid primary key default gen_random_uuid(),
 child_id uuid not null unique references public.family_children(id) on delete cascade,
 education_student_id uuid not null unique references public.education_students(id) on delete cascade,
 linked_by uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
create index if not exists kids_education_links_student_idx on public.kids_education_links(education_student_id);
create or replace function private.kids_is_linked_teacher(p_child_id uuid,p_teacher_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=''
as $$
 select exists(select 1 from public.kids_education_links l join public.education_students s on s.id=l.education_student_id where l.child_id=p_child_id and s.user_id=p_teacher_id);
$$;
create or replace function private.kids_can_view_education_link(p_child_id uuid,p_student_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
 select exists(select 1 from public.kids_education_links l join public.family_children c on c.id=l.child_id join public.education_students s on s.id=l.education_student_id where l.child_id=p_child_id and l.education_student_id=p_student_id and (c.parent_id=(select auth.uid()) or c.child_user_id=(select auth.uid()) or s.user_id=(select auth.uid())));
$$;
revoke all on function private.kids_is_linked_teacher(uuid,uuid),private.kids_can_view_education_link(uuid,uuid) from public,anon;
grant execute on function private.kids_is_linked_teacher(uuid,uuid),private.kids_can_view_education_link(uuid,uuid) to authenticated;
alter table public.kids_education_links enable row level security;
revoke all on public.kids_education_links from public,anon;
grant select on public.kids_education_links to authenticated;
create policy kids_education_links_related_read on public.kids_education_links for select to authenticated using(private.kids_can_view_education_link(child_id,education_student_id));
