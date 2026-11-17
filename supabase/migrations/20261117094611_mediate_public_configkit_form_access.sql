drop policy "Anyone can view published ConfigKit forms" on public.configkit_forms;
drop policy "Users view owned and published forms" on public.configkit_forms;
create policy "Form owners view their own forms" on public.configkit_forms
for select to authenticated using ((select auth.uid())=user_id);
drop policy "Respondents submit to published forms" on public.configkit_form_submissions;
revoke all on table public.configkit_forms from anon;
revoke insert on table public.configkit_form_submissions from anon,authenticated;
grant select,insert,update,delete on table public.configkit_forms to authenticated,service_role;
grant select,insert,update,delete on table public.configkit_form_submissions to service_role;
grant select,delete on table public.configkit_form_submissions to authenticated;
comment on table public.configkit_forms is 'User-owned ConfigKit Forms definitions. Public respondent access is mediated by the configkit-form-public Edge Function; form management is owner-only.';
comment on table public.configkit_form_submissions is 'Private form response records. Public submissions are validated by the configkit-form-public Edge Function; only the form owner can read or delete responses.';
