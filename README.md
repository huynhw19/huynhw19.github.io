# ConfigKit

ConfigKit is a static GitHub Pages toolkit for creating and reviewing Apple `.mobileconfig` configuration profiles. Profile generation and inspection happen in your browser; the project does not upload generated profile contents.

**Live site:** [huynhw19.github.io/huynhw19.github.io](https://huynhw19.github.io/huynhw19.github.io/)

## Features

- Build Wi-Fi profiles, including a quick builder on the home page.
- Create DNS-over-HTTPS and DNS-over-TLS profiles.
- Create Home Screen web clip profiles.
- Combine Wi-Fi, web clip, and encrypted DNS payloads in Mobileconfig Studio.
- Prepare and inspect profiles locally, and browse example payloads and usage tips.
- Sign in with email/password, GitHub, or Microsoft when authentication is configured.
- Use signed-in groups and community discussion features when their Supabase setup is complete.

Start at [`index.html`](index.html) and choose a builder or tool. Generated profiles are unsigned. Review the XML and all profile settings before installing anything.

## Run locally

This is a static site: there is no package installation or build step. Clone or download the repository and serve its files with any local static HTTP server, then open the local site URL. For example, with Python:

```bash
python3 -m http.server 8000
```

Open <http://localhost:8000/>. Some features—especially authentication and OAuth redirects—require the corresponding Supabase and provider configuration, and local development URLs must be allowed in those settings.

## Deploy with GitHub Pages

In the repository settings, enable GitHub Pages for the branch and folder containing the site files. The repository root contains `index.html`, so no build workflow is required. After deployment, open the Pages URL and confirm the site loads. If you enable sign-in, configure the exact deployed URL as described in [AUTH-SETUP.md](AUTH-SETUP.md).

## Optional service setup

Authentication, CAPTCHA verification, signed-in groups, and community sharing depend on external service configuration; the static site alone does not provision these services.

- [Configure Supabase authentication and GitHub/Microsoft sign-in](AUTH-SETUP.md)
- [Configure Cloudflare Turnstile CAPTCHA](CAPTCHA-SETUP.md)
- [Troubleshoot Turnstile](TURNSTILE-TROUBLESHOOTING.md)
- [Set up signed-in groups in Supabase](GROUPS-SETUP.md)
- [Set up builder discussions](BUILDER-DISCUSSION-SETUP.md)

`auth-config.js` contains browser-visible settings such as the Supabase project URL, publishable/anon key, and Turnstile site key. These are not secrets. **Never put OAuth client secrets, Supabase service-role keys, or the Turnstile secret key in this repository or browser code.** Keep private credentials in their respective provider or server-side settings.

## Safety and privacy

Configuration profiles can change device settings and network behavior. Review each payload, organization, URL, and resolver before installation. Wi-Fi profiles may contain your network password; treat generated files as sensitive and do not share them publicly. DNS operators may receive information about the domains your device looks up.

Profile previews and XML checks are basic helpers, not a security audit or a guarantee of compatibility. ConfigKit is an independent project and is not affiliated with Apple. See [Safety & Contact](safety.html), [Privacy](privacy.html), and [Terms](terms.html).

## Project guides

- [How-to guide](how-to.html)
- [Mobileconfig tips](mobileconfig-tips.html)
- [Profile viewer guide](PROFILE-VIEWER.md)
- [Examples](examples.html)
- [Credits](credits.html)

## License

See [LICENSE](LICENSE).
