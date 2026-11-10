# Configure GitHub and Microsoft sign-in

The site is static GitHub Pages, so it must not contain OAuth client secrets or implement a provider's confidential OAuth flow in browser code. This page uses Supabase Auth as the hosted broker; its URL and publishable/anon key are public browser configuration, while provider client secrets stay in the Supabase dashboard.

## 1. Create/configure Supabase

1. Create a Supabase project and open **Authentication → URL Configuration**.
2. Add the deployed site URL to the allowed redirect URLs, for example `https://huynhw19.github.io/login.html`. If you use a custom domain, add that URL too. Set the site URL to your actual deployed homepage.
3. Copy the project URL and the publishable key (or legacy anon key) from the project's API settings. Put them into `auth-config.js` as `supabaseUrl` and `supabaseAnonKey`. These are intended for browser use; never put a `service_role` key or OAuth client secret in this repository.

## 2. Enable GitHub OAuth

1. Create a GitHub OAuth app in GitHub Developer Settings. Set its authorization callback URL to the Supabase project's provider callback URL shown in **Authentication → Providers → GitHub** (usually `https://<project-ref>.supabase.co/auth/v1/callback`).
2. Copy the GitHub client ID and client secret into the Supabase GitHub provider configuration and enable the provider.

## 3. Enable Microsoft OAuth

**Important:** Microsoft sign-in cannot be enabled from frontend code alone. Supabase requires an Azure/Microsoft Entra application registration with a client ID and client secret. Someone with permission to register applications in the relevant Entra tenant must create/provide these credentials and configure the Supabase Azure provider. Do not put the client secret in this GitHub repository.

If you do not have Entra access or an administrator who can provide the credentials, leave Microsoft sign-in unavailable. Users can still create accounts and sign in with email/password or GitHub. The login page disables the Microsoft button and explains this limitation until the provider is configured.

1. Register an application in Microsoft Entra ID (Azure). Configure its supported account types to match the audiences you want.
2. Add the Supabase provider callback URL shown under **Authentication → Providers → Azure** as a Web redirect URI in Entra. Create a client secret there and enter the application client ID and secret in Supabase's Azure provider settings. Keep the secret only in Supabase.
3. Enable the Azure provider. The login page requests `openid email profile` scopes.

## 4. Configure email two-factor delivery

The site includes a custom email second-factor flow backed by a Supabase Edge Function and database access policies. It sends an eight-digit, single-use code and a single-use verification link. Challenges expire after five minutes, are rate-limited, and are bound to an authenticated account/session. Successful verification authorizes that session for up to eight hours.

Email delivery uses [Resend](https://resend.com/). Before enabling the feature:

1. Create a Resend account and verify a sending domain you control.
2. Create a Resend API key with permission to send email.
3. Open the Supabase project **Edge Functions → Secrets** page.
4. Add these secrets there (never in this repository):
   - `RESEND_API_KEY`: your Resend API key.
   - `EMAIL_FROM`: a sender using your verified domain, for example `ConfigKit Security <security@YOUR-VERIFIED-DOMAIN>`.
5. Confirm that the deployed `email-2fa` Edge Function is active.

The migration creates private challenge/session tables and adds restrictive RLS policies to the current public tables (and Storage objects, if present). The browser cannot mark a session verified: the Edge Function validates the code/link and writes the short-lived verification record that RLS checks against the signed-in Supabase session ID.

Users enable the email factor from **Account settings → Email verification as an alternative 2FA method**. Existing verified TOTP users must complete their current authenticator challenge before enrolling email as an alternative. After enrollment, email verification can replace the TOTP prompt for a session. Users can still choose their existing authenticator code instead, and a native Supabase AAL2 session is accepted as the fallback. The existing TOTP/passkey enrollment remains intact.

A one-time email link requires the user to be signed in to the same ConfigKit account in the browser where the link is opened. The link can verify another active session for that account, but it cannot create a signed-in session by itself.

## 5. Test

Deploy the site, open `login.html`, and test each provider in a private browser window. Test email 2FA by enabling it in account settings, signing out, signing in again, and verifying both the emailed code and one-time link. Confirm that direct Supabase Data API requests remain blocked until verification. The Supabase project must allow the exact callback URL. First successful provider sign-in creates an account; subsequent sign-ins use the same identity. Review provider/Supabase account-linking and email-confirmation settings before launch.

This adds authentication only. The site currently has no backend storage or account-specific profile features. Supabase and the identity providers process authentication data under their own privacy terms. Update the site's privacy policy accordingly before inviting users.
