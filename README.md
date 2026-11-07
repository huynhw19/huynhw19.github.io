# ConfigKit

ConfigKit is a static GitHub Pages toolkit for creating and reviewing Apple `.mobileconfig` configuration profiles. Profile generation and inspection happen in your browser; the project does not upload generated profile XML or Wi‑Fi credentials.

**Live site:** [huynhw19.github.io/huynhw19.github.io](https://huynhw19.github.io/huynhw19.github.io/)

## Features

- Build Wi‑Fi profiles, including a quick builder on the home page.
- Create DNS-over-HTTPS and DNS-over-TLS profiles.
- Create Home Screen web clip profiles.
- Combine Wi‑Fi, web clip, and encrypted DNS payloads in Mobileconfig Studio.
- Prepare and inspect profiles locally, and browse example payloads and usage tips.
- Select English or Spanish for the homepage; the selection is saved in your browser.
- Sign in with email/password, GitHub, or Microsoft when authentication is configured.
- Choose personal, education, work, or organization as a self-declared account profile type.
- Use signed-in groups and community discussion features when their Supabase setup is complete.
- View an organization-specific dashboard and getting-started checklist at [`organization-dashboard.html`](organization-dashboard.html).

Start at [`index.html`](index.html) and choose a builder or tool. Generated profiles are unsigned. Review the XML and all profile settings before installing anything.

## Accounts and organization dashboard

The login page lets users choose an account type and provide optional profile details. Organization account type and organization name are self-declared metadata; ConfigKit does not verify organizations, provide organization-managed access, manage organization members, or store profiles. The organization dashboard is a guide to profile creation, review, testing, and safe sharing—not an organization administration console.

Authentication features require the external service configuration described below. Do not use ConfigKit to share passwords, private keys, or sensitive profile contents through unapproved channels.

## Run locally

This is a static site: there is no package installation or build step. Clone or download the repository and serve its files with any local static HTTP server, then open the local site URL. For example:

```bash
python3 -m http.server 8000
```

Open <http://localhost:8000/>. Some features—especially authentication and OAuth redirects—require the corresponding Supabase and provider configuration, and local development URLs must be allowed in Supabase.

## Deploy with GitHub Pages

In the repository settings, enable GitHub Pages for the branch and folder containing the site files. The repository root contains `index.html`, so no build workflow is required. After deployment, open the Pages URL shown in repository settings.

## Optional service setup

Authentication, CAPTCHA verification, signed-in groups, and community sharing depend on external service configuration; the static site alone does not provision these services.

- [Configure Supabase authentication and GitHub/Microsoft sign-in](AUTH-SETUP.md)
- [Configure Cloudflare Turnstile CAPTCHA](CAPTCHA-SETUP.md)
- [Troubleshoot Turnstile](TURNSTILE-TROUBLESHOOTING.md)
- [Set up signed-in groups in Supabase](GROUPS-SETUP.md)
- [Set up builder discussions](BUILDER-DISCUSSION-SETUP.md)

`auth-config.js` contains browser-visible settings such as the Supabase project URL, publishable/anon key, and Turnstile site key. These are not secrets. **Never put OAuth client secrets, Supabase service-role keys, or other private credentials in this repository.**

## Safety and privacy

Configuration profiles can change device settings and network behavior. Review each payload, organization, URL, and resolver before installation. Wi-Fi profiles may contain your network password; protect downloaded files and delete them when they are no longer needed. Only install profiles from sources you trust and only on devices you are authorized to manage.

Profile previews and XML checks are basic helpers, not a security audit or a guarantee of compatibility. ConfigKit is an independent project and is not affiliated with Apple. See [Safety & Contact](safety.html) and [Privacy](privacy.html).

## Project guides

- [How-to guide](how-to.html)
- [Mobileconfig tips](mobileconfig-tips.html)
- [Profile viewer guide](PROFILE-VIEWER.md)
- [Examples](examples.html)
- [Organization dashboard and getting started](organization-dashboard.html)
- [Credits](credits.html)

## License

See [LICENSE](LICENSE).
