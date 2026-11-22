# ConfigKit invited-member onboarding

This flow is for accounts created with Supabase Auth's **Invite user by email** operation. It is separate from normal self-service sign-up.

## Invitation redirect

When sending an invitation with Supabase Admin Auth, set the redirect URL to:

`https://huynhw19.github.io/accept-invitation.html?type=invite`

For example, from a trusted server or Supabase Edge Function (never browser code):

```js
await supabaseAdmin.auth.admin.inviteUserByEmail(email, {
  redirectTo: 'https://huynhw19.github.io/accept-invitation.html?type=invite'
});
```

The invitation sender must use the Supabase **service-role/secret key only on the trusted server**. Never put that key in GitHub Pages, `auth-config.js`, or browser JavaScript.

Add the exact redirect URL above to **Supabase Dashboard → Authentication → URL Configuration → Redirect URLs**. Confirm the Invite user email template uses Supabase's standard confirmation URL (`{{ .ConfirmationURL }}`) so the invitation token is verified by Supabase before the browser is redirected.

## Invited member journey

1. Supabase verifies the invitation token and redirects to `accept-invitation.html?type=invite`.
2. The page requires a signed-in, email-confirmed Supabase session and marks the account as pending ConfigKit invitation onboarding.
3. The member reviews the Welcome page, Privacy Policy and Terms of Service, then records agreement.
4. The member creates and confirms a unique password (minimum 12 characters).
5. The member reaches **Secure your account**, where authenticator-app MFA, passkeys and recovery-code setup are offered. These security methods remain optional and can be configured later.
6. Continuing finishes the invitation onboarding and opens the intended ConfigKit destination.

The invitation flow marks the optional onboarding questions as skipped so invited members are not forced through a second questionnaire.

## Important

- This is a front-end acceptance flow. It does not add a public invitation-sending feature or a service-role credential to the website.
- Invite links are single-use/expiry-controlled by Supabase Auth. If a link has expired or been used, send a fresh invitation.
- Test with a new test email address and a real invitation from a trusted server. Do not test by manually adding `?type=invite` to an ordinary signed-in URL.
