-- Default project grants are broader than the intended Kids Messages table permissions.
revoke all on public.kids_teacher_contacts,public.kids_education_links,public.kids_adult_conversations,public.kids_adult_messages from authenticated;
grant select on public.kids_teacher_contacts,public.kids_education_links to authenticated;
grant select,insert on public.kids_adult_conversations,public.kids_adult_messages to authenticated;
