-- Education data is never anonymous. RLS remains the row-level authorization layer.
revoke all on table
  public.education_students,
  public.education_assignments,
  public.education_slideshows,
  public.education_books,
  public.education_documents,
  public.education_tests,
  public.education_test_questions,
  public.education_test_answer_keys,
  public.education_test_attempts,
  public.education_test_responses
from anon, public;

grant select, insert, update, delete on table
  public.education_students,
  public.education_assignments,
  public.education_slideshows,
  public.education_books,
  public.education_documents,
  public.education_tests,
  public.education_test_questions,
  public.education_test_answer_keys,
  public.education_test_attempts,
  public.education_test_responses
to authenticated;

-- Require the verified email-2FA session for all Education data.
do $$
declare t text;
begin
  foreach t in array array[
    'education_students',
    'education_assignments',
    'education_slideshows',
    'education_books',
    'education_documents',
    'education_tests',
    'education_test_questions',
    'education_test_answer_keys',
    'education_test_attempts',
    'education_test_responses'
  ] loop
    execute format('drop policy if exists %I on public.%I','education_email_2fa_gate',t);
    execute format(
      'create policy %I on public.%I as restrictive for all to authenticated using (private.email_2fa_access_allowed()) with check (private.email_2fa_access_allowed())',
      'education_email_2fa_gate',t
    );
  end loop;
end $$;
