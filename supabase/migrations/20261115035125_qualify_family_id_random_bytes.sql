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