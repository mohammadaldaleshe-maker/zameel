begin;
alter table public.advertisements add column target_account_types text[] not null default '{}',add column target_universities text[] not null default '{}';
alter table public.advertisements add constraint advertisement_account_types_154 check(target_account_types<@array['student','graduate','general']::text[]),add constraint advertisement_universities_154 check(cardinality(target_universities)<=100);
create policy zameel_partner_audience_154 on public.advertisements as restrictive for select to authenticated using(
 not owner_sponsored or public.advertisement_can_manage(advertisements) or exists(select 1 from public.users u where u.id=auth.uid() and (cardinality(target_account_types)=0 or u.account_type=any(target_account_types)) and (cardinality(target_universities)=0 or u.university=any(target_universities))));
create or replace function public.zameel_admin_advertisement_154(p_actor uuid,p_ad uuid,p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare types text[];universities text[];days integer:=(p_input->>'days')::integer;active boolean:=(p_input->>'active')::boolean;reason text:=trim(p_input->>'reason');target advertisements%rowtype;
begin
 if not public.zameel_admin_owner_154(p_actor) then raise exception 'owner_only';end if;
 if length(coalesce(reason,''))<5 or days is null or days not between 1 and 3650 or active is null or length(trim(coalesce(p_input->>'title',''))) not between 1 and 180 then raise exception 'invalid_advertisement';end if;
 select * into target from advertisements where id=p_ad and owner_sponsored for update;if not found then raise exception 'owner_advertisement_not_found';end if;
 if target.deleted_at is not null or target.is_hidden then raise exception 'restore_content_before_editing';end if;
 select coalesce(array_agg(distinct v),'{}') into types from jsonb_array_elements_text(coalesce(p_input->'account_types','[]'::jsonb)) v;
 select coalesce(array_agg(distinct trim(v)) filter(where trim(v)<>''),'{}') into universities from jsonb_array_elements_text(coalesce(p_input->'universities','[]'::jsonb)) v;
 if not types<@array['student','graduate','general']::text[] or cardinality(universities)>100 or exists(select 1 from unnest(universities) v where length(v)>160) then raise exception 'invalid_audience';end if;
 update advertisements set title=trim(p_input->>'title'),body=left(coalesce(p_input->>'body',''),10000),status=case when active then 'published' else 'draft' end,published_at=case when active then now() else published_at end,expires_at=now()+make_interval(days=>days),target_account_types=types,target_universities=universities,updated_at=now() where id=p_ad;
 if active then update advertiser_terms set ends_at=greatest(ends_at,now()+make_interval(days=>days)) where partner_id=target.partner_id;end if;
 insert into zameel_admin_access_log_154(actor_id,action,data_key,target_id,details) values(p_actor,'partner_advertisement','partners',p_ad::text,jsonb_build_object('reason',reason,'active',active,'days',days,'account_types',types,'universities',universities));
 return jsonb_build_object('saved',true);
end $$;
create or replace function public.zameel_sync_partner_location_154() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 update advertisements set latitude=new.latitude,longitude=new.longitude,category=new.category,updated_at=now() where partner_id=new.id and owner_sponsored;
 return new;
end $$;
create trigger zameel_sync_partner_location_154 after update of latitude,longitude,category on public.business_partners for each row execute function public.zameel_sync_partner_location_154();
revoke all on function public.zameel_admin_advertisement_154(uuid,uuid,jsonb),public.zameel_sync_partner_location_154() from public,anon,authenticated;
grant execute on function public.zameel_admin_advertisement_154(uuid,uuid,jsonb) to service_role;
notify pgrst,'reload schema';
commit;
