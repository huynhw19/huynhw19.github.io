-- Disable every existing email-based 2FA enrollment and revoke its outstanding challenges.
update public.email_2fa_settings
   set enabled = false,
       updated_at = pg_catalog.now()
 where enabled = true;

delete from public.email_2fa_challenges;
delete from public.email_2fa_verified_sessions;

-- Preserve previously earned achievement rows as history, but stop awarding
-- the retired email-2FA achievement from future settings changes.
drop trigger if exists award_email_2fa_achievement on public.email_2fa_settings;
drop function if exists private.award_email_2fa_achievement();
