# Community Book

Community Book is a signed-in, curated reading and publishing area for ConfigKit.

## Member experience

- Browse and search published books, filter by genre, and sort by recency or rating.
- Read chapters in the browser.
- Save books to a personal favourites/reading list.
- Leave one rating and review per book.
- Report books or reviews privately to the ConfigKit administrator. The administrator can hide a reported review or remove a reported book from public view.

## Author approval

- A member submits a private application containing a pen name, biography, genres and a writing sample.
- Only the registered ConfigKit site owner can approve, reject, request changes or suspend an author.
- Group owners and group moderators do not receive author-approval permissions.
- Only approved authors can create books. New books start as drafts.
- Approved authors can edit their own books, publish/unpublish and archive them.
- When approval is withdrawn, currently published books are automatically archived.
- Private application writing samples and administrator notes are never exposed through the public author-profile table.

The current site has a single registered owner identity used by `owner-control.html` and the database helper `private.configkit_is_site_admin()`. If ConfigKit later appoints additional administrators, expand this through a trusted server-managed admin-role system rather than editable profile metadata.

## Database and access control

Migrations:
- `20261119110000_create_community_book.sql`
- `20261119113000_add_community_books_to_universal_search.sql`
- `20261119120000_publish_approved_author_profiles.sql`
- `20261119123000_lock_removed_community_books.sql`
- `20261119130000_add_review_moderation_and_reports.sql`
- `20261119133000_gate_author_profile_access.sql`
- `20261119140000_unpublish_books_when_author_suspended.sql`
- `20261119133000_gate_author_profile_access.sql`
- `20261119140000_unpublish_books_when_author_suspended.sql`

All Community Book tables have RLS enabled. Anonymous table access is revoked. Authenticated access is subject to the existing ConfigKit email/2FA session gate and OAuth client restrictions. Author applications are private; public author details are stored separately. Book and review content is rendered as text, not trusted HTML.

Community Book is separate from `education_books`; classroom book visibility and existing student access rules are unchanged. It does not use payment or checkout integrations.

## Owner moderation

Open [Owner Control](https://huynhw19.github.io/owner-control.html) while signed in to the registered owner account to review applications and content reports. The page is noindex and checks the owner identity before displaying controls.

## Content guidance

Authors must publish work they have the right to share. Readers should report suspected copyright violations, unsafe material, spam or harassment. Applications, reports and admin notes should not contain passwords, recovery codes or other secrets.
