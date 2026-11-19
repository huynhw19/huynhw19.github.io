-- Expose only approved author profile fields; never expose private application samples or admin notes.
create table if not exists public.community_book_author_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 pen_name text not null,
 biography text not null,
 genres text[] not null default '{}'::text[],
 updated_at timestamptz not null default now()
);
alter table public.community_book_author_profiles enable row level security;
drop policy if exists community_book_author_profiles_read on public.community_book_author_profiles;
create policy community_book_author_profiles_read on public.community_book_author_profiles for select to authenticated using (true);
revoke all on public.community_book_author_profiles from anon,public,authenticated;
grant select on public.community_book_author_profiles to authenticated;

create or replace function private.configkit_sync_community_book_author_profile()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
 if tg_op='DELETE' then
  delete from public.community_book_author_profiles where user_id=old.user_id;
  return old;
 end if;
 if new.status='approved' then
  insert into public.community_book_author_profiles(user_id,pen_name,biography,genres,updated_at)
  values(new.user_id,new.pen_name,new.biography,new.genres,now())
  on conflict(user_id) do update set pen_name=excluded.pen_name,biography=excluded.biography,genres=excluded.genres,updated_at=now();
 else
  delete from public.community_book_author_profiles where user_id=new.user_id;
 end if;
 return new;
end;
$function$;
drop trigger if exists community_book_author_profile_sync on public.community_book_authors;
create trigger community_book_author_profile_sync after insert or update of status,pen_name,biography,genres or delete
on public.community_book_authors for each row execute function private.configkit_sync_community_book_author_profile();
