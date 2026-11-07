# Enterprise jobs for Builder Discussion

The jobs section is available to signed-in accounts whose Supabase `user_metadata.account_type` is `enterprise` or `organization`. The account type is self-declared; it is not an organization verification or authorization system.

## Configure the Supabase table

Run this SQL once in the Supabase SQL Editor for the project configured in `auth-config.js`:

```sql
create table if not exists public.enterprise_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  company_name text not null check (char_length(company_name) between 1 and 120),
  title text not null check (char_length(title) between 1 and 120),
  location text not null default '' check (char_length(location) <= 120),
  employment_type text not null default '' check (char_length(employment_type) <= 80),
  description text not null check (char_length(description) between 1 and 5000),
  application_url text not null default '' check (char_length(application_url) <= 2048),
  created_at timestamptz not null default now()
);

alter table public.enterprise_jobs enable row level security;
grant select, insert on public.enterprise_jobs to authenticated;

create policy "Signed-in users can read enterprise jobs"
  on public.enterprise_jobs for select to authenticated using (true);

create policy "Enterprise accounts can post jobs as themselves"
  on public.enterprise_jobs for insert to authenticated
  with check (
    auth.uid() = user_id
    and coalesce(auth.jwt() -> 'user_metadata' ->> 'account_type', '') in ('enterprise', 'organization')
  );
```

The discussion page also checks the signed-in account type before showing the job board and posting form. The database policy is important: it independently prevents other account types from inserting job listings.

## Use and safety

Enterprise/organization accounts can post and browse listings. Other signed-in users can read listings directly through the database policy but the Builder Discussion UI displays the section only to enterprise/organization accounts. Job listings are public to authenticated users; do not include confidential information or sensitive personal data. Validate application URLs and job content before following or acting on them.
