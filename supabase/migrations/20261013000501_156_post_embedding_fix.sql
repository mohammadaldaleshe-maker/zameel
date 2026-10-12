begin;
-- Keep the private mention links, but do not advertise a second posts/users
-- relationship to legacy PostgREST embedding requests.
lock table public.zameel_post_mentions156 in access exclusive mode nowait;
alter table public.zameel_post_mentions156 add column if not exists id uuid not null default gen_random_uuid();
do $$
begin
 if not exists(select 1 from pg_constraint where conrelid='public.zameel_post_mentions156'::regclass and conname='zameel_post_mentions156_post_user_key') then
  alter table public.zameel_post_mentions156 add constraint zameel_post_mentions156_post_user_key unique(post_id,user_id);
 end if;
end $$;
alter table public.zameel_post_mentions156 drop constraint if exists zameel_post_mentions156_pkey;
alter table public.zameel_post_mentions156 add constraint zameel_post_mentions156_pkey primary key(id);
-- No post rows, visibility rules, grants or foreign keys are changed.
notify pgrst,'reload schema';
commit;
