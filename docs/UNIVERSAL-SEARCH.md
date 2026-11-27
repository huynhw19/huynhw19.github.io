# Universal Search — implementation and maintenance

## Purpose

Universal Search provides one discovery surface for ConfigKit tools, guides, platform destinations and indexed application content.

Live page: https://huynhw19.github.io/universal-search.html

## Search experience

The page has two result sources:

1. **Curated page catalogue** — a static list in `universal-search.html`. It is available to signed-out visitors and covers builders, workspaces, help pages, developer tools and platform destinations.
2. **Indexed database content** — returned for signed-in users by the Supabase RPC `public.configkit_universal_search(p_query text, p_category text, p_limit integer)`.

The browser catalogue is not a replacement for database search. It helps people find ConfigKit destinations even when those pages do not have database records.

## Filters

| Filter | Curated destinations | Indexed record categories |
|---|---|---|
| All | Every catalogue entry | Every permitted category |
| Tools & guides | Builders and tools | Apps and indexed tool records |
| Community | Community destinations | Community tools, discussions, profiles, groups, events, games, books and listings |
| People | — | Community profiles |
| Videos | Video Studio | Videos |
| Files | Drive and document destinations | Drive files, saved profiles and indexed group/library resources |
| My notes | Notes & Ideas | The signed-in user's notes |
| Education | Family, student and education pages | Education books, documents and slideshows |
| Documentation | User guides, Wiki and help | — |
| Platform & developer | OAuth, admin, announcements, integrations and roadmap | Public roadmap items and published announcements |

Database categories are mapped to user-facing filters in the `filterForDb` function. Keep the category label map (`typeName`) and filter map in sync with the SQL function.

## Query behaviour

- Queries are trimmed and limited to 120 characters in the browser.
- Database search starts at two or more characters and is only requested for a signed-in user.
- PostgreSQL uses `websearch_to_tsquery('simple', ...)` and `ts_rank_cd` to rank indexed records.
- The browser catalogue supports quoted phrases, `OR` alternatives and `-word` exclusions.
- Search results are capped by the RPC (maximum 50) and ordered by relevance, then update time.
- The URL query parameter `q` preserves a shareable search phrase.
- Press `/` or `Ctrl K` / `⌘ K` to focus the search box; Escape clears it.

## Indexed content

The current RPC searches these kinds of records:

- Apps and community tools
- Community profiles, discussions and shared mobileconfig posts
- Videos, groups, events and community games
- Education books, documents and slideshows
- Drive files, saved profiles, group resources and group comments
- Published community books and community store listings
- Library profiles and personal notes
- Public roadmap items
- Published platform announcements

The database RPC's source definition is in the Supabase project. When adding a category, update its SQL result branch, the browser's `typeName` and `filterForDb` maps, the relevant filter UI if needed, and this document.

## Privacy and authorization

- Signed-out visitors can use the curated page catalogue. They are not sent account-content search requests.
- Signed-in search calls the RPC using the current Supabase session.
- The RPC is a SQL-language function using invoker privileges (the default); it is not a service-role search endpoint.
- Underlying table RLS policies determine which private rows are visible to the caller.
- Drive search excludes deleted file records in the query and remains subject to Drive RLS.
- Community books are restricted to published records in the search query.
- Roadmap results are restricted to public items; announcements are restricted to published records.
- Do not add a privileged bypass or expose private fields in search result descriptions.
- Search results should contain only the fields needed for discovery: identifier, category, title, short description, destination, update time and relevance.

If an underlying table's RLS policy is missing or too broad, fix that policy rather than weakening the search function's access model.

## Maintenance checklist

When a new ConfigKit page or feature ships:

1. Add or update its curated catalogue entry in `universal-search.html`.
2. Choose the correct filter and include useful search keywords.
3. If its records should be searchable, add a bounded SQL branch to `configkit_universal_search`.
4. Ensure the source table has appropriate full-text search data and correct RLS policies.
5. Add its category to `typeName` and `filterForDb`.
6. Update the README, platform guide or feature documentation when the change affects user workflows.
7. Check that the destination page exists and that its route is safe for the result renderer.
8. Run JavaScript syntax checks and automated browser checks. Verify signed-out search without credentials; test private data access with controlled test accounts when available.

## Known boundaries

- This is a discovery search, not a global search across every private object or every file's full contents.
- Static catalogue entries are maintained in source code and must be updated when page names or routes change.
- Some indexed resources are scoped to the signed-in user or to public visibility; missing results may therefore be correct.
- Search result availability depends on the database indexes, RPC definition, grants and RLS policies being deployed together.
