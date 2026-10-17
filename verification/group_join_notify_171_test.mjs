import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';

// Real SQL from the repository is used for the groups tables, policies and RPCs
// (059 + 060), so this test proves the new migration on top of what production has.
const read = (p) => fs.readFileSync(new URL(p, import.meta.url), 'utf8');
const m059 = read('../supabase/migrations/059_activate_remaining_services.sql');
const m060 = read('../supabase/migrations/060_groups_polls_shortcuts_partners_meet_fix.sql');
const start = m059.indexOf('create table if not exists public.community_groups (');
const end = m059.indexOf('-- Polls');
assert.ok(start > 0 && end > start, 'groups section of 059 found');
const groups059 = m059.slice(start, end)
  .replace(/do \$\$ begin\s+alter publication[\s\S]*?end \$\$;/g, '');
const fnStart = m060.indexOf('create or replace function public.get_community_group_messages(');
const fnEnd = m060.indexOf('end $$;', fnStart) + 'end $$;'.length;
assert.ok(fnStart > 0 && fnEnd > fnStart, 'message RPC of 060 found');
const messages060 = m060.slice(fnStart, fnEnd);

const A = '10000000-0000-4000-8000-00000000000a'; // owner
const B = '10000000-0000-4000-8000-00000000000b'; // member
const C = '10000000-0000-4000-8000-00000000000c'; // colleague of B
const D = '10000000-0000-4000-8000-00000000000d'; // colleague of A
const E = '10000000-0000-4000-8000-00000000000e'; // not a colleague of anyone
const F = '10000000-0000-4000-8000-00000000000f'; // new user using a link
const X = '10000000-0000-4000-8000-000000000011'; // member of another group only
const Y = '10000000-0000-4000-8000-000000000012'; // blocked by B

const db = new PGlite();
await db.exec(`create role anon; create role authenticated; create role service_role; create schema auth;
create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
create table public.users(id uuid primary key, name text, profile_image text);
insert into public.users values
 ('${A}','Owner A',null),('${B}','Member B',null),('${C}','Colleague C',null),('${D}','Colleague D',null),
 ('${E}','Stranger E',null),('${F}','Newcomer F',null),('${X}','Other X',null),('${Y}','Blocked Y',null);
create table public.friend_requests(sender_id uuid, receiver_id uuid, status text);
insert into public.friend_requests values('${B}','${C}','accepted'),('${A}','${D}','accepted'),('${B}','${Y}','accepted'),('${A}','${B}','accepted');
create table public.user_blocks(blocker_id uuid, blocked_id uuid);
insert into public.user_blocks values('${B}','${Y}');
create function public.is_colleague(a uuid,b uuid) returns boolean language sql stable as $$
  select a=b or exists(select 1 from public.friend_requests r where r.status='accepted' and ((r.sender_id=a and r.receiver_id=b) or (r.sender_id=b and r.receiver_id=a)))$$;
create function public.is_blocked(a uuid,b uuid) returns boolean language sql stable as $$
  select exists(select 1 from public.user_blocks ub where (ub.blocker_id=a and ub.blocked_id=b) or (ub.blocker_id=b and ub.blocked_id=a))$$;
create table public.notifications(id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users(id) on delete cascade,
 actor_id uuid references public.users(id) on delete set null, type text not null, title_ar text not null default '', title_en text not null default '',
 body_ar text not null default '', body_en text not null default '', data jsonb not null default '{}'::jsonb, is_read boolean not null default false, created_at timestamptz not null default now());
create schema storage;
create table storage.buckets(id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(), bucket_id text, name text);
alter table storage.objects enable row level security;
grant usage on schema public, auth, storage to authenticated, anon;
`);
await db.exec(groups059);
await db.exec(messages060);
await db.exec(`alter table public.community_group_messages add column if not exists edited_at timestamptz;
grant select,insert,delete on all tables in schema public to authenticated;
grant select,insert,delete on storage.objects to authenticated;`);

let checks = 0;
const ok = (cond, msg) => { assert.ok(cond, msg); checks++; };
const eq = (a, b, msg) => { assert.deepEqual(a, b, msg); checks++; };
const admin = async (sql) => { await db.exec('reset role'); const r = await db.query(sql); return r; };
const as = async (uid, sql, params) => { await db.exec('reset role'); await db.exec('set role authenticated'); await db.exec(`set test.uid='${uid}'`); return db.query(sql, params); };
const fails = async (uid, sql, params, re) => {
  try { await as(uid, sql, params); } catch (e) { return re.test(String(e.message)); }
  return false;
};


const pub = (await as(A, `insert into public.community_groups(owner_id,name,description,is_private) values('${A}','المجموعة العامة','وصف',false) returning id`)).rows[0].id;
const prv = (await as(A, `insert into public.community_groups(owner_id,name,description,is_private) values('${A}','المجموعة السرية','سري',true) returning id`)).rows[0].id;
const read2 = (p) => fs.readFileSync(new URL(p, import.meta.url), 'utf8');
const m166 = read2('../supabase/migrations/20261017130001_166_group_invites_moderation_media.sql');
const m171 = read2('../supabase/migrations/20261017160001_171_group_join_request_notify.sql');
await db.exec('reset role');
await db.exec(m166);
await db.exec(m171);
await db.exec(m171);
ok(true, 'migration 171 applies twice without error');
const notes = async (uid, type) => (await admin(`select * from public.notifications where user_id='${uid}' and type='${type}' order by created_at`)).rows;

// ---- private group: join request tells the owner -------------------------------
eq((await as(B, `select public.join_community_group('${prv}') as r`)).rows[0].r, 'requested', 'B asks to join the private group');
let n = await notes(A, 'group_join_request');
eq(n.length, 1, 'owner gets exactly one join-request notification');
ok(n[0].actor_id === B && n[0].title_ar === 'طلب انضمام جديد' && n[0].body_ar === '«Member B» يطلب الانضمام إلى مجموعة «المجموعة السرية»', 'Arabic text names the requester and the group');
ok(n[0].data.type === 'group_join_request' && n[0].data.group_id === prv && !!n[0].data.request_id, 'payload routes to the requests list');
await as(B, `select public.join_community_group('${prv}')`);
eq((await notes(A, 'group_join_request')).length, 1, 'asking again within an hour does not duplicate');

// ---- owner answers: requester is told ------------------------------------------
const req = (await admin(`select id from public.community_group_join_requests where group_id='${prv}' and user_id='${B}'`)).rows[0].id;
await as(A, `select public.respond_community_group_join_request('${req}', true)`);
n = await notes(B, 'group_join_accepted');
eq(n.length, 1, 'requester told the request was accepted');
ok(n[0].body_ar === 'تم قبول طلب انضمامك إلى مجموعة «المجموعة السرية»' && n[0].data.group_id === prv, 'accepted text and payload');
eq((await notes(A, 'group_member_joined')).length, 0, 'owner is not told about a member who joined a PRIVATE group he just accepted');

await as(C, `select public.join_community_group('${prv}')`);
const req2 = (await admin(`select id from public.community_group_join_requests where group_id='${prv}' and user_id='${C}'`)).rows[0].id;
await as(A, `select public.respond_community_group_join_request('${req2}', false)`);
eq((await notes(C, 'group_join_rejected')).length, 1, 'requester told the request was declined');

// ---- blocked users never notify each other -------------------------------------
await admin(`insert into public.user_blocks values('${A}','${E}')`);
await as(E, `select public.join_community_group('${prv}')`);
eq((await notes(A, 'group_join_request')).filter((x) => x.actor_id === E).length, 0, 'a user blocked by the owner does not notify him');

// ---- public group: joining tells the owner -------------------------------------
eq((await as(D, `select public.join_community_group('${pub}') as r`)).rows[0].r, 'joined', 'D joins the public group');
n = await notes(A, 'group_member_joined');
eq(n.length, 1, 'owner told about the new member of the public group');
ok(n[0].body_ar === '«Colleague D» انضم إلى مجموعة «المجموعة العامة»' && n[0].data.group_id === pub, 'public join text and payload');
eq((await notes(A, 'group_member_joined')).filter((x) => x.actor_id === A).length, 0, 'owner creating the group is not notified about himself');

// ---- the app routes the new types ----------------------------------------------
const notifSrc = read2('../lib/screens/notifications/notifications_screen.dart');
const mainSrc = read2('../lib/main.dart');
const privSrc = read2('../lib/screens/private_groups_screen.dart');
for (const t of ['group_join_request', 'group_member_joined', 'group_join_accepted']) {
  ok(notifSrc.includes(`'${t}'`) && mainSrc.includes(`'${t}'`), `${t} is routed by the notifications screen and by push taps`);
}
ok(/openRequestsForGroupId/.test(privSrc) && /_showJoinRequests\(match\.first\)/.test(privSrc), 'private groups screen opens the requests list from a notification');
const lamma = read2('../lib/screens/social/lamma_chat_screen.dart');
ok(/\.order\('created_at', ascending: true\)/.test(lamma), 'Lamma chat stream is ordered oldest first (newest at the bottom)');

console.log(`PASS: group join notify 171 (${checks} checks): owner told on request, requester told on answer, public joins reported, blocks and duplicates respected, Lamma chat order.`);
