grant insert on table public.configkit_form_submissions to authenticated;
create policy "Form owners restore their own submissions" on public.configkit_form_submissions
for insert to authenticated with check (
  exists (
    select 1 from public.configkit_forms f
    where f.id=form_id and f.user_id=(select auth.uid())
  )
);
