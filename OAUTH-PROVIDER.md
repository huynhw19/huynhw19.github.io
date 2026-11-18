# ConfigKit as a community OAuth 2.1 / OpenID Connect provider

ConfigKit can offer a **Continue with ConfigKit** sign-in option to community apps using the Supabase Auth OAuth 2.1 server. Supabase handles client registration, authorization codes, PKCE, token exchange, OIDC discovery, signing keys and token issuance. This site provides the user-facing consent and grant-management pages.

> The repository changes do not enable the Supabase OAuth server. A project owner must enable it in the dashboard and verify discovery before sharing the issuer publicly.

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

The issuer above is the expected Supabase issuer URL. Once the server is enabled, verify the live `issuer` value from the OIDC discovery document. Do not publish until the discovery document responds and its issuer matches.

## 1. Enable the Supabase OAuth server

1. Open [ConfigKit Supabase → Authentication → OAuth Server](https://supabase.com/dashboard/project/gwhqnqzzlgslwgijkkpt/auth/oauth-server).
2. Enable the OAuth 2.1 server.
3. In **Authentication → URL Configuration**, set the Site URL to `https://huynhw19.github.io`.
4. Set the OAuth server **Authorization Path** to exactly `/oauth-consent.html`.
5. Use an asymmetric JWT signing key (RS256 or ES256) for OIDC ID tokens. Community clients requesting an ID token must include the `openid` scope.

The consent UI is [oauth-consent.html](https://huynhw19.github.io/oauth-consent.html). It checks the signed-in ConfigKit user, retrieves authorization details, displays the registered app name/website/logo, redirect URI and requested scopes, then calls Supabase's approve/deny methods. It does not expose OAuth client secrets.

## 2. Register community applications

1. Open [ConfigKit Supabase → Authentication → OAuth Apps](https://supabase.com/dashboard/project/gwhqnqzzlgslwgijkkpt/auth/oauth-apps).
2. Add a client with its app name, website/logo and exact redirect URI(s).
3. Choose **Public** for browser, mobile or native apps that cannot protect a secret. Choose **Confidential** only for a server-side app that securely stores a client secret.
4. Share the client ID and registered redirect URI with the developer. Share any confidential client secret only through a secure private channel. Never commit it or place it in browser code.

Use Authorization Code + PKCE (S256), a cryptographically random `state`, exact HTTPS redirect URIs and only the scopes required. A typical OIDC sign-in request uses `openid email profile`. Use discovery metadata rather than hard-coding endpoint URLs where possible.

Example authorization request (replace placeholders and generate fresh state and PKCE values in the client app):

```text
https://gwhqnqzzlgslwgijkkpt.supabase.co/auth/v1/oauth/authorize?client_id=YOUR_CLIENT_ID&redirect_uri=https%3A%2F%2Fcommunity.example%2Fauth%2Fcallback&response_type=code&scope=openid%20email%20profile&state=RANDOM_CSRF_VALUE&code_challenge=BASE64URL_SHA256_CHALLENGE&code_challenge_method=S256
```

The user signs in to ConfigKit if needed, reviews and approves/denies the request, then returns to the registered callback with an authorization code or OAuth error. The client exchanges the code at the token endpoint using its PKCE verifier and, for confidential clients, client authentication.

## 3. User grant management

The [Connected apps](https://huynhw19.github.io/connected-apps.html) page lists grants for the signed-in user and lets them revoke a grant. Supabase Auth performs revocation and invalidates the grant's active sessions and refresh tokens.

## 4. Use ConfigKit as an OIDC provider in another Supabase project

In the consuming Supabase project, open **Authentication → Sign In / Providers → Third-Party Auth → Add provider → Custom OIDC**. Configure the issuer URL above and follow the dashboard's prompts for JWT validation and role claim mapping. This is a consumer setup; it is separate from enabling ConfigKit's own OAuth server.

## Security and launch checklist

- Enable OAuth Server and verify live OIDC discovery before announcing the provider.
- Require HTTPS and exact registered redirect URI matching.
- Use Authorization Code + PKCE (S256) and validate `state` in client apps.
- Use RS256 or ES256 for OIDC ID tokens; rotate signing keys carefully.
- Keep confidential client secrets, Supabase service-role keys and secret API keys out of GitHub Pages and browser code.
- Explain requested scopes. Scopes alone do not restrict database access.
- If OAuth clients access ConfigKit data, enforce row-level security and explicitly consider the OAuth `client_id` claim when designing per-client access. Supabase OAuth access tokens otherwise have the same user-data privileges as regular Supabase session tokens.
- Update the ConfigKit privacy policy and support information before inviting community users.

## References

- [Supabase OAuth 2.1 Server setup](https://supabase.com/docs/guides/auth/oauth-server/getting-started)
- [Supabase OAuth 2.1 flows](https://supabase.com/docs/guides/auth/oauth-server/oauth-flows)
- [Supabase JavaScript OAuth server methods](https://supabase.com/docs/reference/javascript/oauth-server-getauthorizationdetails)
