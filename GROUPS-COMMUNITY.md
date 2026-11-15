# ConfigKit Groups Community

The private community is available at [groups.html](groups.html). It extends the existing create/join/invite/rename/delete/leave workflows rather than replacing them.

## Member experience

- Create a group and invite others with the existing one-time invite code.
- Upload a `.mobileconfig` profile with a title and optional description.
- Download a profile, add comments, and react with a like.
- Report unsafe files, personal information, spam, harassment, or other concerns.
- View the group roster. Group owners can promote or demote moderators. Owners and moderators can remove ordinary members; only owners can remove moderators.
- Group owners and moderators can review reports and remove profiles or comments.

## Privacy and file handling

- Profile visibility is **members-only**. There is no public profile feed or public Storage URL.
- Files are stored in the private Supabase Storage bucket `configkit-group-profiles`.
- Uploads are limited to 10 MiB and the bucket only accepts the configured profile/XML/octet-stream MIME types.
- Object paths are `<group UUID>/<uploader UUID>/<random filename>`; Storage RLS checks active membership and the uploader path.
- Downloads use the authenticated Storage API. The UI does not generate public or long-lived share URLs.
- Group deletion removes its stored profile objects before calling the existing group-delete RPC.
- Mobileconfig profiles can contain credentials, certificates, private keys, VPN settings, or other sensitive information. Share only with trusted members and only when authorized. The site does not inspect or redact secrets inside an uploaded profile.

## Database objects

| Object | Purpose |
| --- | --- |
| `configkit_group_profiles` | Group-scoped profile metadata and moderation state; file bytes stay in Storage |
| `configkit_group_comments` | Threaded discussion for each shared profile |
| `configkit_group_reactions` | Member reactions (like, helpful, thanks) |
| `configkit_group_reports` | Member-submitted reports and moderator resolution |
| `configkit_group_moderation_log` | Audit trail for moderation decisions |
| `configkit_group_members.role` | Owner, moderator, or member permissions |
| `configkit-group-profiles` | Private Storage bucket for uploaded files |

## Authorization

Every new public table has RLS enabled and explicit grants/policies. Policies scope reads and writes to current group membership, constrain authorship, and reserve report queues, moderation logs, and moderator actions for owners/moderators. Existing email-2FA session-gate and OAuth-client restrictions are carried forward as restrictive policies (ANDed with membership rules), with trigger guards on group/member mutations and restricted RPC execution. Anonymous table grants are revoked. Helper functions used to avoid recursive membership-table RLS checks live in the non-exposed `private` schema and are executable only by authenticated users.

Storage RLS allows:
- SELECT only for current group members.
- INSERT only for a member uploading into their own user-ID folder within a group they belong to.
- DELETE only for the uploader or a group owner/moderator.

Content ownership and target/group identifiers are immutable after insert. Invite codes remain hidden from group-list queries and are returned only by the existing create-group RPC.

## Supabase migrations applied

The following migrations were applied to the connected Supabase project:

1. `configkit_groups_community_private_profiles_moderation`
2. `configkit_groups_community_immutable_content`
3. `configkit_groups_community_rls_recursion_fix`
4. `configkit_groups_community_report_integrity`
5. `configkit_groups_community_query_indexes`
6. `configkit_groups_rpc_execute_restrictions`
7. `configkit_groups_strict_grants_and_restrictive_gates`
8. `configkit_groups_verified_session_trigger_guard`
9. `configkit_groups_rls_policy_performance`
10. `configkit_groups_moderator_member_removal`
11. `configkit_groups_moderator_member_removal`

The Storage bucket is private and has a 10 MiB object limit. No service-role key is used in browser code.

## Operational notes

- Test with two real accounts: a member of the same group should be able to download; a non-member should receive an authorization failure.
- Test moderator actions with an owner-promoted moderator account.
- Supabase security advisors also report unrelated pre-existing project findings (for example, an `enterprise_jobs` policy referencing editable user metadata and other SECURITY DEFINER RPC warnings). Those are outside this Groups implementation and should be reviewed separately.
