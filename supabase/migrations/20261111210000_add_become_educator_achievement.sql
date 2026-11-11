alter table public.user_achievements
  drop constraint if exists user_achievements_achievement_key_check;

alter table public.user_achievements
  add constraint user_achievements_achievement_key_check
  check (achievement_key = any (array[
    'welcome','profile_complete','authenticator','passkey','email_2fa',
    'first_saved_profile','first_shared_profile','community_member',
    'conversation_starter','team_player','become_educator'
  ]));

create or replace function private.award_educator_achievement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'published' then
    perform private.award_user_achievement(new.user_id, 'become_educator');
  end if;
  return new;
end;
$$;

revoke all on function private.award_educator_achievement() from public, anon, authenticated;

drop trigger if exists award_educator_achievement on public.education_slideshows;
create trigger award_educator_achievement
after insert or update of status on public.education_slideshows
for each row
when (new.status = 'published')
execute function private.award_educator_achievement();

insert into public.user_achievements (user_id, achievement_key)
select distinct user_id, 'become_educator'
from public.education_slideshows
where status = 'published'
on conflict (user_id, achievement_key) do nothing;
