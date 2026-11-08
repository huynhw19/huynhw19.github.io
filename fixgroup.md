# Fix ConfigKit groups

Use this guide if `groups.html` is not showing groups you created, or if group creation/joining is failing. The groups feature depends on both the static site configuration and Supabase database setup; adding this document by itself does not change either service.

## Quick fix (most common)

If **Create group** shows `function gen_random_bytes(integer) does not exist`, or **Join group** shows `column reference "group_id" is ambiguous`, the group functions in Supabase need updating. In the Supabase Dashboard open **SQL Editor**, choose the project used by the site, paste the whole of [`GROUPS-REPAIR.sql`](GROUPS-REPAIR.sql), and click **Run**. Then reload `groups.html` and try again.

## 1. Sign in and check the page

1. Open the deployed site and sign in at `login.html`.
2. Open `groups.html` and refresh the page.
3. Note the exact status or error shown on the page. If it says groups are not configured, check `auth-config.js` and complete `GROUPS-SETUP.md` first.

## 2. Repair groups missing their creator membership

A group will not appear in **Your groups** unless its creator has a corresponding row in `configkit_group_members`. In the Supabase Dashboard, open **SQL Editor**, select the correct project, and run the contents of [`GROUPS-REPAIR.sql`](GROUPS-REPAIR.sql).

The repair inserts membership rows for existing group creators that are missing them. It is safe to run again. The verification query at the end should return `0` for `groups_missing_creator_membership`. Then reload `groups.html` while signed in as the creator.

> Run this SQL only in the Supabase project used by the deployed site. Do not paste credentials or profile data into SQL or public issue reports.

## 3. If creating or joining still fails

- **Check the setup:** Confirm the schema and functions in [`GROUPS-SETUP.md`](GROUPS-SETUP.md) were run in the correct Supabase project. The required RPCs are `create_configkit_group` and `join_configkit_group`.
- **Check browser configuration:** In `auth-config.js`, verify `supabaseUrl` and `supabaseAnonKey` point to that same project. The anon/publishable key is intended for browser use; never put a service-role key in the site.
- **Check sign-in:** Sign out and back in, then retry. Groups actions require an authenticated Supabase session.
- **Check the database error:** In Supabase SQL Editor, verify both tables exist (`configkit_groups` and `configkit_group_members`) and that RLS is enabled. Reapply the relevant setup only after reviewing the SQL and any existing policies; policy creation statements may need adjustment if they already exist.
- **Check deployment and browser errors:** Ensure the latest site files are deployed. Open the browser developer console/network panel and look for failed requests to Supabase or JavaScript errors. A blocked CDN request can also prevent the Supabase client from loading.
- **Invite not accepted:** Use the complete invite code exactly as shared, and confirm the group still exists in the same Supabase project.

After any database or configuration change, reload the page and test again. If it remains broken, record the exact on-page error and the relevant Supabase error code/message (remove email addresses, tokens, invite codes, and other private values before sharing). Do not share access tokens, passwords, OAuth secrets, service-role keys, or invite codes publicly.
