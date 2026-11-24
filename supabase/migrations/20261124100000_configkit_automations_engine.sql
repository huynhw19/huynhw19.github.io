-- ConfigKit Automations: private scheduled workflows and execution history.
create extension if not exists pg_cron;

create table if not exists public.configkit_automations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 100),
  description text not null default '' check (char_length(description) <= 500),
  trigger_type text not null default 'schedule' check (trigger_type = 'schedule'),
  frequency text not null check (frequency in ('once','daily','weekly','monthly')),
  next_run_at timestamptz not null,
  action_type text not null check (action_type in ('create_task','create_planner_item','send_notification')),
  action_config jsonb not null default '{}'::jsonb,
  is_enabled boolean not null default true,
  last_run_at timestamptz,
  run_count integer not null default 0 check (run_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint configkit_automations_action_config_object check (jsonb_typeof(action_config) = 'object')
);
create index if not exists configkit_automations_due_idx on public.configkit_automations (next_run_at) where is_enabled = true;
create index if not exists configkit_automations_user_idx on public.configkit_automations (user_id, created_at desc);
alter table public.configkit_automations enable row level security;
revoke all on public.configkit_automations from anon;
grant select, insert, update, delete on public.configkit_automations to authenticated;
drop policy if exists "Users manage their own ConfigKit automations" on public.configkit_automations;
create policy "Users manage their own ConfigKit automations" on public.configkit_automations for all to authenticated
using (user_id = (select auth.uid()) and private.email_2fa_access_allowed() and not coalesce((auth.jwt() ? 'client_id'), false))
with check (user_id = (select auth.uid()) and private.email_2fa_access_allowed() and not coalesce((auth.jwt() ? 'client_id'), false));

create table if not exists public.configkit_automation_runs (
  id uuid primary key default gen_random_uuid(),
  automation_id uuid not null references public.configkit_automations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('success','failed')),
  message text not null default '',
  ran_at timestamptz not null default now()
);
create index if not exists configkit_automation_runs_user_idx on public.configkit_automation_runs (user_id, ran_at desc);
alter table public.configkit_automation_runs enable row level security;
revoke all on public.configkit_automation_runs from anon;
grant select on public.configkit_automation_runs to authenticated;
drop policy if exists "Users read their own automation runs" on public.configkit_automation_runs;
create policy "Users read their own automation runs" on public.configkit_automation_runs for select to authenticated
using (user_id = (select auth.uid()) and private.email_2fa_access_allowed() and not coalesce((auth.jwt() ? 'client_id'), false));

create or replace function private.run_configkit_automations()
returns integer language plpgsql security definer
set search_path = pg_catalog, public, private
as $$
declare item record; action jsonb; result_message text; processed integer := 0;
begin
  for item in select * from public.configkit_automations where is_enabled = true and next_run_at <= now()
    order by next_run_at for update skip locked limit 50
  loop
    action := item.action_config; result_message := 'Automation completed.';
    begin
      if item.action_type = 'create_task' then
        insert into public.configkit_tasks (user_id,title,description,status,priority,due_at,reminder_at)
        values (item.user_id,coalesce(nullif(left(action->>'title',160),''),item.name),left(coalesce(action->>'description',''),2000),'todo',
          case when action->>'priority' in ('low','medium','high') then action->>'priority' else 'medium' end,
          case when nullif(action->>'due_in_days','') ~ '^[0-9]{1,3}$' then now()+make_interval(days=>least((action->>'due_in_days')::integer,365)) else null end,null);
        result_message := 'Created a task.';
      elsif item.action_type = 'create_planner_item' then
        insert into public.planner_items (user_id,title,description,item_type,status,priority,category,due_at)
        values (item.user_id,coalesce(nullif(left(action->>'title',160),''),item.name),left(coalesce(action->>'description',''),2000),'task','todo',
          case when action->>'priority' in ('low','normal','high') then action->>'priority' else 'normal' end,'Automation',
          case when nullif(action->>'due_in_days','') ~ '^[0-9]{1,3}$' then now()+make_interval(days=>least((action->>'due_in_days')::integer,365)) else null end);
        result_message := 'Added an item to Daily Planner.';
      elsif item.action_type = 'send_notification' then
        insert into public.configkit_notifications (user_id,actor_user_id,category,event_type,title,body,action_url)
        values (item.user_id,item.user_id,'system','automation.completed',coalesce(nullif(left(action->>'title',120),''),item.name),left(coalesce(action->>'body','Your scheduled automation ran.'),1000),'command-centre.html');
        result_message := 'Created a ConfigKit notification.';
      else raise exception 'Unsupported automation action.';
      end if;
      update public.configkit_automations set last_run_at=now(),run_count=run_count+1,
        next_run_at=case frequency when 'once' then next_run_at when 'daily' then next_run_at+interval '1 day' when 'weekly' then next_run_at+interval '7 days' when 'monthly' then next_run_at+interval '1 month' end,
        is_enabled=case when frequency='once' then false else true end,updated_at=now() where id=item.id;
      insert into public.configkit_automation_runs (automation_id,user_id,status,message) values (item.id,item.user_id,'success',result_message);
    exception when others then
      update public.configkit_automations set last_run_at=now(),run_count=run_count+1,updated_at=now(),
        is_enabled=case when frequency='once' then false else is_enabled end,
        next_run_at=case when frequency='once' then next_run_at when frequency='daily' then now()+interval '1 day' when frequency='weekly' then now()+interval '7 days' when frequency='monthly' then now()+interval '1 month' end
        where id=item.id;
      insert into public.configkit_automation_runs (automation_id,user_id,status,message) values (item.id,item.user_id,'failed',left(sqlerrm,1000));
    end;
    processed:=processed+1;
  end loop;
  return processed;
end; $$;
revoke all on function private.run_configkit_automations() from public,anon,authenticated;
do $$ begin
  if not exists(select 1 from cron.job where jobname='configkit-automation-runner') then
    perform cron.schedule('configkit-automation-runner','* * * * *','select private.run_configkit_automations();');
  end if;
end $$;
