# Configure GitHub and Microsoft sign-in

The site is static GitHub Pages, so it must not contain OAuth client secrets or implement a provider's confidential OAuth flow in browser code. This page uses Supabase Auth as the hosted broker; its URL and publishable/anon key are public browser configuration, while provider client secrets stay in the Supabase dashboard.

## 1. Create/configure Supabase

1. Create a Supabase project and open **Authentication → URL Configuration**.
2. Add the deployed site URL to the allowed redirect URLs, for example `https://huynhw19.github.io/login.html`. If you use a custom domain, add that URL too. Set the site URL to your actual deployed homepage.
3. Copy the project URL and the publishable key (or legacy anon key) from the project's API settings. Put them into `auth-config.js` as `supabaseUrl` and `supabaseAnonKey`. These are intended for browser use; never put a `service_role` key or OAuth client secret in this repository.

## 2. Enable GitHub OAuth

1. Create a GitHub OAuth app in GitHub Developer Settings. Set its authorization callback URL to the Supabase project's provider callback URL shown in **Authentication → Providers → GitHub** (usually `https://<project-ref>.supabase.co/auth/v1/callback`).
2. Copy the GitHub client ID and client secret into the Supabase GitHub provider configuration and enable the provider.

## 3. Enable Bitbucket OAuth

1. In Bitbucket, open your workspace settings and create an **OAuth consumer** under **Apps and Features → OAuth consumers**.
2. Set its callback URL to the Supabase project's provider callback URL shown under **Authentication → Providers → Bitbucket** (usually `https://<project-ref>.supabase.co/auth/v1/callback`). Grant the minimum permissions required; email and read access are generally sufficient.
3. Copy the consumer key and secret into the Supabase Bitbucket provider settings, then enable the provider. Keep the consumer secret only in Supabase; never add it to this repository.
4. The login page calls Supabase Auth with the `bitbucket` provider. Add `https://huynhw19.github.io/login.html` to the Supabase allowed redirect URLs if it is not already present.

## 4. Enable Microsoft OAuth

**Important:** Microsoft sign-in cannot be enabled from frontend code alone. Supabase requires an Azure/Microsoft Entra application registration with a client ID and client secret. Someone with permission to register applications in the relevant Entra tenant must create/provide these credentials and configure the Supabase Azure provider. Do not put the client secret in this GitHub repository.

If you do not have Entra access or an administrator who can provide the credentials, leave Microsoft sign-in unavailable. Users can still create accounts and sign in with email/password or GitHub. The login page disables the Microsoft button and explains this limitation until the provider is configured.

1. Register an application in Microsoft Entra ID (Azure). Configure its supported account types to match the audiences you want.
2. Add the Supabase provider callback URL shown under **Authentication → Providers → Azure** as a Web redirect URI in Entra. Create a client secret there and enter the application client ID and secret in Supabase's Azure provider settings. Keep the secret only in Supabase.
3. Enable the Azure provider. The login page requests `openid email profile` scopes.

## 5. Phone authentication is not available on the website

Phone-number sign-in and phone-based multi-factor authentication (SMS MFA) have been removed from the ConfigKit website. The login and Account settings pages use email/password, configured identity providers, authenticator-app TOTP and passkeys instead.

This is a website-interface change only. It does not delete or modify phone numbers or phone MFA factors already stored in Supabase Auth. Those existing records remain in Supabase and may still be subject to the project's Auth configuration and database policies. The website does not provide controls to inspect, enroll, remove, or use those phone factors. Do not assume an existing phone factor can be used to complete sign-in through this website.

## 6. Configure one-time authenticator recovery codes

ConfigKit provides a separate recovery-code backup for users who have enabled authenticator-app TOTP. It generates 10 random 128-bit codes. Each code can be redeemed once after the user completes their primary email/password or provider sign-in; it is not a password and cannot create a primary session by itself.

1. Confirm the Supabase database migrations `add_secure_totp_recovery_codes` and `secure_recovery_code_status_and_revoke` are applied.
2. Confirm the `recovery-codes` Edge Function is active with JWT verification enabled. It uses the existing Supabase project URL, publishable key, and server-side service-role/secret key environment. Never put the service-role/secret key in this repository or browser code.
3. A signed-in user completes a second-factor check, then opens **Account settings → Authenticator recovery codes** and generates a set. Generation requires a verified TOTP factor and a trusted session.
4. Save the displayed codes in a password manager or other secure offline location. The codes are shown only once. Replacing the set invalidates every unused code in the previous set; users can also revoke the set.
5. During sign-in, after the primary credential is accepted, users can enter one recovery code instead of a TOTP challenge. A successful redemption is single-use and authorizes only that Supabase session for up to eight hours.

Security properties:
- Each code contains 128 bits of cryptographically secure randomness. Only SHA-256 hashes are stored; raw codes are returned once at generation and are never logged.
- Redemption is performed server-side and atomically marks a code as used. Replays fail. Attempts are limited to 10 per session per 15-minute window.
- Recovery-code records and verification sessions live in the private database schema, with service-role-only RPC access. The browser cannot insert hashes or mark itself verified.
- Restrictive RLS policies accept a native AAL2 session or a server-issued recovery-code session while recovery codes are enabled.
- Recovery codes are a backup second factor only. They do not bypass the primary sign-in step. Users should keep a fresh TOTP factor enrolled and replace codes if they may have been exposed.

## 7. Test

Deploy the site, open `login.html`, and test each provider in a private browser window. Test recovery codes by enabling TOTP, generating a set in Account settings, saving the codes, signing out, and using one code after the primary sign-in step. Confirm that the remaining count decreases, that a used code is rejected on replay, and that protected Data API requests remain blocked for an unverified session. Also test normal TOTP sign-in after recovery codes have been enabled. The Supabase project must allow the exact callback URL. First successful provider sign-in creates an account; subsequent sign-ins use the same identity. Review provider/Supabase account-linking and email-confirmation settings before launch.

Supabase and the identity providers process authentication data under their own privacy terms. Other ConfigKit features may also store account-related data in Supabase. Update the site's privacy policy accordingly before inviting users.
