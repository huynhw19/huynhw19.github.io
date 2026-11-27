# Family Rewards & Achievements Centre

Live page: https://huynhw19.github.io/family-rewards.html

## What it does

- Parents can create reward choices for each child profile.
- Parents can award points for effort, kindness, helpfulness and learning.
- Children with a linked child sign-in can view their available balance and request an active reward.
- Parents review redemption requests. Approval deducts points; declining leaves the balance unchanged.
- Parent and child views refresh from Supabase Realtime.
- The existing 50 Kids Achievements page remains available as a separate set of browser-saved challenges.

Points are family encouragement, not money, grades or a measure of a child's worth. Families should agree on fair and age-appropriate reward expectations.

## Database

Migration tables:

- `public.family_reward_catalog`: parent-managed reward options, scoped to one family and child.
- `public.family_reward_activity`: immutable point awards and child redemption requests/reviews.

Both tables have RLS enabled, no anon access, authenticated grants limited to the operations used by the page, verified-session and OAuth-client restrictive gates, and Realtime publication membership.

The policies scope parents to their own child profiles and children to their own linked profile. Children can only create pending redemption requests for active rewards. Parents can award points and review pending requests. A database trigger prevents editing the core details of an activity and checks the available points again when a parent approves a redemption, preventing over-redemption from concurrent requests.

## How to use

1. Sign in to the Family Dashboard and make sure a Family ID is set up.
2. Open the child-specific **Rewards & Points** shortcut on a child profile.
3. Create one or more rewards and award points for positive actions.
4. Open Kids Zone as the linked child account and choose **Family Rewards & Points**.
5. The child can request a reward when their approved balance is sufficient; the parent approves or declines it from the dashboard.

A child needs a linked `family_children.child_user_id` sign-in to use the child view. A guest can still use public Kids Zone activities but cannot see private family reward balances.

## Verification

- RLS, grants, policies and Realtime publication were checked after migration.
- Supabase project-wide advisors still report pre-existing findings on unrelated tables/functions (including a user-metadata RLS policy on `enterprise_jobs` and existing callable security-definer functions). These are outside the two new rewards tables and were not changed by this feature.
- Complete acceptance testing still requires separate parent and linked-child sessions on the live Pages site.
