import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
const owner = '10000000-0000-4000-8000-000000000001';
const m1 = '10000000-0000-4000-8000-000000000002';
const m2 = '10000000-0000-4000-8000-000000000003';
const outsider = '10000000-0000-4000-8000-000000000004';
const L = '30000000-0000-4000-8000-000000000001';
const L2 = '30000000-0000-4000-8000-000000000002';

await db.exec(`create role anon; create role authenticated; create role service_role; create schema auth; create schema storage;
create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
create table public.users(id uuid primary key, name text, profile_image text);
insert into public.users values('${owner}','المنظم',null),('${m1}','سارة','https://x/y.png'),('${m2}','خالد',null),('${outsider}','غريب',null);
create table public.social_lammas (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  max_members smallint not null default 3,
  expires_at timestamptz not null default (now() + interval '3 hours'),
  status text not null default 'open' check (status in ('open','full','ended'))
);
create table public.social_lamma_members (
  lamma_id uuid not null references public.social_lammas(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (lamma_id,user_id)
);
create table public.social_lamma_messages (
  id uuid primary key default gen_random_uuid(),
  lamma_id uuid not null references public.social_lammas(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete cascade,
  body text not null check(char_length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
alter table public.social_lamma_messages enable row level security;
create policy lamma_messages_members_insert on public.social_lamma_messages
for insert to authenticated with check (sender_id=auth.uid());
create policy lamma_messages_members_read on public.social_lamma_messages
for select to authenticated using (true);
create table storage.buckets(id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(), bucket_id text, name text);
alter table storage.objects enable row level security;
insert into public.social_lammas(id,creator_id,title,max_members) values('${L}','${owner}','لمة تجريبية',3),('${L2}','${m1}','لمة ثانية',3);
insert into public.social_lamma_members(lamma_id,user_id) values('${L}','${owner}'),('${L2}','${m1}');
grant usage on schema public, auth, storage to authenticated, anon;
grant select, insert, delete on public.social_lamma_messages to authenticated;
grant select on public.social_lamma_members, public.social_lammas, public.users to authenticated;
grant select, insert, delete on storage.objects to authenticated;
-- Original join function as it was before 165 (kept so we can prove 165 replaces it safely)
create function public.join_social_lamma(p_lamma uuid) returns boolean language sql as $$select false$$;`);
const sql = fs.readFileSync(new URL('../supabase/migrations/20261017120001_165_lamma_moderation_media.sql', import.meta.url), 'utf8');
await db.exec(sql);

let checks = 0;
const ok = (cond, msg) => { assert.ok(cond, msg); checks++; };
const as = async (uid, text, params) => { await db.exec(`set test.uid='${uid}'`); return db.query(text, params); };
const fails = async (uid, text, params, re) => {
  try { await as(uid, text, params); } catch (e) { return re.test(String(e.message)); }
  return false;
};
const count = async (text) => Number((await db.query(text)).rows[0].c);
const status = async (id) => (await db.query(`select status from public.social_lammas where id='${id}'`)).rows[0].status;

// Migration is repeatable.
await db.exec(sql);
ok(true, 'migration can be applied twice');

await db.exec('set role authenticated');
// join: members m1, m2 fill the Lamma (cap 3 with the creator)
ok((await as(m1, 'select public.join_social_lamma($1) as r', [L])).rows[0].r === true, 'first member joins');
ok((await as(m2, 'select public.join_social_lamma($1) as r', [L])).rows[0].r === true, 'second member joins');
await db.exec('reset role');
ok(await status(L) === 'full', 'Lamma is full at capacity');
await db.exec('set role authenticated');
ok((await as(outsider, 'select public.join_social_lamma($1) as r', [L])).rows[0].r === false, 'outsider cannot join a full Lamma');

// leave
ok(await fails(owner, 'select public.leave_social_lamma($1)', [L], /creator_cannot_leave/), 'creator cannot leave');
ok((await as(m2, 'select public.leave_social_lamma($1) as r', [L])).rows[0].r === true, 'member leaves');
await db.exec('reset role');
ok(await status(L) === 'open', 'leaving a full Lamma reopens it');
ok(await count(`select count(*) c from public.social_lamma_members where lamma_id='${L}' and user_id='${m2}'`) === 0, 'leaver is no longer a member');
await db.exec('set role authenticated');
ok((await as(m2, 'select public.join_social_lamma($1) as r', [L])).rows[0].r === true, 'a member who left may join again');

// get_lamma_members
const list = (await as(m1, 'select * from public.get_lamma_members($1)', [L])).rows;
ok(list.length === 3 && list[0].is_creator === true && list[0].name === 'المنظم', 'members list starts with the creator and carries names');
ok(list.some(r => r.user_id === m1 && r.name === 'سارة' && r.profile_image === 'https://x/y.png'), 'members list carries profile data');
ok(await fails(outsider, 'select * from public.get_lamma_members($1)', [L], /membership_required/), 'non-member cannot list members');

// kick
ok(await fails(m1, 'select public.kick_social_lamma_member($1,$2)', [L, m2], /creator_required/), 'only the creator can remove a member');
ok(await fails(owner, 'select public.kick_social_lamma_member($1,$2)', [L, owner], /cannot_remove_creator/), 'creator cannot remove themselves');
ok((await as(owner, 'select public.kick_social_lamma_member($1,$2) as r', [L, m2])).rows[0].r === true, 'creator removes a member');
await db.exec('reset role');
ok(await count(`select count(*) c from public.social_lamma_members where lamma_id='${L}' and user_id='${m2}'`) === 0, 'removed member is gone');
ok(await count(`select count(*) c from public.social_lamma_bans where lamma_id='${L}' and user_id='${m2}'`) === 1, 'removal is recorded');
await db.exec('set role authenticated');
ok(await fails(m2, 'select public.join_social_lamma($1)', [L], /removed_from_lamma/), 'removed member cannot rejoin');
ok(await fails(m2, 'select * from public.get_lamma_members($1)', [L], /membership_required/), 'removed member cannot read the members list');
await db.exec('reset role');

// bans table is private
await db.exec('set role authenticated');
let denied = false;
try { await db.query('select * from public.social_lamma_bans'); } catch (e) { denied = /permission denied/i.test(String(e.message)); }
ok(denied, 'clients cannot read the ban list directly');
await db.exec('reset role');

// reopen when a removal frees a seat in a full Lamma
await db.exec(`insert into public.social_lamma_members(lamma_id,user_id) values('${L}','${outsider}') on conflict do nothing`);
await db.exec(`update public.social_lammas set status='full' where id='${L}'`);
await db.exec('set role authenticated');
await as(owner, 'select public.kick_social_lamma_member($1,$2)', [L, outsider]);
await db.exec('reset role');
ok(await status(L) === 'open', 'removing a member from a full Lamma reopens it');

// anonymous and public cannot call the new functions
for (const fn of ['leave_social_lamma(uuid)', 'kick_social_lamma_member(uuid,uuid)', 'get_lamma_members(uuid)']) {
  await db.exec('set role anon');
  let anonDenied = false;
  try {
    const args = fn.includes(',') ? `'${L}','${m1}'` : `'${L}'`;
    await db.query(`select * from public.${fn.split('(')[0]}(${args})`);
  } catch (e) { anonDenied = /permission denied/i.test(String(e.message)); }
  ok(anonDenied, `anon cannot execute ${fn}`);
  await db.exec('reset role');
}
await db.exec('reset role');
await db.exec(`reset test.uid`);
ok(await fails('', 'select public.leave_social_lamma($1)', [L], /./), 'unauthenticated leave is refused');

// messages: text still works, media must live under the sender's own folder for this Lamma
await db.exec('set role authenticated');
await as(owner, `insert into public.social_lamma_messages(lamma_id,sender_id,body) values($1,$2,'مرحبا')`, [L, owner]);
ok(await count(`select count(*) c from public.social_lamma_messages`) === 1, 'plain text message still inserts without media columns');
await as(owner, `insert into public.social_lamma_messages(lamma_id,sender_id,body,media_url,media_type) values($1,$2,'صورة',$3,'image')`, [L, owner, `${owner}/${L}/1.jpg`]);
ok(await count(`select count(*) c from public.social_lamma_messages where media_type='image'`) === 1, 'media message with own folder path inserts');
ok(await fails(owner, `insert into public.social_lamma_messages(lamma_id,sender_id,body,media_url,media_type) values($1,$2,'صورة',$3,'image')`, [L, owner, `${m1}/${L}/1.jpg`], /row-level security/i), "cannot point at someone else's folder");
ok(await fails(owner, `insert into public.social_lamma_messages(lamma_id,sender_id,body,media_url,media_type) values($1,$2,'صورة',$3,'image')`, [L, owner, `${owner}/${L2}/1.jpg`], /row-level security/i), 'cannot point at another Lamma folder');
ok(await fails(owner, `insert into public.social_lamma_messages(lamma_id,sender_id,body,media_url,media_type) values($1,$2,'x',$3,'exe')`, [L, owner, `${owner}/${L}/1.exe`], /social_lamma_messages_media_type_165|check/i), 'unknown media type refused');
ok(await fails(owner, `insert into public.social_lamma_messages(lamma_id,sender_id,body,media_url) values($1,$2,'x',$3)`, [L, owner, `${owner}/${L}/1.jpg`], /social_lamma_messages_media_pair_165|check/i), 'path without a media type refused');
ok(await fails(outsider, `insert into public.social_lamma_messages(lamma_id,sender_id,body) values($1,$2,'x')`, [L, outsider], /row-level security/i), 'non-member cannot post');
await db.exec('reset role');

// bucket + storage policies
const bucket = (await db.query(`select * from storage.buckets where id='lamma_media'`)).rows[0];
ok(bucket && bucket.public === false && Number(bucket.file_size_limit) === 26214400, 'private bucket with a 25 MB limit exists');
ok(bucket.allowed_mime_types.includes('audio/mp4') && bucket.allowed_mime_types.includes('video/mp4') && bucket.allowed_mime_types.includes('image/jpeg'), 'bucket accepts photo, video and voice types');
ok(!bucket.allowed_mime_types.includes('text/html') && !bucket.allowed_mime_types.includes('image/svg+xml'), 'bucket refuses scriptable types');

await db.exec('set role authenticated');
await as(owner, `insert into storage.objects(bucket_id,name) values('lamma_media',$1)`, [`${owner}/${L}/a.jpg`]);
ok(await count(`select count(*) c from storage.objects`) === 1, 'member can upload to their own folder');
ok(await fails(owner, `insert into storage.objects(bucket_id,name) values('lamma_media',$1)`, [`${m1}/${L}/a.jpg`], /row-level security/i), "cannot upload into another user's folder");
ok(await fails(outsider, `insert into storage.objects(bucket_id,name) values('lamma_media',$1)`, [`${outsider}/${L}/a.jpg`], /row-level security/i), 'non-member cannot upload');
ok(await fails(m2, `insert into storage.objects(bucket_id,name) values('lamma_media',$1)`, [`${m2}/${L}/a.jpg`], /row-level security/i), 'removed member cannot upload');
ok((await as(m1, `select count(*) c from storage.objects where bucket_id='lamma_media'`)).rows[0].c == 1, 'member can read Lamma files');
ok((await as(outsider, `select count(*) c from storage.objects where bucket_id='lamma_media'`)).rows[0].c == 0, 'non-member sees no Lamma files');
ok((await as(m2, `select count(*) c from storage.objects where bucket_id='lamma_media'`)).rows[0].c == 0, 'removed member sees no Lamma files');
await as(m1, `delete from storage.objects where bucket_id='lamma_media'`);
await db.exec('reset role');
ok(await count(`select count(*) c from storage.objects`) === 1, "a member cannot delete another user's file");
await db.exec('set role authenticated');
await as(owner, `delete from storage.objects where bucket_id='lamma_media'`);
await db.exec('reset role');
ok(await count(`select count(*) c from storage.objects`) === 0, 'the owner can delete their own file');

// all new functions are security definer with a pinned search_path
const meta = (await db.query(`select proname, prosecdef, proconfig from pg_proc where proname in ('leave_social_lamma','kick_social_lamma_member','get_lamma_members','join_social_lamma') and pronamespace='public'::regnamespace`)).rows;
ok(meta.length === 4 && meta.every(r => r.prosecdef && String(r.proconfig).includes('search_path=')), 'security definer with a pinned search_path');

// Dart wiring
const read = (p) => fs.readFileSync(new URL(p, import.meta.url), 'utf8');
const screen = read('../lib/screens/social/lamma_screen.dart');
const chat = read('../lib/screens/social/lamma_chat_screen.dart');
const links = read('../lib/widgets/linkified_text165.dart');
ok(screen.includes('leave_social_lamma') && screen.includes('removed_from_lamma') && screen.includes("'creator_id'") && screen.includes('_creatorNames') && screen.includes('_search'), 'Lamma list: leave, removed notice, organizer names, search');
ok(!/insijam|social_discovery|react_social_discovery/i.test(screen), 'Lamma screen no longer carries Insijam');
ok(chat.includes('get_lamma_members') && chat.includes('kick_social_lamma_member') && chat.includes('leave_social_lamma') && chat.includes('لم تعد عضواً في هذه اللّمّة'), 'Lamma chat: members, remove, leave, removed state');
ok(chat.includes("'lamma_media'") && chat.includes("'media_url'") && chat.includes("'media_type'") && chat.includes('VoiceRecordingDialog') && chat.includes('pickImage') && chat.includes('pickVideo') && chat.includes('LinkifiedText165') && chat.includes('social_lamma_messages'), 'Lamma chat: photo, video, voice note and links');
ok(chat.includes('late final Stream') && !/final stream = _db/.test(chat), 'chat stream is created once, not on every rebuild');
ok(links.includes('TapGestureRecognizer') && links.includes('dispose') && links.includes('launchUrl'), 'links widget disposes recognizers and opens links');

console.log(`PASS: lamma 165 (${checks} checks): leave, remove + ban, members list, media columns and path rule, private bucket policies, Dart wiring.`);
