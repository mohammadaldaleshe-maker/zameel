begin;
create or replace function public.zameel_admin_revenue_154(p_actor uuid,p_kind text,p_offset integer default 0,p_query text default '',p_from timestamptz default null,p_to timestamptz default null,p_status text default '')
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
 if not public.zameel_admin_can_read_154(p_actor,'revenue') then raise exception 'read_delegation_required';end if;
 if p_kind not in ('promotion','verification') or p_offset<0 or p_offset>10000000 or length(p_query)>300 then raise exception 'invalid_revenue_filter';end if;
 with filtered as (
 select i.id,i.request_id,i.user_id,u.name,u.email,l.order_id,l.is_test,l.purchased_at,l.settlement_state,f.currency,f.gross,f.tax,f.developer_revenue,f.checked_at
 from zameel_play_payment_intents i join zameel_play_purchase_ledger l on l.intent_id=i.id left join users u on u.id=i.user_id left join zameel_play_finance f on f.intent_id=i.id
 where i.kind=p_kind and (p_from is null or l.purchased_at>=p_from) and (p_to is null or l.purchased_at<=p_to) and (p_status='' or l.settlement_state=p_status)
 and (p_query='' or concat_ws(' ',u.name,u.email,i.user_id::text,l.order_id) ilike '%'||replace(replace(replace(p_query,'\','\\'),'%','\%'),'_','\_')||'%')
 ), page as(select * from filtered order by purchased_at desc,id offset p_offset limit 100), totals as(
 select currency,sum(gross) gross,sum(tax) tax,sum(developer_revenue) developer_revenue,count(*) orders from filtered where not is_test and settlement_state='approved' and currency is not null group by currency)
 select jsonb_build_object('rows',coalesce((select jsonb_agg(to_jsonb(page)) from page),'[]'::jsonb),'total',(select count(*) from filtered),'totals',coalesce((select jsonb_agg(to_jsonb(totals)) from totals),'[]'::jsonb),
 'pending_finance',(select count(*) from filtered where not is_test and settlement_state='approved' and currency is null),'free_verifications',case when p_kind='verification' then (select count(*) from zameel_free_verification_154 where (p_from is null or created_at>=p_from) and (p_to is null or created_at<=p_to)) else 0 end) into result;
 insert into zameel_admin_access_log_154(actor_id,action,data_key,details) values(p_actor,'read','revenue',jsonb_build_object('kind',p_kind,'offset',p_offset));
 return result;
end $$;
revoke all on function public.zameel_admin_revenue_154(uuid,text,integer,text,timestamptz,timestamptz,text) from public,anon,authenticated;
grant execute on function public.zameel_admin_revenue_154(uuid,text,integer,text,timestamptz,timestamptz,text) to service_role;
notify pgrst,'reload schema';
commit;
