do $$
declare t text;
begin
  foreach t in array array[
    'configkit_collab_documents',
    'configkit_collab_members',
    'configkit_collab_invites',
    'configkit_collab_updates',
    'configkit_collab_comments',
    'configkit_collab_snapshots'
  ] loop
    execute format(
      'alter policy %I on public.%I using (((select auth.jwt())->>''client_id'' is null) and (select private.email_2fa_access_allowed())) with check (((select auth.jwt())->>''client_id'' is null) and (select private.email_2fa_access_allowed()))',
      t || '_verified_session_gate', t
    );
  end loop;
end;
$$;