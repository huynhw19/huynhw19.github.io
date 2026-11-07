# Enterprise account and trial preview

`enterprise-dashboard.html` provides a signed-in workspace for accounts marked `enterprise` or the existing `organization` account type. It includes a 14-day trial status display and a getting-started checklist for building and reviewing configuration profiles.

## Sign-up

The existing `login.html` flow already offers an Organization account option and stores the organization name as Supabase user metadata. Use that option to sign up, then open `enterprise-dashboard.html`. The dashboard accepts Organization accounts for compatibility with existing users. The page is intentionally separate from the existing organization dashboard so existing workflows are unchanged.

## Trial limitation

This is a UI/demo trial preview only. The first visit writes `free_trial_started_at` to Supabase user metadata, which is user-editable and client-side. There is no billing integration, trusted trial enforcement, paid-plan feature gating, organization verification, or seat management. Do not use this metadata to grant paid access. A production trial requires a trusted backend to establish and validate the trial period and a billing provider if payment collection is needed.
