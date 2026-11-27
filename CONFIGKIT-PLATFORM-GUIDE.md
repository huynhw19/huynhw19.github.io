# ConfigKit Platform Guide

This guide describes the shared architecture and operating model of ConfigKit. It complements the end-user [Complete Guide](https://huynhw19.github.io/complete-guide.html), [Official Wiki](https://huynhw19.github.io/wiki.html), [Account Guide](https://huynhw19.github.io/account-docs.html), and feature-specific setup notes in this repository.

## 1. Platform overview

ConfigKit is a browser-delivered application hosted on GitHub Pages. Its pages are primarily HTML, CSS and JavaScript. Supabase provides authentication, PostgreSQL data, Row Level Security (RLS), Storage and selected Edge Functions.

The main entry points are:

- Public homepage: https://huynhw19.github.io/
- Signed-in dashboard: https://huynhw19.github.io/dashboard.html
- Universal Search: https://huynhw19.github.io/universal-search.html
- Community roadmap: https://huynhw19.github.io/roadmap.html
- Official Wiki: https://huynhw19.github.io/wiki.html

The repository is the source of truth for static pages, browser-side workflows, documentation and deployment automation. Backend behaviour also depends on the Supabase project schema, policies, functions and server-side secrets.

## 2. Main platform layers

| Layer | Responsibility |
|---|---|
| GitHub Pages | Delivers public HTML, CSS, JavaScript and static assets |
| Browser application | Renders workspaces and calls permitted Supabase APIs |
| Supabase Auth | Authenticates members and manages sessions |
| PostgreSQL | Stores application, community and account-scoped records |
| Row Level Security | Enforces which rows the current role and user may read or change |
| Supabase Storage | Stores private files behind storage policies |
| Edge Functions | Performs selected privileged or server-mediated operations |
| GitHub Actions | Runs repository checks and publishes the Pages site |

A public browser key is not a secret. Service-role keys, API keys and other privileged credentials must remain in server-side secrets and must never be committed to the repository or embedded in browser code.

## 3. Identity and connected applications

ConfigKit operates an OAuth 2.1 / OpenID Connect identity-provider flow through Supabase Auth OAuth Server. Approved third-party applications can offer “Sign in with ConfigKit”.

Useful pages:

- [OAuth developer guide](https://huynhw19.github.io/oauth-developer-guide.html)
- [Register an OAuth app](https://huynhw19.github.io/oauth-apps.html)
- [OAuth test client](https://huynhw19.github.io/oauth-test.html)
- [Connected Apps](https://huynhw19.github.io/connected-apps.html)

The integration uses Authorization Code with PKCE (S256). Public browser/mobile clients use PKCE and do not have a client secret. Confidential clients keep their secret on a trusted server. Redirect URIs must exactly match the URI registered for the client.

OAuth scopes such as `openid`, `email` and `profile` describe identity claims. ConfigKit-specific permissions are separate consented capabilities and are only meaningful where the application and backend have explicit enforcement for them. Approval and consent do not grant blanket access to ConfigKit data.

## 4. Owner and administrator operations

The [Admin Portal](https://huynhw19.github.io/admin-portal.html) is the protected operations workspace. Members can apply for administrator access; the ConfigKit owner reviews applications. The owner role is reserved to the existing owner identity.

The admin workspace brings together supported operations such as account moderation, reports and content review, developer app review, support workflows, announcements, feature flags, audit history and owner-only maintenance controls.

Important boundaries:

- An administrator role is not the same as owner access.
- Owner-only controls remain restricted to the owner.
- Privileged account operations are mediated by server-side Edge Functions.
- The browser must never receive the Supabase service-role key.
- RLS and function-level authorization must remain in place when adding modules.

A feature-flag record is a registry value; a feature only changes behaviour when its own code explicitly reads and applies that flag.

## 5. Announcements

Published platform announcements are available at [Announcements](https://huynhw19.github.io/announcements.html). The public page should expose only records whose status is published. Drafting and publishing are administrator workflows and must remain protected by backend authorization.

## 6. Universal Search

[Universal Search](https://huynhw19.github.io/universal-search.html) combines a curated directory of ConfigKit pages with indexed database content.

- The local directory provides searchable tools, guides and platform destinations without requiring sign-in.
- Signed-in users can search indexed community, education, video, group and account-owned records through the `configkit_universal_search` RPC.
- The RPC uses PostgreSQL full-text search and returns ranked, bounded results.
- Private content remains subject to the underlying table's RLS policies. The search function must not be converted into an unrestricted privileged data endpoint.
- Public roadmap items and published announcements are included in the search index.

See [Universal Search implementation notes](docs/UNIVERSAL-SEARCH.md) for categories, query behaviour and maintenance guidance.

## 7. Data protection and operational rules

1. Keep RLS enabled on exposed tables and storage objects.
2. Write policies for the actual ownership, relationship or role boundary; authentication alone is not authorization.
3. Keep privileged credentials in Supabase secrets and server-side execution contexts.
4. Validate the caller's identity and role inside every privileged Edge Function.
5. Treat user-generated text, files and external content as untrusted input.
6. Keep public search limited to public records; rely on RLS for private records.
7. Do not describe a feature as live merely because a roadmap item, UI link or database row exists. Verify the relevant workflow and backend path.
8. Update the relevant feature guide and Universal Search catalogue when a user-facing page or capability changes.

## 8. Repository workflow

- Keep feature implementation in the relevant page, shared asset or Supabase function.
- Keep database changes in reviewed SQL migrations and verify the resulting schema and policies.
- Pin important client-library versions consistently across pages.
- Run syntax checks and automated browser/deployment checks for changed pages.
- Review GitHub Actions and Pages deployment results before calling a change published.
- Record any test that requires a real signed-in account separately from checks that can be automated.

## Related documentation

- [README](README.md)
- [Universal Search documentation](docs/UNIVERSAL-SEARCH.md)
- [OAuth provider setup](OAUTH-PROVIDER.md)
- [Authentication setup](AUTH-SETUP.md)
- [Collaboration setup](COLLABORATION.md)
