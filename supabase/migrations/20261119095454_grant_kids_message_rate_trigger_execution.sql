-- Trigger functions are not API-exposed, but authenticated inserts need execute permission for the BEFORE INSERT trigger to run.
grant execute on function private.enforce_kids_message_rate_limit() to authenticated;
