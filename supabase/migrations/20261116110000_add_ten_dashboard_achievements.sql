-- Add ten activity-based ConfigKit dashboard achievements.
alter table public.user_achievements
  drop constraint if exists user_achievements_key_check,
  drop constraint if exists user_achievements_achievement_key_check;
alter table public.user_achievements add constraint user_achievements_achievement_key_check
check (achievement_key = any (array[
'welcome','profile_complete','authenticator','passkey','email_2fa',
'first_saved_profile','first_shared_profile','community_member','conversation_starter',
'team_player','become_educator','first_comment','first_message','event_attendee',
'learning_learner','tool_publisher','app_publisher','game_creator',
'marketplace_creator','first_purchase','prolific_creator'
]));

create or replace function private.award_new_achievement()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_user_id uuid;
begin
 v_user_id := nullif(to_jsonb(new)->>tg_argv[0], '')::uuid;
 if v_user_id is not null then perform private.award_user_achievement(v_user_id,tg_argv[1]); end if;
 return new;
end; $$;
revoke all on function private.award_new_achievement() from public,anon,authenticated;

create trigger award_first_comment after insert on public.builder_discussion_comments
for each row execute function private.award_new_achievement('user_id','first_comment');
create trigger award_first_message after insert on public.mail_messages
for each row when (new.sender_user_id is not null)
execute function private.award_new_achievement('sender_user_id','first_message');
create trigger award_event_attendee after insert on public.community_event_rsvps
for each row execute function private.award_new_achievement('user_id','event_attendee');
create trigger award_tool_publisher after insert or update of status on public.configkit_tools
for each row when (new.status='published')
execute function private.award_new_achievement('owner_id','tool_publisher');
create trigger award_app_publisher after insert or update of status on public.configkit_apps
for each row when (new.status='published')
execute function private.award_new_achievement('owner_id','app_publisher');
create trigger award_game_creator after insert or update of status on public.community_games
for each row when (new.status='published')
execute function private.award_new_achievement('created_by','game_creator');
create trigger award_marketplace_creator after insert or update of status on public.community_store_items
for each row when (new.status='published')
execute function private.award_new_achievement('seller_id','marketplace_creator');

create or replace function private.award_first_purchase()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if new.status in ('paid','delivered') and new.buyer_id is not null then
  perform private.award_user_achievement(new.buyer_id,'first_purchase');
 end if;
 return new;
end; $$;
revoke all on function private.award_first_purchase() from public,anon,authenticated;
create trigger award_first_purchase after insert or update of status on public.community_store_orders
for each row when (new.status in ('paid','delivered'))
execute function private.award_first_purchase();

create or replace function private.award_learning_milestone()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if new.is_correct and (select count(*) from public.education_learning_progress
   where student_user_id=new.student_user_id and is_correct)>=10 then
  perform private.award_user_achievement(new.student_user_id,'learning_learner');
 end if;
 return new;
end; $$;
revoke all on function private.award_learning_milestone() from public,anon,authenticated;
create trigger award_learning_milestone after insert on public.education_learning_progress
for each row execute function private.award_learning_milestone();

create or replace function private.award_prolific_creator()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if new.status='published' and (select count(*) from public.configkit_tools
   where owner_id=new.owner_id and status='published')>=3 then
  perform private.award_user_achievement(new.owner_id,'prolific_creator');
 end if;
 return new;
end; $$;
revoke all on function private.award_prolific_creator() from public,anon,authenticated;
create trigger award_prolific_creator after insert or update of status on public.configkit_tools
for each row when (new.status='published')
execute function private.award_prolific_creator();

insert into public.user_achievements(user_id,achievement_key)
select distinct user_id,'first_comment' from public.builder_discussion_comments on conflict do nothing;
insert into public.user_achievements(user_id,achievement_key)
select distinct sender_user_id,'first_message' from public.mail_messages where sender_user_id is not null on conflict do nothing;
insert into public.user_achievements(user_id,achievement_key)
select distinct user_id,'event_attendee' from public.community_event_rsvps on conflict do nothing;
insert into public.user_achievements(user_id,achievement_key)
select distinct owner_id,'tool_publisher' from public.configkit_tools where status='published' on conflict do nothing;
insert into public.user_achievements(user_id,achievement_key)
select distinct owner_id,'app_publisher' from public.configkit_apps where status='published' on conflict do nothing;
insert into public.user_achievements(user_id,achievement_key)
select distinct created_by,'game_creator' from public.community_games where status='published' on conflict do nothing;
insert into public.user_achievements(user_id,achievement_key)
select distinct seller_id,'marketplace_creator' from public.community_store_items where status='published' on conflict do nothing;
insert into public.user_achievements(user_id,achievement_key)
select distinct buyer_id,'first_purchase' from public.community_store_orders where status in ('paid','delivered') on conflict do nothing;
insert into public.user_achievements(user_id,achievement_key)
select student_user_id,'learning_learner' from public.education_learning_progress
where is_correct group by student_user_id having count(*)>=10 on conflict do nothing;
insert into public.user_achievements(user_id,achievement_key)
select owner_id,'prolific_creator' from public.configkit_tools
where status='published' group by owner_id having count(*)>=3 on conflict do nothing;
