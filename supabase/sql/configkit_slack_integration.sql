create schema if not exists private;
create table if not exists private.configkit_slack_oauth_states (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  state_hash text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at timestamptz
);
create index if not exists configkit_slack_oauth_states_expiry_idx on private.configkit_slack_oauth_states (expires_at);
create table if not exists private.configkit_slack_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  team_id text not null,
  team_name text not null,
  bot_user_id text,
  access_token_ciphertext text not null,
  access_token_iv text not null,
  refresh_token_ciphertext text,
  refresh_token_iv text,
  expires_at timestamptz,
  granted_scopes text[] not null default '{}',
  connected_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, team_id)
);
create index if not exists configkit_slack_connections_user_idx on private.configkit_slack_connections (user_id);
alter table private.configkit_slack_oauth_states enable row level security;
alter table private.configkit_slack_connections enable row level security;
revoke all on private.configkit_slack_oauth_states from public, anon, authenticated;
revoke all on private.configkit_slack_connections from public, anon, authenticated;
grant usage on schema private to service_role;
grant all on private.configkit_slack_oauth_states to service_role;
grant all on private.configkit_slack_connections to service_role;