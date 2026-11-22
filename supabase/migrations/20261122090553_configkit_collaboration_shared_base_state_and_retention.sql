alter table public.configkit_collab_documents
  add column base_state_b64 text not null
  check (char_length(base_state_b64) between 1 and 400000);

alter table public.configkit_collab_updates alter column user_id drop not null;
alter table public.configkit_collab_updates drop constraint configkit_collab_updates_user_id_fkey;
alter table public.configkit_collab_updates
  add constraint configkit_collab_updates_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete set null;

alter table public.configkit_collab_snapshots alter column user_id drop not null;
alter table public.configkit_collab_snapshots drop constraint configkit_collab_snapshots_user_id_fkey;
alter table public.configkit_collab_snapshots
  add constraint configkit_collab_snapshots_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete set null;
