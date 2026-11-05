# ConfigKit

A static GitHub Pages mobile configuration profile builder.

## Turnstile CAPTCHA setup

Email/password sign-in uses Cloudflare Turnstile with Supabase server-side validation. See [CAPTCHA-SETUP.md](CAPTCHA-SETUP.md) for initial setup and [TURNSTILE-TROUBLESHOOTING.md](TURNSTILE-TROUBLESHOOTING.md) for troubleshooting.

## Signed-in groups

ConfigKit includes a private groups page where signed-in users can create groups, join with invite codes, and manage their memberships. Set up the required Supabase tables and secure RPC functions using [GROUPS-SETUP.md](GROUPS-SETUP.md), then visit [`groups.html`](groups.html). Groups store names and memberships only; mobileconfig files and profile settings remain on the user's device.
