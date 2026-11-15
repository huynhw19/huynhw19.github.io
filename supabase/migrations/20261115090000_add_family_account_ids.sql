create table if not exists public.family_accounts (
  id uuid primary key default gen_random_uuid(),
  family_id text not null unique
    check (family_id ~ '^[A-Z0-9]{16}$'),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.family_account_members (
  family_id uuid not null references public.family_accounts(id) on delete cascade,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

create index if not exists family_account_members_family_id_idx
  on public.family_account_members(family_id);

alter table public.family_accounts enable row level security;
alter table public.family_account_members enable row level security;

grant select on public.family_accounts to authenticated;
grant select on public.family_account_members to authenticated;

drop policy if exists "Family members can view their family" on public.family_accounts;
create policy "Family members can view their family"
  on public.family_accounts for select to authenticated
  using (exists (
    select 1 from public.family_account_members m
    where m.family_id = family_accounts.id and m.user_id = (select auth.uid())
  ));

drop policy if exists "Members can view their own family membership" on public.family_account_members;
create policy "Members can view their own family membership"
  on public.family_account_members for select to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.create_family_account()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_family public.family_accounts%rowtype;
  new_family_id uuid := gen_random_uuid();
  new_code text := upper(encode(extensions.gen_random_bytes(8), 'hex'));
begin
  if auth.uid() is null then raise exception 'Sign in is required.'; end if;

  select f.* into existing_family
  from public.family_accounts f
  join public.family_account_members m on m.family_id = f.id
  where m.user_id = (select auth.uid());

  if found then return existing_family.family_id; end if;

  insert into public.family_accounts(id, family_id, created_by)
  values (new_family_id, new_code, (select auth.uid()));

  insert into public.family_account_members(family_id, user_id, role)
  values (new_family_id, (select auth.uid()), 'owner');

  return new_code;
end;
$$;

create or replace function public.join_family_account(p_family_id text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  clean_code text := upper(regexp_replace(coalesce(p_family_id, ''), '\s', '', 'g'));
  target_family public.family_accounts%rowtype;
  existing_family public.family_accounts%rowtype;
begin
  if auth.uid() is null then raise exception 'Sign in is required.'; end if;
  if char_length(clean_code) <> 16 or clean_code !~ '^[A-Z0-9]{16}$' then
    raise exception 'Enter a valid 16-character Family ID.';
  end if;

  select f.* into target_family
  from public.family_accounts f
  where f.family_id = clean_code;
  if not found then raise exception 'Family ID not found. Check the code and try again.'; end if;

  select f.* into existing_family
  from public.family_accounts f
  join public.family_account_members m on m.family_id = f.id
  where m.user_id = (select auth.uid());

  if found then
    if existing_family.id = target_family.id then return target_family.family_id; end if;
    raise exception 'This account already belongs to another family.';
  end if;

  insert into public.family_account_members(family_id, user_id, role)
  values (target_family.id, (select auth.uid()), 'member');

  return target_family.family_id;
end;
$$;

revoke all on function public.create_family_account() from public, anon;
revoke all on function public.join_family_account(text) from public, anon;
grant execute on function public.create_family_account() to authenticated;
grant execute on function public.join_family_account(text) to authenticated;
