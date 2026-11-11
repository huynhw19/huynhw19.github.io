-- ConfigKit account achievements. Apply after the public activity tables exist.
create schema if not exists private;

create table if not exists public.user_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_key text not null,
  earned_at timestamptz not null default now(),
  primary key (user_id, achievement_key),
  constraint user_achievements_key_check check (achievement_key in (
    'welcome','profile_complete','authenticator','passkey','email_2fa',
    'first_saved_profile','first_shared_profile','community_member',
    'conversation_starter','team_player'
  ))
);

alter table public.user_achievements enable row level security;
create policy "Users can read their own achievements"
  on public.user_achievements for select to authenticated
  using ((select auth.uid()) = user_id);
revoke insert, update, delete on public.user_achievements from anon, authenticated;
grant select on public.user_achievements to authenticated;

create or replace function private.award_user_achievement(p_user_id uuid, p_key text)
returns void language sql security definer set search_path = '' as $$
  insert into public.user_achievements (user_id, achievement_key)
  values (p_user_id, p_key) on conflict (user_id, achievement_key) do nothing;
$$;
revoke all on function private.award_user_achievement(uuid, text) from public, anon, authenticated;

create or replace function private.award_signup_achievement()
returns trigger language plpgsql security definer set search_path = '' as $$
begin perform private.award_user_achievement(new.id, 'welcome'); return new; end; $$;
create trigger award_signup_achievement after insert on auth.users
for each row execute function private.award_signup_achievement();

create or replace function private.award_profile_achievement()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(new.raw_user_meta_data->>'display_name','') <> ''
     or coalesce(new.raw_user_meta_data->>'full_name','') <> ''
     or coalesce(new.raw_user_meta_data->>'institution','') <> ''
     or coalesce(new.raw_user_meta_data->>'workplace','') <> ''
     or coalesce(new.raw_user_meta_data->>'organization_name','') <> '' then
    perform private.award_user_achievement(new.id, 'profile_complete');
  end if;
  return new;
end; $$;
create trigger award_profile_achievement after insert or update of raw_user_meta_data on auth.users
for each row execute function private.award_profile_achievement();

create or replace function private.award_mfa_achievement()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'verified' and new.factor_type = 'totp' then
    perform private.award_user_achievement(new.user_id, 'authenticator');
  elsif new.status = 'verified' and new.factor_type = 'webauthn' then
    perform private.award_user_achievement(new.user_id, 'passkey');
  end if;
  return new;
end; $$;
create trigger award_mfa_achievement after insert or update of status on auth.mfa_factors
for each row execute function private.award_mfa_achievement();

create or replace function private.award_email_2fa_achievement()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.enabled then perform private.award_user_achievement(new.user_id, 'email_2fa'); end if;
  return new;
end; $$;
create trigger award_email_2fa_achievement after insert or update of enabled on public.email_2fa_settings
for each row execute function private.award_email_2fa_achievement();

create or replace function private.award_saved_profile_achievement()
returns trigger language plpgsql security definer set search_path = '' as $$
begin perform private.award_user_achievement(new.user_id, 'first_saved_profile'); return new; end; $$;
create trigger award_saved_profile_achievement after insert on public.saved_profiles
for each row execute function private.award_saved_profile_achievement();

create or replace function private.award_shared_profile_achievement()
returns trigger language plpgsql security definer set search_path = '' as $$
begin perform private.award_user_achievement(new.user_id, 'first_shared_profile'); return new; end; $$;
create trigger award_shared_profile_achievement after insert on public.mobileconfig_posts
for each row execute function private.award_shared_profile_achievement();

create or replace function private.award_follow_achievement()
returns trigger language plpgsql security definer set search_path = '' as $$
begin perform private.award_user_achievement(new.follower_id, 'community_member'); return new; end; $$;
create trigger award_follow_achievement after insert on public.user_follows
for each row execute function private.award_follow_achievement();

create or replace function private.award_discussion_achievement()
returns trigger language plpgsql security definer set search_path = '' as $$
begin perform private.award_user_achievement(new.user_id, 'conversation_starter'); return new; end; $$;
create trigger award_discussion_achievement after insert on public.builder_discussions
for each row execute function private.award_discussion_achievement();

create or replace function private.award_group_achievement()
returns trigger language plpgsql security definer set search_path = '' as $$
begin perform private.award_user_achievement(new.user_id, 'team_player'); return new; end; $$;
create trigger award_group_achievement after insert on public.configkit_group_members
for each row execute function private.award_group_achievement();

-- Existing users and qualifying activity are backfilled when the feature is installed.
insert into public.user_achievements (user_id, achievement_key)
select id, 'welcome' from auth.users on conflict do nothing;
insert into public.user_achievements (user_id, achievement_key)
select id, 'profile_complete' from auth.users
where coalesce(raw_user_meta_data->>'display_name','') <> ''
   or coalesce(raw_user_meta_data->>'full_name','') <> ''
   or coalesce(raw_user_meta_data->>'institution','') <> ''
   or coalesce(raw_user_meta_data->>'workplace','') <> ''
   or coalesce(raw_user_meta_data->>'organization_name','') <> ''
on conflict do nothing;
insert into public.user_achievements (user_id, achievement_key)
select user_id, case factor_type when 'totp' then 'authenticator' else 'passkey' end
from auth.mfa_factors where status = 'verified' and factor_type in ('totp','webauthn')
on conflict do nothing;
insert into public.user_achievements (user_id, achievement_key)
select user_id, 'email_2fa' from public.email_2fa_settings where enabled on conflict do nothing;
insert into public.user_achievements (user_id, achievement_key)
select distinct user_id, 'first_saved_profile' from public.saved_profiles on conflict do nothing;
insert into public.user_achievements (user_id, achievement_key)
select distinct user_id, 'first_shared_profile' from public.mobileconfig_posts on conflict do nothing;
insert into public.user_achievements (user_id, achievement_key)
select distinct follower_id, 'community_member' from public.user_follows on conflict do nothing;
insert into public.user_achievements (user_id, achievement_key)
select distinct user_id, 'conversation_starter' from public.builder_discussions on conflict do nothing;
insert into public.user_achievements (user_id, achievement_key)
select distinct user_id, 'team_player' from public.configkit_group_members on conflict do nothing;
