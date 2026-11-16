alter table public.configkit_trusted_devices
  add constraint configkit_trusted_devices_session_fk
  foreign key (session_id) references auth.sessions(id) on delete cascade;

create or replace function public.is_current_device_trusted()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.configkit_trusted_devices d
    where d.user_id = (select auth.uid())
      and d.session_id::text = (select auth.jwt() ->> 'session_id')
  );
$$;

revoke all on function public.is_current_device_trusted() from public, anon;
grant execute on function public.is_current_device_trusted() to authenticated;
