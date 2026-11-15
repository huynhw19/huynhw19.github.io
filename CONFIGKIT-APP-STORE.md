# ConfigKit App Store

The App Store is available at [configkit-app-store.html](https://huynhw19.github.io/configkit-app-store.html) and from the main [dashboard](https://huynhw19.github.io/dashboard.html).

## Features

- Browse published apps and filter by iOS, Android, Windows, macOS, Linux, or web. The page preselects a detected operating system when the browser exposes one.
- Search by app name and description and filter by category.
- Publish an app as a file upload or an HTTPS redirect link.
- Save new listings as drafts, then publish, unpublish, archive, edit, or delete them.
- Keep uploaded files in a private Supabase Storage bucket. Published file downloads are issued as short-lived signed URLs to signed-in users.

## Security and distribution notes

- Each listing belongs to its creator; row-level security restricts editing and deletion to that owner.
- Only published listing metadata is visible in the public catalogue.
- Uploaded app files are stored in the private `configkit-app-files` bucket. Object policies restrict uploads, updates and deletes to the creator's own folder. Published downloads require an authenticated session.
- Redirect destinations must use HTTPS.
- Upload limit: 250 MB.
- ConfigKit does not scan, sign, verify, or certify applications. Users should review publishers, permissions, file types, and download sources before installing software.
- The App Store does not install apps automatically; it downloads the file or opens the publisher's external download page.

## Database

Migration: `20261115102034_configkit_app_store_catalog_and_private_files.sql`

Table: `public.configkit_apps`

Storage bucket: `configkit-app-files` (private)
