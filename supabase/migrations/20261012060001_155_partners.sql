begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('partner-branding','partner-branding',true,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create or replace function public.zameel_partner_quota_155() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare month_start timestamptz;month_end timestamptz;used integer;
begin
 if new.deleted_at is not null or new.status='deleted' then return new;end if;
 if tg_op='UPDATE' and old.deleted_at is null and old.status<>'deleted' and old.partner_id=new.partner_id and old.created_at=new.created_at then return new;end if;
 perform 1 from business_partners where id=new.partner_id for update;
 month_start:=date_trunc('month',new.created_at at time zone 'Asia/Amman') at time zone 'Asia/Amman';
 month_end:=(date_trunc('month',new.created_at at time zone 'Asia/Amman')+interval '1 month') at time zone 'Asia/Amman';
 select count(*) into used from advertisements where partner_id=new.partner_id and deleted_at is null and status<>'deleted' and created_at>=month_start and created_at<month_end and id<>new.id;
 if used>=5 then raise exception 'partner_monthly_limit_5';end if;
 return new;
end $$;
drop trigger if exists zameel_partner_quota_155 on public.advertisements;
create trigger zameel_partner_quota_155 before insert or update of partner_id,created_at,deleted_at,status on public.advertisements for each row execute function public.zameel_partner_quota_155();
create or replace function public.zameel_validate_partner_media_155(p_actor uuid,p_media jsonb) returns void language plpgsql security definer set search_path=public,storage,pg_temp as $$
declare item jsonb;path text;
begin
 if jsonb_typeof(p_media)<>'array' or jsonb_array_length(p_media)>10 then raise exception 'invalid_media';end if;
 for item in select value from jsonb_array_elements(p_media) loop
 path:=item->>'path';
 if item->>'type' not in ('image','video') or path is null or path not like p_actor::text||'/partners155/%' or path like '%..%' or not exists(select 1 from storage.objects where bucket_id='advertisements' and name=path) then raise exception 'invalid_media';end if;
 end loop;
end $$;
create or replace function public.zameel_admin_partner_155(p_actor uuid,p_partner uuid,p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb;media_items jsonb:=coalesce(p_input->'media','[]');previous_end timestamptz;
begin
 if not zameel_admin_owner_154(p_actor) then raise exception 'owner_only';end if;
 if length(trim(coalesce(p_input->>'contact_phone','')))<5 then raise exception 'phone_required';end if;
 perform zameel_validate_partner_media_155(p_actor,media_items);
 select ends_at into previous_end from advertiser_terms where partner_id=p_partner;
 result:=zameel_admin_partner_154(p_actor,p_partner,p_input);
 if result->>'advertisement_id' is not null then
 update advertisements set media=media_items where id=(result->>'advertisement_id')::uuid;
 update advertisements set target_account_types=coalesce(array(select jsonb_array_elements_text(p_input->'account_types')),'{}'),target_universities=coalesce(array(select jsonb_array_elements_text(p_input->'universities')),'{}') where id=(result->>'advertisement_id')::uuid;
 end if;
 update advertiser_terms set ends_at=greatest(ends_at,previous_end) where partner_id=(result->>'partner_id')::uuid;
 return result;
end $$;
create or replace function public.zameel_admin_partner_delete_155(p_actor uuid,p_partner uuid,p_ad uuid default null) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not zameel_admin_owner_154(p_actor) then raise exception 'owner_only';end if;
 perform 1 from business_partners where id=p_partner for update;if not found then raise exception 'partner_not_found';end if;
 if p_ad is null then
 update business_partners set is_active=false,updated_at=now() where id=p_partner;
 update advertisements set status='deleted',deleted_at=now(),deleted_by=p_actor,deletion_reason='حذف الشريك' where partner_id=p_partner and deleted_at is null;
 else
 update advertisements set status='deleted',deleted_at=now(),deleted_by=p_actor,deletion_reason='حذف منشور الشريك' where id=p_ad and partner_id=p_partner and deleted_at is null;
 if not found then raise exception 'advertisement_not_found';end if;
 end if;
 insert into zameel_admin_access_log_154(actor_id,action,data_key,target_id,details) values(p_actor,'partner_delete','partners',p_partner::text,jsonb_build_object('advertisement_id',p_ad));
 return jsonb_build_object('saved',true);
end $$;
revoke all on function public.zameel_partner_quota_155(),public.zameel_validate_partner_media_155(uuid,jsonb),public.zameel_admin_partner_155(uuid,uuid,jsonb),public.zameel_admin_partner_delete_155(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.zameel_admin_partner_155(uuid,uuid,jsonb),public.zameel_admin_partner_delete_155(uuid,uuid,uuid) to service_role;
create or replace function public.zameel_admin_advertisement_155(p_actor uuid,p_ad uuid,p_input jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare previous jsonb;items jsonb:=coalesce(p_input->'media','[]');item jsonb;result jsonb;
begin
 if not zameel_admin_owner_154(p_actor) then raise exception 'owner_only';end if;
 select media into previous from advertisements where id=p_ad and owner_sponsored for update;if not found then raise exception 'owner_advertisement_not_found';end if;
 if jsonb_typeof(items)<>'array' or jsonb_array_length(items)>10 then raise exception 'invalid_media';end if;
 for item in select value from jsonb_array_elements(items) loop
 if coalesce(previous,'[]')@>jsonb_build_array(item) then continue;end if;
 perform zameel_validate_partner_media_155(p_actor,jsonb_build_array(item));
 end loop;
 result:=zameel_admin_advertisement_154(p_actor,p_ad,p_input);
 update advertisements set media=items where id=p_ad;return result;
end $$;
revoke all on function public.zameel_admin_advertisement_155(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.zameel_admin_advertisement_155(uuid,uuid,jsonb) to service_role;
notify pgrst,'reload schema';commit;
