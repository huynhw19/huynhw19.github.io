revoke insert, update on public.family_children from authenticated;
grant insert (parent_id, child_name, age_years, grade, notes) on public.family_children to authenticated;
grant update (child_name, age_years, grade, notes, messaging_enabled) on public.family_children to authenticated;