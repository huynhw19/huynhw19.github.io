-- If an approved author loses approval, automatically unpublish their active titles.
create or replace function private.configkit_sync_community_book_author_profile()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
 if tg_op='DELETE' then
  delete from public.community_book_author_profiles where user_id=old.user_id;
  update public.community_books set status='archived',updated_at=now()
   where author_id=old.user_id and status='published';
  return old;
 end if;
 if new.status='approved' then
  insert into public.community_book_author_profiles(user_id,pen_name,biography,genres,updated_at)
  values(new.user_id,new.pen_name,new.biography,new.genres,now())
  on conflict(user_id) do update set pen_name=excluded.pen_name,biography=excluded.biography,genres=excluded.genres,updated_at=now();
 else
  delete from public.community_book_author_profiles where user_id=new.user_id;
  if old.status='approved' then
   update public.community_books set status='archived',updated_at=now()
    where author_id=new.user_id and status='published';
  end if;
 end if;
 return new;
end;
$function$;
