# ConfigKit Education: Homework and Tests

The Education dashboard supports teacher-created homework/assignments and tests for linked students.

## Homework and assignments

The existing assignment workflow is the homework workflow. Teachers can choose a linked student, add a title and instructions, set an optional due date, save a draft, publish it to the student, move it back to draft, edit it, or delete it. Published homework appears in the student's dashboard under **My homework & assignments**.

## Tests and quizzes

Open [Education-dashboard.html](Education-dashboard.html) and use the **Create a test** section.

A teacher can:
- Assign a test to one linked student.
- Set a title, description, instructions, due date, optional time limit (1–240 minutes), and allowed attempts (1–5).
- Add up to 100 multiple-choice or short-answer questions.
- Set points for each question.
- Save as a draft, publish to the selected student, move to draft, or archive.
- Review submitted attempts and set marks/feedback for written answers.
- View automatic multiple-choice scores and final grades.

Multiple-choice responses are marked in Postgres, not in the browser. Short-answer questions are held for teacher review. Tests with attempts cannot have their questions or assigned student edited, and cannot be deleted; archive them and create a new version instead. A test with an active attempt cannot be unpublished or archived from the dashboard.

## Student experience

The [student-dashboard.html](student-dashboard.html) page shows published tests assigned to the signed-in student. Students can start or continue an attempt, save their answers, and submit. A time limit is also reflected in the test UI. Multiple-choice marks appear automatically; written answers show as awaiting teacher review until graded.

## Security model

The Supabase schema separates student-visible question content from private answer keys:

- `education_tests`: test settings and assignment target.
- `education_test_questions`: student-visible prompts, choices, point values, and ordering.
- `education_test_answer_keys`: teacher-only correct answers.
- `education_test_attempts`: attempt status, timestamps, score, and grading state.
- `education_test_responses`: submitted answers, automatic marks, and teacher marks/feedback.

RLS is enabled on every assessment table. Teachers can manage only tests attached to their own student records. Students can read only published tests attached to their linked student record and their own attempts/responses. Students cannot query answer keys. Attempt creation, automatic marking, and grade finalization use authenticated, owner-checked RPC functions; anonymous and OAuth-client access is denied. Email-2FA session checks are restrictive policies on assessment data and the existing homework assignment table.

Students cannot change automatic marks or teacher feedback. Student response edits are limited to the active attempt window; time-limited tests also check the deadline in RLS. Questions are locked after the first attempt begins to preserve assessment integrity.

## Supabase migration

The following migrations were applied to the connected Supabase project:

1. `education_homework_tests_and_secure_assessments`
2. `education_test_timer_and_integrity_guards`

The new tables have explicit `authenticated` grants and no `anon` table grants. No service-role key is used in browser code.

## Test checklist

Use separate teacher and student accounts to test:
1. Teacher creates a draft test with multiple-choice and short-answer questions.
2. Teacher publishes it to a linked student.
3. Student can see the test but cannot read the answer-key table.
4. Student saves, resumes, and submits an attempt.
5. Multiple-choice marks are computed server-side.
6. Teacher reviews and grades written answers.
7. Student sees final score and teacher feedback.
8. A user not linked to the assigned student cannot read the test, questions, attempts, or responses.
9. Anonymous requests cannot access the new tables or RPC functions.

The repository JavaScript was syntax-checked after the changes. A full browser-based test with two real accounts is still required to verify all user flows end-to-end.
