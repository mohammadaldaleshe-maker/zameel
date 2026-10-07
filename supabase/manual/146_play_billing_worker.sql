-- Install only AFTER the function and secrets are configured. No key is embedded here.
-- Vault name: zameel_billing_worker_secret; value must equal Edge Secret ZAMEEL_BILLING_WORKER_SECRET.
begin;
do $$begin
 if (select count(*) from vault.decrypted_secrets where name='zameel_billing_worker_secret')<>1 then
  raise exception 'Create exactly one Vault secret named zameel_billing_worker_secret first';
 end if;
end $$;
-- Repeatable scheduling; avoid duplicate dispatchers.
select cron.unschedule(jobid) from cron.job where jobname='zameel-play-billing-every-minute';
select cron.schedule('zameel-play-billing-every-minute','* * * * *',$job$
 select net.http_post(
  url:='https://jwuqyykjmltroneqtjoc.supabase.co/functions/v1/play-billing',
  headers:=jsonb_build_object('Content-Type','application/json','x-zameel-billing-secret',
    (select decrypted_secret from vault.decrypted_secrets where name='zameel_billing_worker_secret')),
  body:='{"action":"reconcile"}'::jsonb,
  timeout_milliseconds:=90000
 );
$job$);
commit;
