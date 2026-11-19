-- Children can create and read peer messages, but cannot edit or delete sent messages directly.
revoke update,delete on public.kids_messages from authenticated;
