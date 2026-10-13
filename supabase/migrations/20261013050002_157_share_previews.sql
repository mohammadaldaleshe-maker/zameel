begin;
set local lock_timeout = '3s';
alter table public.posts add column if not exists share_cover157 text;
comment on column public.posts.share_cover157 is 'Generated preview from this post media; private references remain private.';
create or replace function public.zameel_invalidate_share_cover157()
returns trigger language plpgsql set search_path = '' as $$
begin
  if (new.media_items is distinct from old.media_items or
      new.video_url is distinct from old.video_url or
      new.image_url is distinct from old.image_url or
      new.audience is distinct from old.audience)
      and new.share_cover157 is not distinct from old.share_cover157 then
    new.share_cover157 := null;
  end if;
  return new;
end;
$$;
drop trigger if exists invalidate_share_cover157 on public.posts;
create trigger invalidate_share_cover157 before update on public.posts
for each row execute function public.zameel_invalidate_share_cover157();
notify pgrst, 'reload schema';
commit;
