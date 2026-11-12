create or replace function public.kids_check_pin(p_child_id uuid,p_parent_id uuid,p_pin text)
returns uuid language plpgsql security definer set search_path='' as $$
declare cred private.kids_pin_credentials%rowtype; linked_user uuid;
begin
 select c.child_user_id into linked_user from public.family_children c where c.id=p_child_id and c.parent_id=p_parent_id;
 if linked_user is null then raise exception 'Profile or PIN is not available'; end if;
 select * into cred from private.kids_pin_credentials where child_id=p_child_id for update;
 if not found then raise exception 'Profile or PIN is not available'; end if;
 if cred.locked_until is not null and cred.locked_until>now() then raise exception 'Too many attempts. Try again later.'; end if;
 if extensions.crypt(coalesce(p_pin,''),cred.pin_hash)<>cred.pin_hash then
   update private.kids_pin_credentials set failed_attempts=least(failed_attempts+1,5),
     locked_until=case when failed_attempts+1>=5 then now()+interval '15 minutes' else null end,
     updated_at=now() where child_id=p_child_id;
   return null;
 end if;
 update private.kids_pin_credentials set failed_attempts=0,locked_until=null,updated_at=now() where child_id=p_child_id;
 return linked_user;
end; $$;