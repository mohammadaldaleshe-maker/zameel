-- Non-destructive verification; fixture rows are rolled back. No dispatcher,
-- media deletion, real-account cleanup or Auth deletion is called.
begin;
do $$
declare id uuid:=gen_random_uuid(); uid uuid:=gen_random_uuid(); token uuid:=gen_random_uuid(); claimed jsonb; lease uuid;
begin
 if has_table_privilege('authenticated','public.zameel_account_deletion_jobs','SELECT') then
  raise exception 'job_table_exposed'; end if;
 if has_function_privilege('authenticated','public.zameel_remove_account_data(uuid,uuid)','EXECUTE') then
  raise exception 'worker_function_exposed'; end if;
 if not has_function_privilege('authenticated','public.delete_my_account()','EXECUTE') then
  raise exception 'user_request_missing'; end if;
 insert into public.zameel_account_deletion_jobs(id,user_id,token,lease_until)
  values(id,uid,token,now()+interval '5 minutes');
 if public.zameel_claim_account_deletion(id,gen_random_uuid()) is not null then raise exception 'invalid_token_accepted'; end if;
 claimed:=public.zameel_claim_account_deletion(id,token);
 if claimed is null or claimed->>'user_id'<>uid::text then raise exception 'claim_failed'; end if;
 if public.zameel_claim_account_deletion(id,token) is not null then raise exception 'token_replay_accepted'; end if;
 lease:=(claimed->>'lease')::uuid;
 begin
  perform public.zameel_finish_account_deletion(id,lease);
  raise exception 'incomplete_job_finished';
 exception when others then
  if sqlerrm not in ('invalid_worker_lease','deletion_not_complete') then raise; end if;
 end;
end $$;
rollback;
select 'PASS: access isolation, one-time claims and incomplete-job protection' as result;
