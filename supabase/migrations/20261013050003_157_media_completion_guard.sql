begin;
set local lock_timeout = '3s';
-- Guard only the new durable publisher. Legacy clients' draft creation is unchanged.
create or replace function public.zameel_complete_media_guard157()
returns trigger language plpgsql set search_path = '' as $$
declare doc jsonb := to_jsonb(new); required_type text; reference text; has_media boolean := false;
begin
  if doc->>'background156' <> 'true' or doc->>'upload_state156' <> 'ready' then return new; end if;
  if tg_table_name = 'posts' then
    required_type := doc->>'type';
    if required_type not in ('image','video') then return new; end if;
    reference := doc->>(case when required_type='video' then 'video_url' else 'image_url' end);
    has_media := exists(select 1 from jsonb_array_elements(case when jsonb_typeof(doc->'media_items')='array' then doc->'media_items' else '[]'::jsonb end) m
      where m->>'type'=required_type and nullif(btrim(m->>'url'),'') is not null and m->>'url' not like 'uploading://%');
  elsif tg_table_name='clips' then reference := doc->>'video_url';
  else reference := doc->>'media_url'; end if;
  if not has_media and (nullif(btrim(reference),'') is null or reference like 'uploading://%') then
    raise exception 'published_media_reference_missing' using errcode='23514';
  end if;
  return new;
end;
$$;
drop trigger if exists complete_media_guard157 on public.posts;
create trigger complete_media_guard157 before insert or update on public.posts for each row execute function public.zameel_complete_media_guard157();
drop trigger if exists complete_media_guard157 on public.clips;
create trigger complete_media_guard157 before insert or update on public.clips for each row execute function public.zameel_complete_media_guard157();
drop trigger if exists complete_media_guard157 on public.social_stories;
create trigger complete_media_guard157 before insert or update on public.social_stories for each row execute function public.zameel_complete_media_guard157();
commit;
