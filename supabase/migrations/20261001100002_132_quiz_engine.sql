-- Draft: do not install until release validation is complete.
begin;
create table if not exists public.zameel_quiz_questions (
 id uuid primary key default gen_random_uuid(), level smallint not null check(level between 1 and 6),
 question_ar text not null check(char_length(question_ar) between 5 and 1000),
 question_en text not null check(char_length(question_en) between 5 and 1000),
 options_ar jsonb not null check(jsonb_typeof(options_ar)='array' and jsonb_array_length(options_ar)=4),
 options_en jsonb not null check(jsonb_typeof(options_en)='array' and jsonb_array_length(options_en)=4),
 correct_index smallint not null check(correct_index between 0 and 3),
 source_url text not null check(source_url like 'https://%'), review_note text not null default '',
 status text not null default 'draft' check(status in ('draft','published','disabled')),
 revision integer not null default 1, created_by uuid references public.users(id) on delete set null,
 reviewed_by uuid references public.users(id) on delete set null, reviewed_at timestamptz,
 updated_at timestamptz not null default now(),
 check(status<>'published' or (reviewed_by is not null and reviewed_at is not null and char_length(trim(review_note))>=10))
);
create unique index if not exists quiz_question_ar_unique on public.zameel_quiz_questions(md5(lower(btrim(question_ar))));
create unique index if not exists quiz_question_en_unique on public.zameel_quiz_questions(md5(lower(btrim(question_en))));
create index if not exists quiz_questions_available_idx on public.zameel_quiz_questions(level) where status='published';
create table if not exists public.zameel_quiz_players (
 user_id uuid primary key references public.users(id) on delete cascade,
 score integer not null default 0 check(score>=0), answered integer not null default 0 check(answered>=0),
 score_changed_at timestamptz not null default now()
);
create table if not exists public.zameel_quiz_attempts (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users(id) on delete cascade,
 question_id uuid not null references public.zameel_quiz_questions(id), revision integer not null,
 ordinal integer not null, selected_index smallint check(selected_index between 0 and 3),
 correct_index smallint not null, answered_at timestamptz, awarded boolean not null default false,
 cancelled boolean not null default false, created_at timestamptz not null default now()
);
create unique index if not exists quiz_one_pending_idx on public.zameel_quiz_attempts(user_id) where answered_at is null and not cancelled;
create unique index if not exists quiz_one_award_idx on public.zameel_quiz_attempts(user_id,question_id) where awarded;
create index if not exists quiz_attempts_user_question_idx on public.zameel_quiz_attempts(user_id,question_id);
create index if not exists quiz_rank_idx on public.zameel_quiz_players(score desc,score_changed_at,user_id);
create table if not exists public.zameel_quiz_reports (
 id uuid primary key default gen_random_uuid(), question_id uuid not null references public.zameel_quiz_questions(id),
 reporter_id uuid not null references public.users(id) on delete cascade,
 reason text not null check(char_length(trim(reason)) between 5 and 1000),
 status text not null default 'open' check(status in ('open','resolved','dismissed')),
 created_at timestamptz not null default now(), reviewed_by uuid references public.users(id) on delete set null,
 reviewed_at timestamptz, review_reason text, unique(question_id,reporter_id)
);
-- There is intentionally no client table access: answer keys remain server-side.
alter table public.zameel_quiz_questions enable row level security;
alter table public.zameel_quiz_players enable row level security;
alter table public.zameel_quiz_attempts enable row level security;
alter table public.zameel_quiz_reports enable row level security;
revoke all on public.zameel_quiz_questions,public.zameel_quiz_players,public.zameel_quiz_attempts,public.zameel_quiz_reports from public,anon,authenticated;
grant all on public.zameel_quiz_questions,public.zameel_quiz_players,public.zameel_quiz_attempts,public.zameel_quiz_reports to service_role;
create or replace function public.zameel_quiz_level(p_score integer) returns integer language sql immutable set search_path='' as $$
 select case when p_score>=351 then 6 when p_score>=141 then 5 when p_score>=81 then 4 when p_score>=31 then 3 when p_score>=16 then 2 else 1 end
$$;
create or replace function public.zameel_quiz_require_access() returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
 if actor is null or not coalesce(public.zameel_account_can_write(),false) then raise exception 'quiz_account_unavailable'; end if;
 if not exists(select 1 from public.feature_flags where feature_key='quiz' and scope_type='global' and scope_value='*' and is_enabled and display_mode='enabled' and rollout_percent=100) then raise exception 'quiz_temporarily_unavailable'; end if;
 return actor;
end $$;
create or replace function public.zameel_quiz_next() returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.zameel_quiz_require_access(); player public.zameel_quiz_players; attempt public.zameel_quiz_attempts; question public.zameel_quiz_questions; chosen uuid;
begin
 insert into public.zameel_quiz_players(user_id) values(actor) on conflict do nothing;
 select * into player from public.zameel_quiz_players where user_id=actor for update;
 select * into attempt from public.zameel_quiz_attempts where user_id=actor and answered_at is null and not cancelled;
 if attempt.id is not null then
  select * into question from public.zameel_quiz_questions where id=attempt.question_id and status='published' and revision=attempt.revision;
  if question.id is null then update public.zameel_quiz_attempts set cancelled=true where id=attempt.id; attempt.id=null; end if;
 end if;
 if attempt.id is null then
  select q.id into chosen from public.zameel_quiz_questions q where status='published' and level=public.zameel_quiz_level(player.score)
   and not exists(select 1 from public.zameel_quiz_attempts a where a.user_id=actor and a.question_id=q.id and a.answered_at is not null)
   order by random() limit 1;
  if chosen is null then
   select q.id into chosen from public.zameel_quiz_questions q where status='published' and level=public.zameel_quiz_level(player.score)
    and not exists(select 1 from public.zameel_quiz_attempts a where a.user_id=actor and a.question_id=q.id and a.awarded)
    order by (select max(a.answered_at) from public.zameel_quiz_attempts a where a.user_id=actor and a.question_id=q.id) nulls first,random() limit 1;
  end if;
  if chosen is null then return jsonb_build_object('available',false,'score',player.score,'level',public.zameel_quiz_level(player.score),'ordinal',player.answered+1); end if;
  select * into question from public.zameel_quiz_questions where id=chosen;
  insert into public.zameel_quiz_attempts(user_id,question_id,revision,ordinal,correct_index) values(actor,question.id,question.revision,player.answered+1,question.correct_index) returning * into attempt;
 end if;
 return jsonb_build_object('available',true,'attempt_id',attempt.id,'question_id',question.id,'ordinal',attempt.ordinal,
 'score',player.score,'level',public.zameel_quiz_level(player.score),'question_ar',question.question_ar,'question_en',question.question_en,'options_ar',question.options_ar,'options_en',question.options_en);
end $$;
create or replace function public.zameel_quiz_answer(p_attempt_id uuid,p_selected integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.zameel_quiz_require_access(); player public.zameel_quiz_players; attempt public.zameel_quiz_attempts; valid_question boolean; won boolean;
begin
 if p_selected is null or p_selected not between 0 and 3 then raise exception 'invalid_quiz_answer'; end if;
 select * into player from public.zameel_quiz_players where user_id=actor for update;
 select * into attempt from public.zameel_quiz_attempts where id=p_attempt_id and user_id=actor for update;
 if attempt.id is null or attempt.cancelled then raise exception 'quiz_attempt_unavailable'; end if;
 if attempt.answered_at is null then
  select exists(select 1 from public.zameel_quiz_questions where id=attempt.question_id and status='published' and revision=attempt.revision) into valid_question;
  if not valid_question then raise exception 'quiz_question_changed'; end if;
  won=p_selected=attempt.correct_index and not exists(select 1 from public.zameel_quiz_attempts where user_id=actor and question_id=attempt.question_id and awarded);
  update public.zameel_quiz_attempts set selected_index=p_selected,answered_at=now(),awarded=won where id=attempt.id returning * into attempt;
  update public.zameel_quiz_players set score=score+case when won then 1 else 0 end,answered=answered+1,
   score_changed_at=case when won then now() else score_changed_at end where user_id=actor returning * into player;
 end if;
 -- Retries return the original recorded answer, never award again.
 return jsonb_build_object('attempt_id',attempt.id,'selected_index',attempt.selected_index,'correct_index',attempt.correct_index,'correct',attempt.selected_index=attempt.correct_index,'awarded',attempt.awarded,'score',player.score,'level',public.zameel_quiz_level(player.score));
end $$;
create or replace function public.zameel_quiz_leaderboard() returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.zameel_quiz_require_access(); result jsonb; own_rank bigint;
begin
 with ranked as (select p.user_id,u.name,u.profile_image,p.score,public.zameel_quiz_level(p.score) as level,row_number() over(order by p.score desc,p.score_changed_at,p.user_id) as rank from public.zameel_quiz_players p join public.users u on u.id=p.user_id where p.score>0 and not exists(select 1 from public.admin_user_states state where state.user_id=p.user_id and state.status in ('blocked','suspended') and (state.suspended_until is null or state.suspended_until>now())))
 select coalesce(jsonb_agg(to_jsonb(r) order by r.rank),'[]'::jsonb) into result from ranked r where rank<=10;
 select count(*)+1 into own_rank from public.zameel_quiz_players p,public.zameel_quiz_players me where me.user_id=actor and not exists(select 1 from public.admin_user_states state where state.user_id=p.user_id and state.status in ('blocked','suspended') and (state.suspended_until is null or state.suspended_until>now())) and (p.score>me.score or (p.score=me.score and (p.score_changed_at,p.user_id)<(me.score_changed_at,me.user_id)));
 return jsonb_build_object('rows',result,'own_rank',case when exists(select 1 from public.zameel_quiz_players where user_id=actor and score>0) then own_rank else null end);
end $$;
create or replace function public.zameel_quiz_report(p_question_id uuid,p_reason text) returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.zameel_quiz_require_access();
begin
 if not exists(select 1 from public.zameel_quiz_attempts where user_id=actor and question_id=p_question_id) then raise exception 'quiz_question_unavailable'; end if;
 insert into public.zameel_quiz_reports(question_id,reporter_id,reason) values(p_question_id,actor,p_reason) on conflict(question_id,reporter_id) do nothing;
end $$;
revoke all on function public.zameel_quiz_level(integer),public.zameel_quiz_require_access(),public.zameel_quiz_next(),public.zameel_quiz_answer(uuid,integer),public.zameel_quiz_leaderboard(),public.zameel_quiz_report(uuid,text) from public,anon,authenticated;
grant execute on function public.zameel_quiz_next(),public.zameel_quiz_answer(uuid,integer),public.zameel_quiz_leaderboard(),public.zameel_quiz_report(uuid,text) to authenticated;
insert into public.feature_flags(feature_key,name_ar,description,is_enabled,display_mode,rollout_percent,scope_type,scope_value)
 values('quiz','كويز','مسابقة معلومات عامة بأسئلة مراجعة',false,'hidden',0,'global','*') on conflict(feature_key) do nothing;
commit;
