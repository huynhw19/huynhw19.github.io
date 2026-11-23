-- Education link changes revoke teacher access, but must not alter peer
-- friendships that were independently approved by both families.
create or replace function private.invalidate_kids_teacher_approvals_on_education_link_change()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  child_to_reset uuid;
begin
  if tg_op='UPDATE' and old.education_student_id is not distinct from new.education_student_id then
    return new;
  end if;

  child_to_reset:=old.child_id;
  delete from public.kids_teacher_contacts where child_id=child_to_reset;

  if tg_op='DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.invalidate_kids_teacher_approvals_on_education_link_change() from public,anon,authenticated;
