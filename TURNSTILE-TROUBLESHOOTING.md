# Turnstile troubleshooting

## What the keys are

Cloudflare Turnstile issues two related credentials for each widget:

- **Site key** — public identifier for the widget. It is used in the browser in `auth-config.js` as `turnstileSiteKey` and is safe to publish.
- **Secret key** — private credential used by the server to validate challenge tokens. For this site, Supabase performs that validation, so the secret belongs in the Supabase CAPTCHA settings only. Never commit it or put it in `auth-config.js`.

These are a matched pair from the same Turnstile widget; they are not interchangeable. The site key is obtained from the Cloudflare dashboard under **Turnstile** after creating/opening the widget. Supabase does not issue either Cloudflare key.

## If the challenge works but sign-in reports an invalid key/site

If the Turnstile challenge displays and completes, but Supabase rejects the sign-in with a CAPTCHA/key error, the browser may be using a valid site key while Supabase has a missing, incorrect, or mismatched secret. Check:

1. In Cloudflare, open the widget for this site and copy its current **site key** into `turnstileSiteKey` in `auth-config.js`.
2. In the same widget, copy its **secret key** into the Cloudflare Turnstile CAPTCHA provider setting in the correct Supabase project (**Authentication → Security and Protection → CAPTCHA**; dashboard labels can vary). Do not put the secret in this repository.
3. Confirm that the widget allows the exact deployed hostname (for example, `huynhw19.github.io`), and add any custom domain or local development hostname used for testing.
4. Confirm the page's Supabase URL/key points to that same Supabase project where CAPTCHA is enabled and the secret was saved.
5. Deploy the updated public site key, then reload the page and complete a fresh challenge. Turnstile tokens expire and are single-use; do not retry an old token.

If the challenge itself does not load and Cloudflare reports an invalid site key, check the browser's Cloudflare Turnstile error details and verify the site key and hostname allowlist in Cloudflare.

## Can this repository fix the key automatically?

No. A real Cloudflare site/secret pair is account-specific. The repository can hold the public site key, but it cannot discover or repair the secret stored in Supabase. The current configured value is a site-key-shaped value, but only the owner can verify that it is the active key for the deployed widget and that Supabase has its matching secret. Do not replace it with a guessed or test key for production.

See also [`CAPTCHA-SETUP.md`](CAPTCHA-SETUP.md).
