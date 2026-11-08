-- Fix ConfigKit groups. Run this whole file once in the Supabase SQL Editor
-- (project used by the live site). It is safe to rerun.
--
-- Part 1 replaces the two group functions:
--   * "Create group" failed with: function gen_random_bytes(integer) does not exist
--     (pgcrypto is not on the function's empty search_path). Invite codes now
--     come from gen_random_uuid(), which is built in.
--   * "Join group" failed with: column reference "group_id" is ambiguous
--     (the function's output column clashed with the table column).
-- Existing invite codes keep working.

create or replace function public.create_configkit_group(group_name text)
returns table(group_id uuid, invite_code text)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  new_id uuid := gen_random_uuid();
  new_code text := replace(gen_random_uuid()::text, '-', '');
  clean_name text := btrim(create_configkit_group.group_name);
begin
  if auth.uid() is null then raise exception 'Sign in is required.'; end if;
  if clean_name is null or char_length(clean_name) < 1 or char_length(clean_name) > 80 then
    raise exception 'Group name must be between 1 and 80 characters.';
  end if;
  insert into public.configkit_groups(id, name, invite_code, created_by)
    values (new_id, clean_name, new_code, auth.uid());
  insert into public.configkit_group_members(group_id, user_id)
    values (new_id, auth.uid())
    on conflict on constraint configkit_group_members_pkey do nothing;
  return query select new_id, new_code;
end;
$$;

create or replace function public.join_configkit_group(invite_code text)
returns table(group_id uuid, group_name text)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  found_group public.configkit_groups%rowtype;
  clean_code text := lower(regexp_replace(coalesce(join_configkit_group.invite_code, ''), '\s', '', 'g'));
begin
  if auth.uid() is null then raise exception 'Sign in is required.'; end if;
  select * into found_group from public.configkit_groups g where g.invite_code = clean_code;
  if not found then raise exception 'Invite code not found.'; end if;
  insert into public.configkit_group_members(group_id, user_id)
    values (found_group.id, auth.uid())
    on conflict on constraint configkit_group_members_pkey do nothing;
  return query select found_group.id, found_group.name;
end;
$$;

revoke all on function public.create_configkit_group(text) from public, anon;
revoke all on function public.join_configkit_group(text) from public, anon;
grant execute on function public.create_configkit_group(text) to authenticated;
grant execute on function public.join_configkit_group(text) to authenticated;

-- Part 2: repair existing groups whose creator was not added to the
-- membership table. The groups page lists memberships rather than every row
-- in configkit_groups, so a group without this row is invisible to its creator.

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
