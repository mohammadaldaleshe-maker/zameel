begin;
-- Public badge facts for identities already visible in the UI; name matching is never used.
create or replace function public.zameel_verification_badges(p_users uuid[])
returns table(user_id uuid,expires_at timestamptz)
language sql stable security invoker set search_path='' as $$
 select u.id,u.verification_expires_at from public.users u
 where auth.uid() is not null and u.id=any(p_users[1:100])
 and u.verification_expires_at>now()
;
$$;
revoke all on function public.zameel_verification_badges(uuid[]) from public,anon;
grant execute on function public.zameel_verification_badges(uuid[]) to authenticated;
update public.admin_permissions set category='promotions' where permission_key in ('verification.read','verification.manage');
create or replace function public.zameel_review_verification(p_actor uuid,p_id uuid,p_decision text,p_code text,p_amount_fils integer,p_note text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.zameel_verification_requests; expiry timestamptz; term_start timestamptz; target uuid;
begin
 if not coalesce(public.admin_has_permission('verification.manage',p_actor),false) or not coalesce(public.admin_can_access_screen('promotions',p_actor),false) then raise exception 'verification_review_not_authorized';end if;
 if p_decision is null or p_decision not in ('approve','reject') or length(trim(coalesce(p_note,'')))<5 then raise exception 'invalid_verification_review';end if;
 select user_id into target from public.zameel_verification_requests where id=p_id;
 perform 1 from public.users where id=target for update;
 select * into r from public.zameel_verification_requests where id=p_id for update;
 if r.id is null then raise exception 'verification_not_found';end if;
 if p_decision='approve' and (upper(trim(coalesce(p_code,'')))<>r.payment_code or p_amount_fils is distinct from 1000) then raise exception 'payment_code_or_amount_mismatch';end if;
 if r.status=(case p_decision when 'approve' then 'approved' else 'rejected' end) then return jsonb_build_object('status',r.status,'ends_at',r.ends_at);end if;
 if r.status<>'pending' then raise exception 'verification_already_decided';end if;
 if p_decision='approve' then
 if exists(select 1 from public.admin_user_states where user_id=r.user_id and status in ('blocked','suspended')) then raise exception 'verification_account_unavailable';end if;
 select greatest(now(),coalesce(verification_expires_at,now())) into term_start from public.users where id=r.user_id;
 expiry:=term_start+interval '1 month';
 update public.users set verification_expires_at=expiry where id=r.user_id;
 end if;
 update public.zameel_verification_requests set status=case p_decision when 'approve' then 'approved' else 'rejected' end,reviewed_at=now(),reviewed_by=p_actor,review_note=trim(p_note),starts_at=case when p_decision='approve' then term_start end,ends_at=expiry where id=p_id;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details) values(p_actor,'verification.'||p_decision,'verification',p_id::text,jsonb_build_object('note',p_note,'ends_at',expiry));
 insert into public.notifications(user_id,actor_id,type,title_ar,title_en,body_ar,body_en,data,is_read) values(r.user_id,p_actor,'account_verification_review','تحديث طلب توثيق الحساب','Verification request update',case when p_decision='approve' then 'تم توثيق حسابك لمدة شهر' else 'تمت مراجعة طلبك ورفضه. تواصل مع الدعم للاستفسار عن الدفع.' end,case when p_decision='approve' then 'Your account verification was approved for one month' else 'Your request was rejected. Contact support about your payment.' end,jsonb_build_object('verification_request_id',r.id,'user_id',r.user_id,'ends_at',expiry),false);
 return jsonb_build_object('status',case p_decision when 'approve' then 'approved' else 'rejected' end,'ends_at',expiry);
end $$;
create or replace function public.zameel_trust_view(p_match uuid,p_user uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.zameel_trust_matches; r public.zameel_trust_rounds; result jsonb; messages jsonb; last_round jsonb; is_one boolean;
begin
 select * into m from public.zameel_trust_matches where id=p_match;
 if m.id is null or (p_user is distinct from m.player1 and p_user is distinct from m.player2) then raise exception 'match_access_denied';end if;
 is_one:=p_user=m.player1;
 select jsonb_agg(jsonb_build_object('round_no',round_no,'won',won,'correct_index',correct_index,'options_ar',options_ar,'options_en',options_en)
 order by round_no desc) into last_round from public.zameel_trust_rounds where match_id=m.id and resolved_at is not null;
 result:=jsonb_build_object('match_id',m.id,'phase',m.phase,'round_no',m.round_no,'prize',m.prize,
 'stake',m.stake,'reward_unit',m.reward_unit,'server_now',now(),'deadline',m.deadline,
 'balance',(select balance from public.zameel_coin_wallets where user_id=p_user),
 'own_choice',case when is_one then m.choice1 else m.choice2 end,
 'opponent_decided',case when is_one then m.choice2 is not null else m.choice1 is not null end,
 'last_round',last_round->0,'reason',m.reason);
 if m.phase='questions' then
  select * into r from public.zameel_trust_rounds where match_id=m.id and round_no=m.round_no;
  result:=result||jsonb_build_object('question',jsonb_build_object('question_ar',r.question_ar,'question_en',r.question_en,
   'options_ar',r.options_ar,'options_en',r.options_en,'own_selected',case when is_one then r.selected1 else r.selected2 end,
   'opponent_selected',case when is_one then r.selected2 else r.selected1 end));
 end if;
 if m.phase in ('questions','decision') then
  select coalesce(jsonb_agg(x order by x.id),'[]'::jsonb) into messages from
   (select id,body,(sender_id=p_user) as own,created_at from public.zameel_trust_messages where match_id=m.id order by id desc limit 100) x;
  result:=result||jsonb_build_object('messages',messages);
 else
  result:=result||jsonb_build_object('own_payout',case when is_one then m.payout1 else m.payout2 end,
   'opponent_choice',case when is_one then m.choice2 else m.choice1 end,
   'opponent', (select jsonb_build_object('id',u.id,'name',u.name,'profile_image',u.profile_image) from public.users u
    where u.id=case when is_one then m.player2 else m.player1 end));
 end if;
 return result;
end $$;
create or replace function public.zameel_radio_author_badges(p_posts uuid[])
returns table(post_id uuid,user_id uuid)
language sql stable security definer set search_path='' as $$
 select p.id,p.user_id from public.zameel_radio_posts p
 join public.zameel_radio_feed() f on f.id=p.id
 where auth.uid() is not null and not p.is_anonymous and p.id=any(p_posts[1:100]);
$$;
revoke all on function public.zameel_radio_author_badges(uuid[]) from public,anon;
grant execute on function public.zameel_radio_author_badges(uuid[]) to authenticated;
commit;
