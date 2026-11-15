create policy "email_2fa_session_gate"
  on public.family_accounts as restrictive
  for all to authenticated
  using (private.email_2fa_access_allowed())
  with check (private.email_2fa_access_allowed());

create policy "email_2fa_session_gate"
  on public.family_account_members as restrictive
  for all to authenticated
  using (private.email_2fa_access_allowed())
  with check (private.email_2fa_access_allowed());

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
  if not private.email_2fa_access_allowed() then
    raise exception 'Complete your second-factor verification before creating a family.';
  end if;
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
  if not private.email_2fa_access_allowed() then
    raise exception 'Complete your second-factor verification before joining a family.';
  end if;
  if char_length(clean_code) <> 16 or clean_code !~ '^[A-Z0-9]{16}$' then
    raise exception 'Enter a valid 16-character Family ID.';
  end if;
  select f.* into target_family from public.family_accounts f where f.family_id = clean_code;
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