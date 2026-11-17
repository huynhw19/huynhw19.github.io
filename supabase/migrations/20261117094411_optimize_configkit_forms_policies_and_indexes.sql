drop policy "Form owners manage their own forms" on public.configkit_forms;
drop policy "Signed-in respondents can view published ConfigKit forms" on public.configkit_forms;
create policy "Users view owned and published forms" on public.configkit_forms
for select to authenticated using ((select auth.uid())=user_id or status='published');
create policy "Form owners create their own forms" on public.configkit_forms
for insert to authenticated with check ((select auth.uid())=user_id);
create policy "Form owners update their own forms" on public.configkit_forms
for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy "Form owners delete their own forms" on public.configkit_forms
for delete to authenticated using ((select auth.uid())=user_id);
drop index if exists public.configkit_forms_public_token_idx;
drop index if exists public.configkit_form_submissions_form_time_idx;
