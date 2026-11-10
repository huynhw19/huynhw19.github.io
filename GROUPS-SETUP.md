# Set up ConfigKit groups

The signed-in groups page is `groups.html`. It lets authenticated users create a group, share a one-time invite code, join by code, view their memberships, and leave groups. Group creators can also rename or permanently delete groups; only the creator is authorized to perform those actions. The group feature stores group names and membership only; it does not share or save mobileconfig profiles. Configure Supabase first with `auth-config.js`. Never put a Supabase service-role key in browser code.

> **Already set up groups before November 2026?** Creating and joining groups failed with the old functions. Run [`GROUPS-REPAIR.sql`](GROUPS-REPAIR.sql) once to fix them — see [`fixgroup.md`](fixgroup.md).

## Apply the database schema

Run this SQL once in the Supabase SQL Editor. The invite code is created server-side from a cryptographically random UUID and is not exposed by group list queries. Creation and joining are RPC-only; row-level security limits memberships and group visibility to members.

```sql
create table if not exists public.configkit_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  invite_code text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.configkit_group_members (
  group_id uuid not null references public.configkit_groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

alter table public.configkit_groups enable row level security;
alter table public.configkit_group_members enable row level security;

grant select on public.configkit_groups to authenticated;
grant select, delete on public.configkit_group_members to authenticated;

create policy "Members can read their groups"
  on public.configkit_groups for select to authenticated
  using (exists (
    select 1 from public.configkit_group_members m
    where m.group_id = id and m.user_id = auth.uid()
  ));

create policy "Members can see their memberships"
  on public.configkit_group_members for select to authenticated
  using (user_id = auth.uid());

create policy "Members can leave their groups"
  on public.configkit_group_members for delete to authenticated
  using (user_id = auth.uid());

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

create or replace function public.update_configkit_group(group_id uuid, group_name text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $
declare
  clean_name text := btrim(update_configkit_group.group_name);
begin
  if auth.uid() is null then raise exception 'Sign in is required.'; end if;
  if clean_name is null or char_length(clean_name) < 1 or char_length(clean_name) > 80 then
    raise exception 'Group name must be between 1 and 80 characters.';
  end if;
  update public.configkit_groups
    set name = clean_name
    where id = update_configkit_group.group_id
      and created_by = auth.uid();
  if not found then raise exception 'Only the group owner can edit this group.'; end if;
  return true;
end;
$;

create or replace function public.delete_configkit_group(group_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $
begin
  if auth.uid() is null then raise exception 'Sign in is required.'; end if;
  delete from public.configkit_groups
    where id = delete_configkit_group.group_id
      and created_by = auth.uid();
  if not found then raise exception 'Only the group owner can delete this group.'; end if;
  return true;
end;
$;

revoke all on function public.update_configkit_group(uuid, text) from public, anon;
revoke all on function public.delete_configkit_group(uuid) from public, anon;
grant execute on function public.update_configkit_group(uuid, text) to authenticated;
grant execute on function public.delete_configkit_group(uuid) to authenticated;

revoke all on function public.create_configkit_group(text) from public, anon;
revoke all on function public.join_configkit_group(text) from public, anon;
grant execute on function public.create_configkit_group(text) to authenticated;
grant execute on function public.join_configkit_group(text) to authenticated;
```

Then deploy the site and visit `groups.html` after signing in. Test create, join from a second account, and leave while signed in. Invite codes are bearer secrets: share them only with intended members. For larger communities, add moderation, abuse controls, and invite rotation through trusted server-side functions before broad use.
