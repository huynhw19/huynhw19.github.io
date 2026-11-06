# Student login setup

This adds student sign-in to the existing education-student records. It does **not** create passwords for students: students create and control their own account using the email address their teacher entered. A verified email is required before a student record is linked.

## 1. Apply the database changes

Run this SQL in the Supabase SQL Editor for the same project configured in `auth-config.js`. It assumes the existing `public.education_students` table has the `student_email` field used by `Education-dashboard.html` and has RLS enabled or can have it enabled.

```sql
alter table public.education_students
  add column if not exists student_user_id uuid references auth.users(id) on delete set null;

create or replace function public.link_education_student_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  account_email text;
  account_confirmed text;
begin
  if tg_table_schema = 'auth' and tg_table_name = 'users' then
    account_email := lower(btrim(coalesce(to_jsonb(new) ->> 'email', '')));
    account_confirmed := to_jsonb(new) ->> 'email_confirmed_at';
    if account_email <> '' and account_confirmed is not null then
      update public.education_students
         set student_user_id = (to_jsonb(new) ->> 'id')::uuid
       where student_user_id is null
         and lower(btrim(student_email)) = account_email;
    end if;
  else
    account_email := lower(btrim(coalesce(to_jsonb(new) ->> 'student_email', '')));
    if account_email <> '' then
      update public.education_students as student
         set student_user_id = account.id
        from auth.users as account
       where student.ctid = new.ctid
         and student.student_user_id is null
         and lower(btrim(student.student_email)) = account_email
         and account.email_confirmed_at is not null
         and lower(btrim(account.email)) = account_email;
    end if;
  end if;
  return new;
end;
$$;

 drop trigger if exists link_verified_auth_user_to_education_students on auth.users;
create trigger link_verified_auth_user_to_education_students
  after insert or update of email, email_confirmed_at on auth.users
  for each row execute function public.link_education_student_account();

drop trigger if exists link_education_student_to_existing_auth_user on public.education_students;
create trigger link_education_student_to_existing_auth_user
  after insert or update of student_email on public.education_students
  for each row execute function public.link_education_student_account();

alter table public.education_students enable row level security;
drop policy if exists "Students can read their linked education records" on public.education_students;
create policy "Students can read their linked education records"
  on public.education_students
  for select
  to authenticated
  using (student_user_id = (select auth.uid()));
```

The trigger links only confirmed accounts and does not change `user_id` (the teacher/record owner field used by the existing teacher dashboard). The new `student_user_id` is the separate student account link. Existing teacher policies should remain in place. If you intentionally allow teachers to see student notes, keep those policies restricted to the owning teacher.

## 2. Student workflow

1. A teacher signs in and adds the student on `Education-dashboard.html` using the student's email address.
2. The student opens [`student-login.html`](student-login.html), selects **Sign up** on the standard login page, and registers with that same email.
3. The student follows the email confirmation link. The database trigger links their verified account to the teacher-created record.
4. The student signs in and opens [`student-dashboard.html`](student-dashboard.html) to view their name, school, and grade. They can also use the normal ConfigKit dashboard.

Students with an existing verified account for the entered email are linked when the teacher creates the student record. Email addresses must match exactly apart from letter case and surrounding spaces. A teacher should never ask for or set a student's password.

## Notes

- Email/password sign-up on `login.html` uses the repository's configured CAPTCHA integration; configure Supabase CAPTCHA and Turnstile as described in `CAPTCHA-SETUP.md`.
- The student page queries only the student's own linked rows. The added RLS policy is essential; do not rely on client-side filtering alone.
- Test with a teacher account and a separate student email before using this with real student data. Follow applicable school privacy and consent requirements.
