# Scratch Project Studio

Live workspace: https://huynhw19.github.io/scratch-studio.html  
Compatible player: https://huynhw19.github.io/scratch-project.html

## Architecture

The Studio dashboard is a separate page. `scratch-project.html` remains the compatible TurboWarp player, local upload runner and existing ConfigKit Drive editor handoff. The Studio does not replace the player or alter the existing private Drive bucket.

## Existing Drive compatibility

- Private project bytes remain in `configkit-drive-files`.
- Drive metadata remains in `public.drive_items`.
- Scratch project uploads retain the existing two-folder storage path: `<user-id>/<file-id>/blob`.
- Studio project records reference Drive items through `scratch_projects.drive_item_id`.
- Existing Drive ownership, email assurance, OAuth restrictions and Storage RLS policies are not relaxed.
- Older Scratch Drive files are registered in Studio metadata when the owner opens the library; their original bytes are not rewritten.

## Studio capabilities

- Project library with search, category, tags, favourites and archive state.
- Project details stored separately from the original `.sb3` bytes.
- Version snapshots stored as additional private Drive items; restoring creates a new current Drive item and preserves the snapshot.
- Private asset collections for individual images, audio and other reusable files.
- Creative challenge catalogue and per-user completion tracking.
- Public showcase and unlisted publishing. Publishing copies a project into the separate `configkit-scratch-public` bucket; the private Drive source remains private. Unpublishing removes the public copy.
- Public projects can be opened in the compatible player with `?publicProject=<project-id>`; owner projects use `?driveProject=<drive-item-id>`.

## Database

Migration `scratch_project_studio_foundation` creates:

- `scratch_projects`
- `scratch_project_versions`
- `scratch_project_collaborators`
- `scratch_project_feedback`
- `scratch_asset_collections`
- `scratch_assets`
- `scratch_challenges`
- `scratch_challenge_progress`
- `scratch_achievements`

Migration `scratch_studio_public_showcase_storage` adds the public-copy path and the separate public Storage bucket. RLS is enabled on the Studio tables. Private project files and version files continue to use the existing private Drive policies.

## Privacy and sharing boundaries

- Projects are private by default.
- Public and unlisted projects are explicitly copied to a dedicated public bucket. Anyone with access to a public or unlisted link can retrieve that published copy.
- Unpublishing removes the public object and changes the project visibility to private.
- Asset files and version snapshots remain in the owner's private Drive.
- The collaborator table is a schema foundation only. A future secure invitation and shared-file service is required before shared editing is enabled. Studio deliberately does not grant collaborators direct access to private Drive objects.
- Feedback is available only on public projects.
- Never put Supabase service-role credentials in browser code.

## Operational checks

After changes, validate page JavaScript, ensure both deep-link modes work, verify the existing private Drive path and upload/download flow, test publish/unpublish against the separate bucket, review RLS policies and check the GitHub Pages deployment workflow.
