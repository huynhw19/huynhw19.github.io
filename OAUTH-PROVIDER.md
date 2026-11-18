# ConfigKit as a community OAuth 2.1 / OpenID Connect provider

ConfigKit can offer a **Continue with ConfigKit** sign-in option to community apps by using the Supabase Auth OAuth 2.1 server. Supabase handles client registration, authorization codes, PKCE, token exchange, OIDC discovery, signing keys, and token issuance. The GitHub Pages site supplies the user-facing consent screen.

> This is a setup guide, not proof that the OAuth server is enabled. An owner of the Supabase project must complete the dashboard steps below before the issuer can be used by community apps.

## Provider endpoints

For the ConfigKit Supabase project:

| Setting | URL |
| --- | --- |
| Issuer | `https://gwhqnqzzlgslwgijkkpt.supabase.co/auth/v1` |
| OIDC discovery | `https://gwhqnqzzlgslwgijkkpt.supabase.co/auth/v1/.well-known/openid-configuration` |
| OAuth authorization server metadata | `https://gwhqnqzzlgslwgijkkpt.supabase.co/.well-known/oauth-authorization-server/auth/v1` |
| Authorization endpoint | `https://gwhqnqzzlgslwgijkkpt.supabase.co/auth/v1/oauth/authorize` |
| Token endpoint | `https://gwhqnqzzlgslwgijkkpt.supabase.co/auth/v1/oauth/token` |
| JWKS | `https://gwhqnqzzlgslwgijkkpt.supabase.co/auth/v1/.well-known/jwks.json` |

The issuer is the expected Supabase issuer URL. After enabling the server, verify it against the live `issuer` value returned by the OIDC discovery document. If discovery does not load or the issuer differs, do not publish the provider yet.

## 1. Enable the Supabase OAuth server

1. Open [ConfigKit Supabase → Authentication → OAuth Server](https://supabase.com/dashboard/project/gwhqnqzzlgslwgijkkpt/auth/oauth-server).
2. Enable the OAuth 2.1 server.
3. In **Authentication → URL Configuration**, set the Site URL to `https://huynhw19.github.io`.
4. Add `https://huynhw19.github.io/**` (or the exact callback / redirect URLs you use) to allowed redirect URLs as appropriate for the site's normal Supabase Auth flows.
5. Set the OAuth server's **Authorization Path** to exactly `/oauth-consent.html`.
6. Ensure the project uses an asymmetric JWT signing key (RS256 or ES256) before expecting OIDC ID tokens. Request the `openid` scope for an ID token.

The consent page is deployed at [https://huynhw19.github.io/oauth-consent.html](https://huynhw19.github.io/oauth-consent.html). It requires a signed-in ConfigKit user, shows the requesting client's registered name, website/logo when available, redirect URI and requested scopes, and calls Supabase's approve/deny methods. It does not receive or handle OAuth client secrets.

## 2. Register community applications

1. Open [ConfigKit Supabase → Authentication → OAuth Apps](https://supabase.com/dashboard/project/gwhqnqzzlgslwgijkkpt/auth/oauth-apps).
2. Choose **Add new client** and register the app name, website/logo and exact redirect URI(s).
3. Choose **Public** for browser/mobile/native apps that cannot keep a secret. Choose **Confidential** only for a server-side app that can securely store its client secret.
4. Give the app developer the client ID and the exact redirect URI they registered. Give a client secret only through a secure private channel when required; never commit it or put it in browser JavaScript.

Community apps should use Authorization Code + PKCE (S256), a cryptographically random `state`, and only the scopes they need. A typical OIDC sign-in request asks for `openid email profile`. Use the discovery document rather than hard-coding endpoint paths in client integrations where possible.

Example authorization URL (replace placeholders and generate fresh `state` and PKCE values in the client app):

```text
https://gwhqnqzzlgslwgijkkpt.supabase.co/auth/v1/oauth/authorize?client_id=YOUR_CLIENT_ID&redirect_uri=https%3A%2F%2Fcommunity.example%2Fauth%2Fcallback&response_type=code&scope=openid%20email%20profile&state=RANDOM_CSRF_VALUE&code_challenge=BASE64URL_SHA256_CHALLENGE&code_challenge_method=S256
```

The user signs in to ConfigKit if needed, reviews the consent screen, and approves or denies. Supabase redirects to the registered callback with an authorization code or an OAuth error. The client backend exchanges the code at the token endpoint using its PKCE verifier (and, for confidential clients, its client authentication).

## 3. Let users review and revoke access

The new [Connected apps](https://huynhw19.github.io/connected-apps.html) page lists OAuth grants for the signed-in user and lets them revoke a grant. Revocation is handled by Supabase Auth and invalidates the grant's active sessions and refresh tokens.

## 4. Use ConfigKit as a third-party OIDC provider in another Supabase project

In the other Supabase project, open **Authentication → Sign In / Providers → Third-Party Auth → Add provider → Custom OIDC**. Use the issuer URL above, then follow that project's prompts for JWT validation / role claim mapping. The other project consumes ConfigKit as an identity provider; this is different from enabling ConfigKit's own OAuth server.

## Security and launch checklist

- Do not publish until the OAuth server is enabled and the discovery document is live and correct.
- Use HTTPS redirect URIs and exact registered callback matching.
- Require Authorization Code + PKCE (S256) and validate `state` in client apps.
- Use RS256 or ES256 signing for OIDC ID tokens; rotate signing keys carefully.
- Keep confidential client secrets, Supabase service-role keys and secret API keys off GitHub Pages and out of browser code.
- Request and explain only the minimum scopes. A scope label is not a substitute for database authorization.
- If an OAuth client accesses ConfigKit data, enforce row-level security and explicitly consider the OAuth `client_id` claim when designing per-client access. Supabase OAuth access tokens otherwise have the same user-data privileges as regular Supabase session tokens.
- Update the ConfigKit privacy policy and support information before inviting community users.

## References

- [Supabase OAuth 2.1 Server setup](https://supabase.com/docs/guides/auth/oauth-server/getting-started)
- [Supabase OAuth 2.1 flows](https://supabase.com/docs/guides/auth/oauth-server/oauth-flows)
- [Supabase JavaScript OAuth server methods](https://supabase.com/docs/reference/javascript/oauth-server-getauthorizationdetails)
