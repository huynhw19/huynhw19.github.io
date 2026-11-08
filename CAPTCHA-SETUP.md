# Turnstile CAPTCHA setup

The login page uses Cloudflare Turnstile for Supabase email sign-up, password sign-in, and password-reset requests. Supabase validates the CAPTCHA token server-side; a browser-only challenge by itself is not a security check.

1. In the [Cloudflare Turnstile dashboard](https://dash.cloudflare.com/?to=/:account/turnstile), create a widget for your deployed hostname(s). Choose a managed widget and allow local development hostnames if needed.
2. Copy the **site key** into `turnstileSiteKey` in `auth-config.js`. The site key is public and belongs in browser config; never put the Turnstile **secret key** in this repository.
3. In the Supabase project, open **Authentication → Security and Protection → CAPTCHA** (dashboard labels may vary), enable CAPTCHA, choose **Cloudflare Turnstile**, and enter the secret key. Save the settings.
4. Deploy and test sign-up, password sign-in, and password reset on the configured hostname. The challenge must complete for each request because tokens expire and are single-use.

If the site key is missing, email/password authentication is intentionally blocked rather than silently proceeding without verification. GitHub and Microsoft OAuth buttons are separate flows and are not protected by this page's Turnstile token integration; use Supabase/provider abuse controls for those flows.

This request is done.
