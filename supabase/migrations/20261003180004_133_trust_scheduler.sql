-- Supabase supports pg_cron. Enable it from Database / Extensions if needed.
-- Required: expires unattended matches and detects missed database scheduler windows.
create extension if not exists pg_cron;
do $$ begin
 if exists(select 1 from cron.job where jobname='zameel-trust-sweep') then
  perform cron.unschedule('zameel-trust-sweep');
 end if;
 perform cron.schedule('zameel-trust-sweep','* * * * *','select public.zameel_trust_sweep();');
end $$;
