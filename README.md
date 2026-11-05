# ConfigKit

A static GitHub Pages mobile configuration profile builder.

## Turnstile CAPTCHA setup

Email/password sign-in uses Cloudflare Turnstile with Supabase server-side validation. See [CAPTCHA-SETUP.md](CAPTCHA-SETUP.md) for initial setup and [TURNSTILE-TROUBLESHOOTING.md](TURNSTILE-TROUBLESHOOTING.md) if the challenge works but authentication reports an invalid CAPTCHA/key. The Cloudflare site key is public; keep its matching secret key in Supabase only.
