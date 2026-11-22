# ConfigKit Collaboration Studio

ConfigKit Collaboration Studio is the shared editing workspace at [collaboration.html](https://huynhw19.github.io/collaboration.html).

## What it supports

- Shared text documents and slide-deck outlines.
- Live concurrent editing with Yjs CRDT updates.
- Private Realtime channels with online presence and typing indicators.
- Owner, editor and viewer roles.
- Single-use invitation links with a maximum seven-day expiry.
- Workspace comments and manually named checkpoints.
- Import from ConfigKit Drive and export/download copies.
- Member removal, role changes, workspace deletion and leave-workspace controls.

Documents use a plain-text/Markdown editor. Slide decks are edited as text sections separated by a line containing `---`; this is not a rich visual slide canvas.

## How to use it

1. Sign in to ConfigKit and open Collaboration Studio from the dashboard or site navigation.
2. Create a document or slide deck, or import a saved `.ckdoc.json` / `.ckslides.json` file from Drive.
3. Open **People** and create an Editor or Viewer invitation link.
4. Send the link only to the intended collaborator. The recipient must sign in to ConfigKit to accept it.
5. Edit together. Changes are merged with Yjs and appended to the private update log.
6. Use comments to discuss the work and checkpoints to save named restore points.
7. Save a copy to ConfigKit Drive or download a ConfigKit JSON file when finished.

Invitation links are bearer credentials: anyone who receives an active link can use it once. Links are stored as SHA-256 hashes, expire within seven days, and can be revoked by the owner before acceptance. The raw token is not stored in the database.

## Roles

| Capability | Owner | Editor | Viewer |
|---|---:|---:|---:|
| Read and edit document text | Yes | Yes | Read only |
| See live presence | Yes | Yes | Yes |
| Add comments | Yes | Yes | Yes |
| Create checkpoints | Yes | Yes | No |
| Invite collaborators | Yes | No | No |
| Change roles / remove members | Yes | No | No |
| Delete workspace | Yes | No | No |
| Leave workspace | No (the owner must delete the workspace) | Yes | Yes |

## Security and data model

The feature uses Supabase tables prefixed with `configkit_collab_`:

- `configkit_collab_documents`: workspace metadata and a shared immutable Yjs base state.
- `configkit_collab_members`: membership and role assignments.
- `configkit_collab_invites`: hashed one-time invite tokens and expiry/revocation state.
- `configkit_collab_updates`: append-only Yjs update history.
- `configkit_collab_comments`: member discussion.
- `configkit_collab_snapshots`: named Yjs checkpoints.

Row Level Security is enabled on every table. Access is restricted to authenticated workspace members, with a verified-session gate and an OAuth-client restriction. Editors can append document updates; viewers cannot broadcast document edits. Private Realtime channel policies check membership for presence, editor rights for document-update broadcasts, and owner rights for member-management and workspace-control events. Comments are delivered through the Realtime publication with member-scoped RLS.

The update log is append-only so concurrent edits can be replayed when a collaborator joins. It is not automatically compacted yet; long-lived workspaces with heavy editing may accumulate update rows. Checkpoints are restore points, not automatic log compaction.

## Operational notes

- All collaborators need an internet connection and a signed-in ConfigKit account.
- Yjs is loaded from a version-pinned CDN URL; Supabase JS is loaded from the project's configured CDN version.
- Invitation links are shared manually; the feature does not send invitation emails.
- Removing a member or changing their role triggers a client refresh event. Supabase Realtime authorization is cached for an existing WebSocket until the connection reauthenticates, so users should keep sessions current.
- Test with at least two separate ConfigKit accounts before relying on collaboration for important work. Check editing, invitation acceptance, viewer restrictions, member removal, checkpoints and Drive export.

