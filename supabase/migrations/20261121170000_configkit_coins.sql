-- ConfigKit Coins: secure rewards, promo redemption and community purchases.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.configkit_coin_ledger (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 amount integer not null check(amount<>0),
 reason text not null check(reason in ('achievement','daily_visit','weekly_visit','promo_code','purchase','sale','admin_adjustment')),
 reference text not null,
 description text not null,
 created_at timestamptz not null default now(),
 unique(user_id,reason,reference)
);
create index if not exists configkit_coin_ledger_user_created_idx on public.configkit_coin_ledger(user_id,created_at desc);
alter table public.configkit_coin_ledger enable row level security;
revoke all on public.configkit_coin_ledger from anon,public;
grant select on public.configkit_coin_ledger to authenticated;
drop policy if exists "Members can read their own coin ledger" on public.configkit_coin_ledger;
create policy "Members can read their own coin ledger" on public.configkit_coin_ledger for select to authenticated using(user_id=(select auth.uid()));

create table if not exists public.configkit_coin_promo_codes (
 code_hash text primary key,label text not null,reward integer not null check(reward>0),active boolean not null default true,created_at timestamptz not null default now()
);
alter table public.configkit_coin_promo_codes enable row level security;
revoke all on public.configkit_coin_promo_codes from anon,authenticated,public;
create table if not exists public.configkit_coin_redemptions (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 code_hash text not null references public.configkit_coin_promo_codes(code_hash),redeemed_at timestamptz not null default now(),unique(user_id,code_hash)
);
alter table public.configkit_coin_redemptions enable row level security;
revoke all on public.configkit_coin_redemptions from anon,public;
grant select on public.configkit_coin_redemptions to authenticated;
drop policy if exists "Members can view own coin code redemptions" on public.configkit_coin_redemptions;
create policy "Members can view own coin code redemptions" on public.configkit_coin_redemptions for select to authenticated using(user_id=(select auth.uid()));

insert into public.configkit_coin_promo_codes(code_hash,label,reward) values
(encode(extensions.digest('CKC-WELCOME-2026','sha256'),'hex'),'Welcome bonus',50),
(encode(extensions.digest('CKC-CONFIGKIT-START','sha256'),'hex'),'Getting started',50),
(encode(extensions.digest('CKC-COMMUNITY-LOVE','sha256'),'hex'),'Community spirit',50),
(encode(extensions.digest('CKC-BUILD-TOGETHER','sha256'),'hex'),'Builder bonus',50),
(encode(extensions.digest('CKC-COIN-QUEST','sha256'),'hex'),'Coin quest',50),
(encode(extensions.digest('CKC-EXPLORE-MORE','sha256'),'hex'),'Explorer bonus',50),
(encode(extensions.digest('CKC-CREATOR-CLUB','sha256'),'hex'),'Creator bonus',50),
(encode(extensions.digest('CKC-THANK-YOU','sha256'),'hex'),'Thank-you bonus',50),
(encode(extensions.digest('CKC-DAILY-BOOST','sha256'),'hex'),'Daily boost',50),
(encode(extensions.digest('CKC-2026-LAUNCH','sha256'),'hex'),'Launch celebration',50)
on conflict(code_hash) do nothing;

create or replace function public.configkit_coin_balance()
returns integer language sql stable security invoker set search_path=''
as $$ select coalesce(sum(amount),0)::integer from public.configkit_coin_ledger where user_id=(select auth.uid()) $$;
revoke all on function public.configkit_coin_balance() from public;
grant execute on function public.configkit_coin_balance() to authenticated;

create or replace function public.configkit_claim_visit_rewards()
returns table(reward_type text,amount integer,balance integer)
language plpgsql security definer set search_path=''
as $$
declare uid uuid:=auth.uid(); today_key text:=to_char(timezone('utc',now()),'YYYY-MM-DD'); week_key text:=to_char(timezone('utc',now()),'IYYY-"W"IW');
begin
 if uid is null then raise exception 'Sign in to earn ConfigKit Coins.'; end if;
 insert into public.configkit_coin_ledger(user_id,amount,reason,reference,description) values(uid,5,'daily_visit',today_key,'Daily website visit') on conflict(user_id,reason,reference) do nothing;
 if found then reward_type:='daily';amount:=5;return next;end if;
 insert into public.configkit_coin_ledger(user_id,amount,reason,reference,description) values(uid,20,'weekly_visit',week_key,'Weekly website visit') on conflict(user_id,reason,reference) do nothing;
 if found then reward_type:='weekly';amount:=20;return next;end if;
 select coalesce(sum(l.amount),0)::integer into balance from public.configkit_coin_ledger l where l.user_id=uid;
 return;
end;
$$;
revoke all on function public.configkit_claim_visit_rewards() from public,anon;
grant execute on function public.configkit_claim_visit_rewards() to authenticated;

create or replace function public.configkit_redeem_coin_code(p_code text)
returns table(awarded integer,balance integer)
language plpgsql security definer set search_path=''
as $$
declare uid uuid:=auth.uid(); h text; reward_amount integer;
begin
 if uid is null then raise exception 'Sign in to redeem a promo code.';end if;
 if p_code is null or length(btrim(p_code))<4 or length(p_code)>80 then raise exception 'Enter a valid promo code.';end if;
 h:=encode(extensions.digest(upper(regexp_replace(btrim(p_code),'\s','','g')),'sha256'),'hex');
 select c.reward into reward_amount from public.configkit_coin_promo_codes c where c.code_hash=h and c.active;
 if reward_amount is null then raise exception 'That promo code is invalid or inactive.';end if;
 insert into public.configkit_coin_redemptions(user_id,code_hash) values(uid,h) on conflict(user_id,code_hash) do nothing;
 if not found then raise exception 'You have already redeemed this promo code.';end if;
 insert into public.configkit_coin_ledger(user_id,amount,reason,reference,description) values(uid,reward_amount,'promo_code',h,'Promo code reward');
 select coalesce(sum(l.amount),0)::integer into balance from public.configkit_coin_ledger l where l.user_id=uid;
 awarded:=reward_amount;return next;
end;
$$;
revoke all on function public.configkit_redeem_coin_code(text) from public,anon;
grant execute on function public.configkit_redeem_coin_code(text) to authenticated;

create or replace function public.configkit_award_achievement_coins()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 insert into public.configkit_coin_ledger(user_id,amount,reason,reference,description) values(new.user_id,10,'achievement',new.achievement_key,'Achievement: '||new.achievement_key) on conflict(user_id,reason,reference) do nothing;
 return new;
end;
$$;
revoke all on function public.configkit_award_achievement_coins() from public,anon,authenticated;
drop trigger if exists configkit_achievement_coin_reward on public.user_achievements;
create trigger configkit_achievement_coin_reward after insert on public.user_achievements for each row execute function public.configkit_award_achievement_coins();

insert into public.configkit_coin_ledger(user_id,amount,reason,reference,description)
select ua.user_id,10,'achievement',ua.achievement_key,'Achievement: '||ua.achievement_key from public.user_achievements ua
on conflict(user_id,reason,reference) do nothing;

alter table public.community_store_items add column if not exists coin_price integer not null default 0 check(coin_price>=0);
alter table public.configkit_apps add column if not exists coin_price integer not null default 0 check(coin_price>=0);
alter table public.community_store_items drop constraint if exists community_store_items_listing_type_check;
alter table public.community_store_items add constraint community_store_items_listing_type_check check(listing_type in ('free','paid','coins'));
alter table public.community_store_items drop constraint if exists community_store_price_type_check;
alter table public.community_store_items add constraint community_store_price_type_check check(
 (listing_type='free' and price=0 and download_url is not null and download_url ~ '^https://')
 or (listing_type='paid' and price>0 and download_url is null)
 or (listing_type='coins' and price=0 and download_url is null and coin_price>0)
);

create table if not exists public.community_store_coin_files (
 item_id uuid primary key references public.community_store_items(id) on delete cascade,
 download_url text not null check(download_url ~* '^https://'),
 seller_id uuid not null references auth.users(id) on delete cascade
);
alter table public.community_store_coin_files enable row level security;
revoke all on public.community_store_coin_files from anon,public;
grant select,insert,update,delete on public.community_store_coin_files to authenticated;
drop policy if exists "Sellers manage own coin files" on public.community_store_coin_files;
create policy "Sellers manage own coin files" on public.community_store_coin_files for all to authenticated using(seller_id=(select auth.uid())) with check(seller_id=(select auth.uid()));

create table if not exists public.configkit_coin_purchases (
 id uuid primary key default gen_random_uuid(),buyer_id uuid not null references auth.users(id) on delete cascade,
 seller_id uuid not null references auth.users(id) on delete cascade,item_kind text not null check(item_kind in ('app','store')),
 item_id uuid not null,amount integer not null check(amount>0),purchased_at timestamptz not null default now(),
 unique(buyer_id,item_kind,item_id),check(buyer_id<>seller_id)
);
alter table public.configkit_coin_purchases enable row level security;
revoke all on public.configkit_coin_purchases from anon,public;
grant select on public.configkit_coin_purchases to authenticated;
drop policy if exists "Members can read own coin purchases" on public.configkit_coin_purchases;
create policy "Members can read own coin purchases" on public.configkit_coin_purchases for select to authenticated using(buyer_id=(select auth.uid()) or seller_id=(select auth.uid()));

create or replace function public.configkit_purchase_with_coins(p_item_kind text,p_item_id uuid)
returns table(download_url text,file_path text,delivery_type text,amount_paid integer,balance integer)
language plpgsql security definer set search_path=''
as $$
declare uid uuid:=auth.uid(); seller uuid; cost integer; prior public.configkit_coin_purchases%rowtype; item_url text; item_path text; item_delivery text; ref text;
begin
 if uid is null then raise exception 'Sign in to shop with ConfigKit Coins.';end if;
 if p_item_kind not in ('app','store') then raise exception 'Unsupported item type.';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select * into prior from public.configkit_coin_purchases p where p.buyer_id=uid and p.item_kind=p_item_kind and p.item_id=p_item_id;
 if found then
  if p_item_kind='store' then select f.download_url into item_url from public.community_store_coin_files f where f.item_id=p_item_id;
  else select a.file_path,a.delivery_type,a.redirect_url into item_path,item_delivery,item_url from public.configkit_apps a where a.id=p_item_id and a.status='published';end if;
  download_url:=item_url;file_path:=item_path;delivery_type:=item_delivery;amount_paid:=prior.amount;
  select coalesce(sum(l.amount),0)::integer into balance from public.configkit_coin_ledger l where l.user_id=uid;return next;return;
 end if;
 if p_item_kind='store' then
  select i.seller_id,i.coin_price,f.download_url into seller,cost,item_url from public.community_store_items i join public.community_store_coin_files f on f.item_id=i.id where i.id=p_item_id and i.status='published' and i.listing_type='coins';
  item_delivery:='link';
 else
  select a.owner_id,a.coin_price,a.file_path,a.delivery_type,a.redirect_url into seller,cost,item_path,item_delivery,item_url from public.configkit_apps a where a.id=p_item_id and a.status='published';
 end if;
 if seller is null or cost is null or cost<1 then raise exception 'This item is not available for ConfigKit Coin purchases.';end if;
 if seller=uid then raise exception 'You cannot purchase your own listing.';end if;
 if (select coalesce(sum(l.amount),0) from public.configkit_coin_ledger l where l.user_id=uid)<cost then raise exception 'You do not have enough ConfigKit Coins.';end if;
 ref:=p_item_kind||':'||p_item_id::text||':'||uid::text;
 insert into public.configkit_coin_ledger(user_id,amount,reason,reference,description) values(uid,-cost,'purchase',ref,'Purchased a community '||p_item_kind);
 insert into public.configkit_coin_ledger(user_id,amount,reason,reference,description) values(seller,cost,'sale',ref,'Sold a community '||p_item_kind);
 insert into public.configkit_coin_purchases(buyer_id,seller_id,item_kind,item_id,amount) values(uid,seller,p_item_kind,p_item_id,cost);
 download_url:=item_url;file_path:=item_path;delivery_type:=item_delivery;amount_paid:=cost;
 select coalesce(sum(l.amount),0)::integer into balance from public.configkit_coin_ledger l where l.user_id=uid;return next;
end;
$$;
revoke all on function public.configkit_purchase_with_coins(text,uuid) from public,anon;
grant execute on function public.configkit_purchase_with_coins(text,uuid) to authenticated;
