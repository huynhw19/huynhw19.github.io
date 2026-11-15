alter table public.education_students
  add column if not exists student_id text;

update public.education_students
   set student_id = 'CK-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))
 where student_id is null;

alter table public.education_students
  alter column student_id set not null;

create unique index if not exists education_students_student_id_key
  on public.education_students (student_id);

create or replace function public.assign_education_student_id()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.student_id is distinct from old.student_id then
    raise exception 'Student IDs cannot be changed after creation';
  end if;

  if new.student_id is null or btrim(new.student_id) = '' then
    loop
      new.student_id := 'CK-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
      exit when not exists (
        select 1 from public.education_students s where s.student_id = new.student_id
      );
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists assign_education_student_id on public.education_students;
create trigger assign_education_student_id
before insert or update of student_id on public.education_students
for each row execute function public.assign_education_student_id();

create or replace function public.link_education_student_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  account_email text;
  account_confirmed text;
  account_metadata jsonb;
  account_student_id text;
  account_user_id uuid;
begin
  if tg_table_schema = 'auth' and tg_table_name = 'users' then
    account_email := lower(btrim(coalesce(to_jsonb(new) ->> 'email', '')));
    account_confirmed := to_jsonb(new) ->> 'email_confirmed_at';
    account_metadata := coalesce(to_jsonb(new) -> 'raw_user_meta_data', '{}'::jsonb);
    account_student_id := upper(btrim(coalesce(account_metadata ->> 'configkit_student_id', '')));
    account_user_id := (to_jsonb(new) ->> 'id')::uuid;

    if account_email <> '' and account_confirmed is not null then
      if account_metadata ->> 'configkit_student_signup' = 'true' then
        update public.education_students
           set student_user_id = account_user_id
         where student_user_id is null
           and upper(student_id) = account_student_id
           and lower(btrim(student_email)) = account_email;
      else
        update public.education_students
           set student_user_id = account_user_id
         where student_user_id is null
           and lower(btrim(student_email)) = account_email;
      end if;
    end if;
  else
    account_email := lower(btrim(coalesce(to_jsonb(new) ->> 'student_email', '')));
    if account_email <> '' then
      update public.education_students as student
         set student_user_id = account.id
        from auth.users as account
       where student.ctid = new.ctid
         and student.student_user_id is null
         and lower(btrim(student.student_email)) = lower(btrim(account.email))
         and account.email_confirmed_at is not null
         and (
           coalesce(account.raw_user_meta_data ->> 'configkit_student_signup', 'false') <> 'true'
           or upper(student.student_id) =
             upper(btrim(coalesce(account.raw_user_meta_data ->> 'configkit_student_id', '')))
         );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists link_verified_auth_user_to_education_students on auth.users;
create trigger link_verified_auth_user_to_education_students
after insert or update of email, email_confirmed_at, raw_user_meta_data on auth.users
for each row execute function public.link_education_student_account();

revoke execute on function public.assign_education_student_id() from public, anon, authenticated;

revoke execute on function public.link_education_student_account() from public, anon, authenticated;
