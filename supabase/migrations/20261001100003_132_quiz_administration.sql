-- Draft: install only with the completed 132 release, after quiz engine.
begin;
insert into public.admin_permissions(permission_key,name_ar,category) values
 ('quiz.generate','توليد مسودات كويز بالخدمة المهيأة','quiz'),('quiz.read','عرض بنك أسئلة كويز','quiz'),('quiz.write','إعداد أسئلة كويز','quiz'),('quiz.publish','مراجعة ونشر أسئلة كويز','quiz')
 on conflict(permission_key) do update set name_ar=excluded.name_ar,category=excluded.category;
insert into public.admin_role_permissions(role_id,permission_key)
 select r.id,p.permission_key from public.admin_roles r cross join public.admin_permissions p
 where r.role_key='super_admin' and p.permission_key like 'quiz.%' on conflict do nothing;
create or replace function public.zameel_quiz_admin_question(p_actor uuid,p_id uuid,p_data jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid; old_revision integer;
begin
 if not public.admin_has_permission('quiz.write',p_actor) or not public.admin_can_access_screen('quiz',p_actor) then raise exception 'quiz_write_not_authorized'; end if;
 if p_id is null then
  insert into public.zameel_quiz_questions(level,question_ar,question_en,options_ar,options_en,correct_index,source_url,created_by)
  values((p_data->>'level')::smallint,p_data->>'question_ar',p_data->>'question_en',p_data->'options_ar',p_data->'options_en',(p_data->>'correct_index')::smallint,p_data->>'source_url',p_actor) returning id into result;
 else
  select revision into old_revision from public.zameel_quiz_questions where id=p_id for update;
  if old_revision is null then raise exception 'quiz_question_not_found'; end if;
  update public.zameel_quiz_questions set level=(p_data->>'level')::smallint,question_ar=p_data->>'question_ar',question_en=p_data->>'question_en',options_ar=p_data->'options_ar',options_en=p_data->'options_en',correct_index=(p_data->>'correct_index')::smallint,source_url=p_data->>'source_url',status='draft',reviewed_by=null,reviewed_at=null,review_note='',revision=revision+1,updated_at=now() where id=p_id returning id into result;
 end if;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details) values(p_actor,'quiz.save_draft','quiz_question',result::text,jsonb_build_object('previous_revision',old_revision));
 return result;
end $$;
create or replace function public.zameel_quiz_admin_review(p_actor uuid,p_id uuid,p_revision integer,p_decision text,p_note text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare question public.zameel_quiz_questions; state text;
begin
 if not public.admin_has_permission('quiz.publish',p_actor) or not public.admin_can_access_screen('quiz',p_actor) then raise exception 'quiz_publish_not_authorized'; end if;
 if p_decision is null or p_decision not in ('publish','disable','draft') or char_length(trim(coalesce(p_note,'')))<10 then raise exception 'invalid_quiz_review'; end if;
 select * into question from public.zameel_quiz_questions where id=p_id for update;
 if question.id is null or p_revision is null or question.revision<>p_revision then raise exception 'quiz_revision_changed'; end if;
 if p_decision='publish' and (jsonb_array_length(question.options_ar)<>4 or jsonb_array_length(question.options_en)<>4 or question.source_url not like 'https://%') then raise exception 'quiz_question_incomplete'; end if;
 state=case p_decision when 'publish' then 'published' when 'disable' then 'disabled' else 'draft' end;
 update public.zameel_quiz_questions set status=state,reviewed_by=p_actor,reviewed_at=now(),review_note=p_note,updated_at=now() where id=p_id;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details) values(p_actor,'quiz.'||p_decision,'quiz_question',p_id::text,jsonb_build_object('revision',p_revision,'note',p_note));
 return jsonb_build_object('status',state);
end $$;
revoke all on function public.zameel_quiz_admin_question(uuid,uuid,jsonb),public.zameel_quiz_admin_review(uuid,uuid,integer,text,text) from public,anon,authenticated;
grant execute on function public.zameel_quiz_admin_question(uuid,uuid,jsonb),public.zameel_quiz_admin_review(uuid,uuid,integer,text,text) to service_role;
create or replace function public.zameel_quiz_admin_report(p_actor uuid,p_report uuid,p_decision text,p_note text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not public.admin_has_permission('quiz.publish',p_actor) or not public.admin_can_access_screen('quiz',p_actor) then raise exception 'quiz_review_not_authorized'; end if;
 if p_decision is null or p_decision not in ('resolved','dismissed') or char_length(trim(coalesce(p_note,'')))<10 then raise exception 'invalid_quiz_report_review'; end if;
 update public.zameel_quiz_reports set status=p_decision,reviewed_by=p_actor,reviewed_at=now(),review_reason=p_note where id=p_report;
 if not found then raise exception 'quiz_report_not_found'; end if;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details) values(p_actor,'quiz.report.'||p_decision,'quiz_report',p_report::text,jsonb_build_object('note',p_note));
end $$;
revoke all on function public.zameel_quiz_admin_report(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.zameel_quiz_admin_report(uuid,uuid,text,text) to service_role;

create or replace function public.zameel_quiz_admin_import(p_actor uuid,p_questions jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare item jsonb; ids jsonb:='[]'::jsonb; saved uuid;
begin
 if jsonb_typeof(p_questions)<>'array' or jsonb_array_length(p_questions)<1 or jsonb_array_length(p_questions)>100 then raise exception 'quiz_import_batch_limit'; end if;
 for item in select value from jsonb_array_elements(p_questions) loop
  saved=public.zameel_quiz_admin_question(p_actor,null,item);ids=ids||jsonb_build_array(saved);
 end loop;
 return ids;
end $$;
revoke all on function public.zameel_quiz_admin_import(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.zameel_quiz_admin_import(uuid,jsonb) to service_role;

create or replace function public.zameel_quiz_claim_generation(p_actor uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not public.admin_has_permission('quiz.generate',p_actor) or not public.admin_has_permission('quiz.write',p_actor) or not public.admin_can_access_screen('quiz',p_actor) then raise exception 'quiz_generation_not_authorized'; end if;
 perform pg_advisory_xact_lock(hashtextextended('quiz-generation:'||p_actor::text,0));
 if exists(select 1 from public.admin_audit_logs where actor_id=p_actor and action='quiz.generate_drafts' and created_at>now()-interval '1 minute') then raise exception 'quiz_generation_wait_one_minute'; end if;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,details) values(p_actor,'quiz.generate_drafts','quiz','draft_batch',jsonb_build_object('state','requested'));
end $$;
revoke all on function public.zameel_quiz_claim_generation(uuid) from public,anon,authenticated;
grant execute on function public.zameel_quiz_claim_generation(uuid) to service_role;
commit;
