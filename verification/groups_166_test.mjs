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

// groups: G1 public (owner A, member B), G2 public of someone else (member X), P private (owner A)
const g1 = (await as(A, `insert into public.community_groups(owner_id,name,description,is_private) values('${A}','المجموعة الأولى','وصف 1',false) returning id`)).rows[0].id;
const g2 = (await as(X, `insert into public.community_groups(owner_id,name,description,is_private) values('${X}','مجموعة أخرى','وصف 2',true) returning id`)).rows[0].id;
const pg = (await as(A, `insert into public.community_groups(owner_id,name,description,is_private) values('${A}','مجموعة خاصة','سري',true) returning id`)).rows[0].id;
await as(B, `select public.join_community_group('${g1}')`);
await admin(`insert into public.community_group_messages(group_id,user_id,content) values('${g2}','${X}','سر المجموعة الأخرى')`);
await admin(`insert into public.community_group_messages(group_id,user_id,content) values('${g1}','${A}','أهلا بالجميع')`);

// ---- root cause of the message leak, before 166 --------------------------------
const leakBefore = (await as(A, `select content from public.community_group_messages where group_id='${g2}'`)).rows;
ok(leakBefore.length === 1, 'BEFORE 166: a member of another group reads the private group messages (policy compared the member row with itself)');

// ---- apply 166 twice -----------------------------------------------------------
const m166 = read('../supabase/migrations/20261017130001_166_group_invites_moderation_media.sql');
await db.exec('reset role');
await db.exec(m166);
await db.exec(m166);
ok(true, 'migration 166 applies twice without error');

// ---- discover: every group is returned to every user, content stays closed ----
const discover = (await as(E, `select id,is_private,is_joined,join_status from public.get_community_groups()`)).rows;
ok([g1, g2, pg].every((id) => discover.some((r) => r.id === id)), 'discover returns public and private groups to a stranger');
ok(discover.every((r) => r.is_joined === false), 'stranger is a member of none');

// ---- message policies fixed ----------------------------------------------------
eq((await as(A, `select content from public.community_group_messages where group_id='${g2}'`)).rows.length, 0, 'AFTER 166: a member of another group no longer reads foreign messages');
ok(await fails(A, `insert into public.community_group_messages(group_id,user_id,content) values('${g2}','${A}','x')`, [], /row-level security/i), 'non-member cannot post into another group');
ok((await as(A, `select content from public.community_group_messages where group_id='${g1}'`)).rows.length === 1, 'member still reads own group messages');
await as(B, `insert into public.community_group_messages(group_id,user_id,content) values('${g1}','${B}','رد من العضو')`);
ok(true, 'member can post text');
await as(B, `insert into public.community_group_messages(group_id,user_id,content,media_url,media_type) values('${g1}','${B}','صورة','${B}/${g1}/1_a.jpg','image')`);
ok(true, 'member can post an attachment under his own folder');
ok(await fails(B, `insert into public.community_group_messages(group_id,user_id,content,media_url,media_type) values('${g1}','${B}','صورة','${A}/${g1}/1_a.jpg','image')`, [], /row-level security/i), 'attachment path of another sender is refused');
ok(await fails(B, `insert into public.community_group_messages(group_id,user_id,content,media_url,media_type) values('${g1}','${B}','صورة','${B}/${g2}/1_a.jpg','image')`, [], /row-level security/i), 'attachment path of another group is refused');
ok(await fails(B, `insert into public.community_group_messages(group_id,user_id,content,media_url) values('${g1}','${B}','x','${B}/${g1}/x.jpg')`, [], /media_pair/i), 'media url without type is refused');
ok(await fails(B, `insert into public.community_group_messages(group_id,user_id,content,media_url,media_type) values('${g1}','${B}','x','${B}/${g1}/x.exe','file')`, [], /media_type/i), 'unknown media type is refused');

// ---- message feed carries media keys -------------------------------------------
const feed = (await as(B, `select * from public.get_community_group_messages_155('${g1}')`)).rows.map((r) => r.get_community_group_messages_155);
const mediaRow = feed.find((r) => r.media_type === 'image');
ok(mediaRow && mediaRow.media_url === `${B}/${g1}/1_a.jpg` && 'edited_at' in mediaRow && 'content' in mediaRow && 'sender_name' in mediaRow, 'feed keeps old keys and adds media_url/media_type');
ok(feed.find((r) => r.media_type === null && r.media_url === null), 'text messages have null media keys');
let nonMemberFeed = 0;
try { nonMemberFeed = (await as(E, `select * from public.get_community_group_messages_155('${g1}')`)).rows.length; } catch (e) { nonMemberFeed = /group_membership_required/.test(String(e.message)) ? 0 : -1; }
ok(nonMemberFeed === 0, 'non-member gets nothing from the feed (empty or refused)');

// ---- invitations ---------------------------------------------------------------
ok(await fails(E, `select public.send_community_group_invitation('${g1}','${C}')`, [], /group_membership_required/), 'non-member cannot invite');
ok(await fails(B, `select public.send_community_group_invitation('${g1}','${B}')`, [], /invalid_invitee/), 'cannot invite himself');
ok(await fails(B, `select public.send_community_group_invitation('${g1}','${E}')`, [], /colleague_required/), 'only colleagues can be invited');
ok(await fails(B, `select public.send_community_group_invitation('${g1}','${Y}')`, [], /user_unavailable/), 'blocked user cannot be invited');
ok(await fails(B, `select public.send_community_group_invitation('${g1}','10000000-0000-4000-8000-0000000000ff')`, [], /user_not_found/), 'unknown user is refused');
eq((await as(B, `select public.send_community_group_invitation('${g1}','${C}') as r`)).rows[0].r, 'sent', 'member invites a colleague');
eq((await as(B, `select public.send_community_group_invitation('${g1}','${C}') as r`)).rows[0].r, 'already_invited', 'duplicate pending invitation is not created');
eq((await as(A, `select public.send_community_group_invitation('${g1}','${B}') as r`)).rows[0].r, 'already_member', 'inviting an existing member is a no-op');
const note = (await admin(`select * from public.notifications where user_id='${C}' and type='group_invitation'`)).rows;
eq(note.length, 1, 'exactly one notification for the invitee');
ok(note[0].actor_id === B && note[0].body_ar.includes('Member B') && note[0].body_ar.includes('«المجموعة الأولى»') && note[0].title_ar === 'دعوة إلى مجموعة', 'notification names the inviter and the group in Arabic');
ok(note[0].body_en.includes('Member B') && note[0].body_en.includes('المجموعة الأولى'), 'notification has an English body');
const invId = note[0].data.invitation_id;
ok(note[0].data.type === 'group_invitation' && note[0].data.group_id === g1 && note[0].data.group_name === 'المجموعة الأولى' && !!invId, 'notification payload routes to the invitation');

const card = (await as(C, `select * from public.get_community_group_invitation('${invId}')`)).rows;
eq(card.length, 1, 'invitee can open the invitation card');
ok(card[0].group_name === 'المجموعة الأولى' && card[0].inviter_name === 'Member B' && card[0].status === 'pending' && Number(card[0].members) === 2, 'card shows group, inviter, status and member count only');
ok(!('content' in card[0]) && !('messages' in card[0]), 'card contains no group content');
eq((await as(E, `select * from public.get_community_group_invitation('${invId}')`)).rows.length, 0, 'other users cannot open the invitation');
eq((await as(C, `select * from public.get_my_community_group_invitations()`)).rows.length, 1, 'invitee lists his pending invitation');
eq((await as(C, `select content from public.community_group_messages where group_id='${g1}'`)).rows.length, 0, 'invitee cannot read group messages before accepting');
eq((await as(C, `select * from public.get_community_group_messages_155('${g1}')`).catch(() => ({rows: []}))).rows.length, 0, 'invitee gets nothing from the feed before accepting');
ok(await fails(C, `select * from public.get_community_group_members('${g1}')`, [], /group_membership_required/), 'invitee cannot list members before accepting');
ok(await fails(E, `select public.respond_community_group_invitation('${invId}',true)`, [], /pending_invitation_not_found/), 'someone else cannot respond');
await as(C, `select public.respond_community_group_invitation('${invId}',false)`);
eq((await admin(`select status from public.community_group_invitations where id='${invId}'`)).rows[0].status, 'declined', 'decline is recorded');
eq((await admin(`select count(*)::int n from public.community_group_members where group_id='${g1}' and user_id='${C}'`)).rows[0].n, 0, 'decline does not join');
ok(await fails(C, `select public.respond_community_group_invitation('${invId}',true)`, [], /pending_invitation_not_found/), 'an answered invitation cannot be answered again');
eq((await as(C, `select * from public.get_my_community_group_invitations()`)).rows.length, 0, 'declined invitation leaves the pending list');
eq((await as(B, `select public.send_community_group_invitation('${g1}','${C}') as r`)).rows[0].r, 'sent', 're-invite after decline works');
const inv2 = (await admin(`select id from public.community_group_invitations where group_id='${g1}' and invitee_id='${C}' and status='pending'`)).rows[0].id;
eq((await as(C, `select public.respond_community_group_invitation('${inv2}',true) as r`)).rows[0].r, g1, 'accept returns the group id');
eq((await admin(`select count(*)::int n from public.community_group_members where group_id='${g1}' and user_id='${C}'`)).rows[0].n, 1, 'accept joins as member');
ok((await as(C, `select content from public.community_group_messages where group_id='${g1}'`)).rows.length >= 1, 'after accepting the member reads the group');

// private group: an invited colleague joins directly, an uninvited user only requests
eq((await as(A, `select public.send_community_group_invitation('${pg}','${D}') as r`)).rows[0].r, 'sent', 'owner invites into the private group');
eq((await as(E, `select public.join_community_group('${pg}') as r`)).rows[0].r, 'requested', 'uninvited user only sends a request');
eq((await as(D, `select public.join_community_group('${pg}') as r`)).rows[0].r, 'joined', 'invited user joins the private group directly');
eq((await admin(`select status from public.community_group_invitations where group_id='${pg}' and invitee_id='${D}'`)).rows[0].status, 'accepted', 'direct join marks the invitation accepted');

// ---- members list --------------------------------------------------------------
const members = (await as(B, `select * from public.get_community_group_members('${g1}')`)).rows;
ok(members.length === 3 && members[0].role === 'owner' && members[0].name === 'Owner A', 'members list shows the owner first with names');

// ---- removal -------------------------------------------------------------------
ok(await fails(B, `select public.kick_community_group_member('${g1}','${C}')`, [], /group_owner_required/), 'a member cannot remove another member');
ok(await fails(A, `select public.kick_community_group_member('${g1}','${A}')`, [], /cannot_remove_owner/), 'the owner cannot remove himself');
await as(B, `select public.send_community_group_invitation('${g1}','${D}')`).catch(() => {});
await as(A, `select public.kick_community_group_member('${g1}','${C}')`);
eq((await admin(`select count(*)::int n from public.community_group_members where group_id='${g1}' and user_id='${C}'`)).rows[0].n, 0, 'owner removes a member');
eq((await admin(`select count(*)::int n from public.community_group_bans where group_id='${g1}' and user_id='${C}'`)).rows[0].n, 1, 'removal records a ban');
ok(await fails(C, `select public.join_community_group('${g1}')`, [], /removed_from_group/), 'removed member cannot rejoin a public group alone');
ok(await fails(B, `select public.send_community_group_invitation('${g1}','${C}')`, [], /removed_from_group/), 'a member cannot re-invite a removed person');
eq((await as(C, `select content from public.community_group_messages where group_id='${g1}'`)).rows.length, 0, 'removed member no longer reads the group');
eq((await as(A, `select public.send_community_group_invitation('${g1}','${C}') as r`)).rows[0].r, 'sent', 'the owner can re-invite a removed person');
const inv3 = (await admin(`select id from public.community_group_invitations where group_id='${g1}' and invitee_id='${C}' and status='pending'`)).rows[0].id;
await as(C, `select public.respond_community_group_invitation('${inv3}',true)`);
eq((await admin(`select count(*)::int n from public.community_group_bans where group_id='${g1}' and user_id='${C}'`)).rows[0].n, 0, 'accepting the owner invitation clears the ban');
eq((await admin(`select count(*)::int n from public.community_group_members where group_id='${g1}' and user_id='${C}'`)).rows[0].n, 1, 'removed member is back after the owner invitation');

// removal also clears pending requests and invitations
await as(E, `select public.join_community_group('${pg}')`);
await as(A, `select public.send_community_group_invitation('${pg}','${D}')`).catch(() => {});
await as(A, `select public.kick_community_group_member('${pg}','${E}')`);
eq((await admin(`select status from public.community_group_join_requests where group_id='${pg}' and user_id='${E}'`)).rows[0].status, 'rejected', 'removal rejects a pending join request');
ok(await fails(E, `select public.join_community_group('${pg}')`, [], /removed_from_group/), 'removed person cannot request again');

// ---- leaving -------------------------------------------------------------------
await as(B, `select public.leave_community_group('${g1}')`);
eq((await admin(`select count(*)::int n from public.community_group_members where group_id='${g1}' and user_id='${B}'`)).rows[0].n, 0, 'a member can leave');
ok(await fails(A, `select public.leave_community_group('${g1}')`, [], /owner_cannot_leave/), 'the owner cannot leave');
const afterLeave = (await as(B, `select id,is_joined from public.get_community_groups()`)).rows.find((r) => r.id === g1);
ok(afterLeave && afterLeave.is_joined === false, 'after leaving the group is listed as not joined');
await as(B, `select public.join_community_group('${g1}')`);

// ---- invite link ---------------------------------------------------------------
ok(await fails(E, `select public.get_community_group_invite_code('${g1}')`, [], /group_membership_required/), 'non-member cannot read the invite code');
const code = (await as(B, `select public.get_community_group_invite_code('${g1}') as c`)).rows[0].c;
ok(/^[0-9a-f]{10}$/.test(code), 'invite code is ten lowercase hex characters');
eq((await as(A, `select public.get_community_group_invite_code('${g1}') as c`)).rows[0].c, code, 'every member sees the same code');
const preview = (await as(F, `select * from public.get_community_group_by_invite_code('${code.toUpperCase()}')`)).rows;
ok(preview.length === 1 && preview[0].name === 'المجموعة الأولى' && preview[0].is_joined === false && preview[0].is_removed === false && !('content' in preview[0]), 'link preview is case-insensitive and shows the card only');
eq((await as(F, `select * from public.get_community_group_by_invite_code('nonexistent')`)).rows.length, 0, 'unknown code shows nothing');
ok(await fails(F, `select public.join_community_group_by_code('nonexistent')`, [], /invite_not_found/), 'joining with an unknown code fails');
eq((await as(F, `select public.join_community_group_by_code('${code}') as g`)).rows[0].g, g1, 'a link joins the group');
ok((await admin(`select 1 from public.community_group_members where group_id='${g1}' and user_id='${F}'`)).rows.length === 1, 'link joiner is a member');
await as(A, `select public.kick_community_group_member('${g1}','${F}')`);
ok(await fails(F, `select public.join_community_group_by_code('${code}')`, [], /removed_from_group/), 'a removed person cannot use the link');
ok(await fails(B, `select public.reset_community_group_invite_code('${g1}')`, [], /group_owner_required/), 'only the owner resets the link');
const fresh = (await as(A, `select public.reset_community_group_invite_code('${g1}') as c`)).rows[0].c;
ok(fresh !== code && /^[0-9a-f]{10}$/.test(fresh), 'owner resets the link');
ok(await fails(E, `select public.join_community_group_by_code('${code}')`, [], /invite_not_found/), 'the old link stops working');

// ---- limits and permissions ----------------------------------------------------
await admin(`delete from public.community_group_invitations where inviter_id='${A}'`);
await admin(`insert into public.community_group_invitations(group_id,inviter_id,invitee_id,status) select '${g1}','${A}',gen_random_uuid(),'declined' from generate_series(1,1) where false`);
const ghosts = [];
for (let i = 0; i < 30; i++) {
  const id = `20000000-0000-4000-8000-${String(i).padStart(12, '0')}`;
  ghosts.push(id);
  await admin(`insert into public.users values('${id}','Ghost ${i}',null)`);
  await admin(`insert into public.community_group_invitations(group_id,inviter_id,invitee_id,status) values('${pg}','${A}','${id}','declined')`);
}
await admin(`insert into public.friend_requests values('${A}','${E}','accepted')`);
ok(await fails(A, `select public.send_community_group_invitation('${g1}','${E}')`, [], /too_many_invitations/), 'more than 30 invitations in an hour are refused');

await db.exec('reset role');
await db.exec('set role anon');
for (const call of [
  `select public.send_community_group_invitation('${g1}','${C}')`,
  `select public.kick_community_group_member('${g1}','${C}')`,
  `select public.get_community_group_invite_code('${g1}')`,
  `select public.get_my_community_group_invitations()`,
  `select public.join_community_group_by_code('x')`,
  `select public.respond_community_group_invitation('${invId}',true)`
]) {
  let denied = false;
  try { await db.query(call); } catch (e) { denied = /permission denied/i.test(String(e.message)); }
  ok(denied, `anon cannot execute: ${call.slice(0, 60)}`);
}
await db.exec('reset role');
for (const table of ['community_group_invitations', 'community_group_bans']) {
  ok(await fails(A, `select * from public.${table}`, [], /permission denied/i), `${table} is not readable by clients`);
}

// ---- storage -------------------------------------------------------------------
ok((await admin(`select public,file_size_limit from storage.buckets where id='group_media'`)).rows[0].public === false, 'group_media bucket is private');
await as(B, `insert into storage.objects(bucket_id,name) values('group_media','${B}/${g1}/a.jpg')`);
ok(true, 'a member uploads under his own folder of his group');
ok(await fails(E, `insert into storage.objects(bucket_id,name) values('group_media','${E}/${g1}/a.jpg')`, [], /row-level security/i), 'a non-member cannot upload');
ok(await fails(B, `insert into storage.objects(bucket_id,name) values('group_media','${A}/${g1}/a.jpg')`, [], /row-level security/i), 'cannot upload into another sender folder');
eq((await as(A, `select name from storage.objects where bucket_id='group_media'`)).rows.length, 1, 'a member reads group files');
eq((await as(E, `select name from storage.objects where bucket_id='group_media'`)).rows.length, 0, 'a non-member reads nothing');

// ---- definer functions pin the search path -------------------------------------
const meta = (await admin(`select proname,prosecdef,proconfig from pg_proc where proname in ('kick_community_group_member','get_community_group_members','get_community_group_invite_code','reset_community_group_invite_code','get_community_group_by_invite_code','join_community_group_by_code','send_community_group_invitation','respond_community_group_invitation','get_community_group_invitation','get_my_community_group_invitations','join_community_group')`)).rows;
ok(meta.length === 11 && meta.every((r) => r.prosecdef && String(r.proconfig).includes('search_path=')), 'all new definer functions pin the search path');

// ---- Dart source contracts -------------------------------------------------------
const chatSrc = read('../lib/screens/groups/group_chat_screen.dart');
const mainSrc = read('../lib/main.dart');
const notifSrc = read('../lib/screens/notifications/notifications_screen.dart');
const manifest = read('../android/app/src/main/AndroidManifest.xml');
const privSrc = read('../lib/screens/private_groups_screen.dart');
const groupsSrc = read('../lib/screens/groups/groups_screen.dart');
ok(/uploadGroupAttachment/.test(chatSrc) && /mediaPath:/.test(chatSrc) && /LinkifiedText165/.test(chatSrc) && /VoiceRecordingDialog/.test(chatSrc), 'group chat sends media, voice and shows links');
ok(/showGroupInviteSheet/.test(chatSrc) && /GroupMembersScreen/.test(chatSrc), 'group chat has invite and members actions');
ok(/type == 'group_invitation'/.test(mainSrc) && /host == 'group'/.test(mainSrc), 'main.dart routes group push and link');
ok(/type == 'group_invitation'/.test(notifSrc), 'notifications screen opens group invitations');
ok(/android:host="group"/.test(manifest), 'manifest accepts zameel://group');
ok(/minimumSize: const Size\(0, 36\)/.test(privSrc) && /minimumSize: const Size\(0, 36\)/.test(groupsSrc), 'join buttons have a finite minimum width');

console.log(`PASS: groups 166 (${checks} checks): message-policy leak fixed, invitations with notification, private-group invite join, owner removal with ban and re-invite, leave, invite link, storage policy, anon and table denial.`);
