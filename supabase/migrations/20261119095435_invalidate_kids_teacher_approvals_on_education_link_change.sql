-- Remove stale teacher approvals whenever a parent changes or unlinks an Education record, including FK cascades.
create or replace function private.invalidate_kids_teacher_approvals_on_education_link_change()
returns trigger language plpgsql security definer set search_path=''
as $$
declare child_to_reset uuid;
begin
 if tg_op='UPDATE' and old.education_student_id is not distinct from new.education_student_id then return new; end if;
 child_to_reset:=old.child_id;
 delete from public.kids_teacher_contacts where child_id=child_to_reset;
 update public.kids_friendships set status='pending',teacher_approved_by=null,teacher_approved_at=null,updated_at=now()
 where status in ('approved','pending') and (child_a_id=child_to_reset or child_b_id=child_to_reset);
 if tg_op='DELETE' then return old; end if;
 return new;
end;
$$;
revoke all on function private.invalidate_kids_teacher_approvals_on_education_link_change() from public,anon,authenticated;
drop trigger if exists kids_education_link_invalidate_teacher_approvals on public.kids_education_links;
create trigger kids_education_link_invalidate_teacher_approvals after delete or update of education_student_id on public.kids_education_links for each row execute function private.invalidate_kids_teacher_approvals_on_education_link_change();
