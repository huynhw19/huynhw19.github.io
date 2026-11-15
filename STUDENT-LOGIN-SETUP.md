# Student login and Student ID setup

Student IDs are generated automatically when a teacher creates a record in `Education-dashboard.html`. Each ID has the form `CK-` followed by 12 hexadecimal characters. The database enforces uniqueness and prevents IDs from being edited.

## Student workflow

1. A teacher signs in and adds the student with their name and email address.
2. The Education Dashboard displays the generated Student ID beside the record. The teacher can copy it with **Copy Student ID**.
3. The student opens [`student-login.html`](student-login.html), selects **Sign up**, chooses **Education account**, selects **I am a student**, and enters the Student ID.
4. The student signs up using the exact email address the teacher registered, then confirms that email.
5. Supabase links the account only when the confirmed email and Student ID both match the same unlinked student record.
6. The student signs in and opens [`student-dashboard.html`](student-dashboard.html).

The Student ID alone does not grant access. Email verification and the matching registered email are also required. Existing student records keep their existing student-account linking behavior when no Student ID signup intent is provided.

## Database

The migration `20261115090000_add_student_ids_and_secure_student_linking.sql` adds and backfills Student IDs, enforces uniqueness, generates IDs for new records, and updates the auth trigger to validate Student ID plus confirmed email for Student ID signups. It is already applied to the configured Supabase project.

## Notes

- Students create and control their own passwords. Teachers should never ask for or set a student's password.
- Email/password sign-up uses the repository's configured CAPTCHA integration; configure Supabase CAPTCHA and Turnstile as described in `CAPTCHA-SETUP.md`.
- Test with a teacher account and a separate student email before using this with real student data. Follow applicable school privacy and consent requirements.
