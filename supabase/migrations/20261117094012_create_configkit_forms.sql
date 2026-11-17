create table public.configkit_forms (
  id uuid primary key default gen_random_uuid(),
  public_token uuid not null unique default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'Untitled form' check (char_length(btrim(title)) between 1 and 140),
  description text not null default '' check (char_length(description) <= 3000),
  fields jsonb not null default '[]'::jsonb check (jsonb_typeof(fields) = 'array' and jsonb_array_length(fields) <= 50 and pg_column_size(fields) <= 65536),
  settings jsonb not null default '{}'::jsonb check (jsonb_typeof(settings) = 'object' and pg_column_size(settings) <= 8192),
  status text not null default 'draft' check (status in ('draft','published','archived')),
  accepting_responses boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint configkit_forms_id_user_unique unique (id,user_id)
);
create index configkit_forms_owner_updated_idx on public.configkit_forms(user_id,updated_at desc);
create index configkit_forms_public_token_idx on public.configkit_forms(public_token) where status='published';
alter table public.configkit_forms enable row level security;
create policy "Form owners manage their own forms" on public.configkit_forms for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy "Anyone can view published ConfigKit forms" on public.configkit_forms for select to anon using (status='published');
create policy "Signed-in respondents can view published ConfigKit forms" on public.configkit_forms for select to authenticated using (status='published');
revoke all on table public.configkit_forms from public,anon,authenticated;
grant select on table public.configkit_forms to anon;
grant select,insert,update,delete on table public.configkit_forms to authenticated;
create table public.configkit_form_submissions (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null,
  form_owner_id uuid not null,
  answers jsonb not null check (jsonb_typeof(answers)='object' and pg_column_size(answers) <= 32768),
  submitted_at timestamptz not null default now(),
  constraint configkit_form_submissions_form_owner_fkey foreign key (form_id,form_owner_id) references public.configkit_forms(id,user_id) on delete cascade
);
create index configkit_form_submissions_owner_time_idx on public.configkit_form_submissions(form_owner_id,submitted_at desc);
create index configkit_form_submissions_form_time_idx on public.configkit_form_submissions(form_id,submitted_at desc);
alter table public.configkit_form_submissions enable row level security;
create policy "Form owners view their submissions" on public.configkit_form_submissions for select to authenticated using ((select auth.uid())=form_owner_id);
create policy "Respondents submit to published forms" on public.configkit_form_submissions for insert to anon,authenticated with check (exists (select 1 from public.configkit_forms f where f.id=form_id and f.user_id=form_owner_id and f.status='published' and f.accepting_responses=true));
create policy "Form owners delete their submissions" on public.configkit_form_submissions for delete to authenticated using ((select auth.uid())=form_owner_id);
revoke all on table public.configkit_form_submissions from public,anon,authenticated;
grant insert on table public.configkit_form_submissions to anon;
grant select,insert,delete on table public.configkit_form_submissions to authenticated;
comment on table public.configkit_forms is 'User-owned ConfigKit Forms definitions. Published form metadata is readable by public respondents; management is owner-only.';
comment on table public.configkit_form_submissions is 'Private form response records. Respondents can insert answers only into currently published forms; only the form owner can read or delete responses.';
