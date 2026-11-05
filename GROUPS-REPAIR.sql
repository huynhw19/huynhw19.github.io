-- Repair existing ConfigKit groups whose creator was not added to the
-- membership table. The groups page intentionally lists memberships rather
-- than every row in configkit_groups, so a group without this row is invisible
-- to its creator under the current RLS policies.
--
-- Run once in the Supabase SQL Editor using the project's database owner role.
-- This is safe to rerun: the primary key and ON CONFLICT prevent duplicates.

insert into public.configkit_group_members (group_id, user_id)
select g.id, g.created_by
from public.configkit_groups as g
where not exists (
  select 1
  from public.configkit_group_members as m
  where m.group_id = g.id
    and m.user_id = g.created_by
)
on conflict (group_id, user_id) do nothing;

-- Optional verification: this should return 0 after the repair.
select count(*) as groups_missing_creator_membership
from public.configkit_groups as g
left join public.configkit_group_members as m
  on m.group_id = g.id
 and m.user_id = g.created_by
where m.group_id is null;
