-- Zameel 068: non-destructive storage guard and owner-only usage report.
-- Run after migration 067. This migration does not delete user content.
begin;

update storage.buckets
set file_size_limit = 83886080
where id = 'posts';

create or replace function public.zameel_storage_usage_report()
returns table (
  bucket_id text,
  object_count bigint,
  total_bytes bigint,
  total_megabytes numeric
)
language plpgsql
security definer
set search_path = public, storage
set row_security = off
as $$
begin
  if auth.uid() is null or not exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and lower(coalesce(u.role, '')) in ('owner', 'admin')
  ) then
    raise exception 'not_authorized';
  end if;

  return query
  select
    o.bucket_id,
    count(*)::bigint,
    coalesce(sum(coalesce((o.metadata ->> 'size')::bigint, 0)), 0)::bigint,
    round(
      coalesce(sum(coalesce((o.metadata ->> 'size')::numeric, 0)), 0)
        / 1048576.0,
      2
    )
  from storage.objects o
  group by o.bucket_id
  order by 3 desc;
end;
$$;

revoke all on function public.zameel_storage_usage_report() from public, anon;
grant execute on function public.zameel_storage_usage_report() to authenticated;

commit;
