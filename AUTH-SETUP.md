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

1. Register an application in Microsoft Entra ID (Azure). Configure its supported account types to match the audiences you want.
2. Add the Supabase provider callback URL shown under **Authentication → Providers → Azure** as a Web redirect URI in Entra. Create a client secret there and enter the application client ID and secret in Supabase's Azure provider settings. Keep the secret only in Supabase.
3. Enable the Azure provider. The login page requests `openid email profile` scopes.

## 4. Test

Deploy the site, open `login.html`, and test each provider in a private browser window. The Supabase project must allow the exact callback URL. First successful provider sign-in creates an account; subsequent sign-ins use the same identity. Review provider/Supabase account-linking and email-confirmation settings before launch.

This adds authentication only. The site currently has no backend storage or account-specific profile features. Supabase and the identity providers process authentication data under their own privacy terms. Update the site's privacy policy accordingly before inviting users.
