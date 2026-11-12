# Education Books

The Education Dashboard includes a book authoring and management area at [Education Dashboard](https://huynhw19.github.io/Education-dashboard.html).

## Create and manage books

- Set a title and optional description.
- Add up to 50 chapters. Each chapter has a title and text body.
- Share with all linked students or select one student.
- Save as a draft, publish to the selected audience, or archive.
- Edit, publish/unpublish, archive, or delete a book from Manage books.

Published books appear in the linked student's Student Dashboard. Student accounts can only read published books that are shared with their linked student profile or the whole class.

## Database and privacy

The `education_books` table stores book metadata and chapter content as JSONB. Row-level security allows education account owners to manage their own books. Linked students can only select published books from their linked teacher and, where a book targets one student, only the matching student profile. Anonymous access is revoked.

Apply `supabase/migrations/20261112150000_create_education_books.sql` in any additional Supabase environment. The migration has been applied to the connected Supabase project.

Books are intended for text-based learning content. Do not include confidential student data or sensitive personal information in book content.
