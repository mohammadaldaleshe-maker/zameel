begin;
insert into public.app_releases(platform,version_name,build_number,is_allowed,download_url)
values('android','2.0.8',17,true,'')
on conflict(platform,version_name) do update set build_number=excluded.build_number;
commit;
