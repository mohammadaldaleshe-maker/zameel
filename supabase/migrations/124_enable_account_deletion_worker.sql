-- Run AFTER deploying account-deletion with --no-verify-jwt.
-- Authentication is enforced by one-time, per-job credentials in PostgreSQL.
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('zameel-account-deletion-worker','* * * * *',
 'select public.zameel_dispatch_account_deletions();');
