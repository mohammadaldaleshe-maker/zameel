import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
const a = '10000000-0000-4000-8000-000000000001', b = '10000000-0000-4000-8000-000000000002', stranger = '10000000-0000-4000-8000-000000000003';
const c1 = '20000000-0000-4000-8000-000000000001', c2 = '20000000-0000-4000-8000-000000000002';
await db.exec(`create role anon; create role authenticated; create role service_role; create schema auth;
create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
create table public.users(id uuid primary key);
insert into public.users values('${a}'),('${b}'),('${stranger}');
create table public.conversations(id uuid primary key);
create table public.conversation_members(conversation_id uuid, user_id uuid);
create table public.user_blocks(blocker_id uuid, blocked_id uuid);
create table public.messages(id uuid primary key default gen_random_uuid(), conversation_id uuid references public.conversations(id),
  sender_id uuid references public.users(id), content text, media_url text, media_type text, is_read boolean default false,
  delivered_at timestamptz, read_at timestamptz, created_at timestamptz not null default now());
create table public.zameel_deleted_messages(message_id uuid primary key);
create table public.zameel_hidden_messages(message_id uuid, user_id uuid);
create table public.zameel_message_likes(message_id uuid, user_id uuid);
create function public.is_conversation_member(uuid, uuid) returns boolean language sql as $$select exists(select 1 from public.conversation_members where conversation_id=$1 and user_id=$2)$$;
insert into public.conversations values('${c1}'),('${c2}');
insert into public.conversation_members values('${c1}','${a}'),('${c1}','${b}'),('${c2}','${a}'),('${c2}','${stranger}');
grant usage on schema public, auth to authenticated, anon;
grant select, insert on all tables in schema public to authenticated;`);
await db.exec(fs.readFileSync(new URL('../supabase/migrations/20261017110001_164_message_reply.sql', import.meta.url), 'utf8'));

let checks = 0;
const ok = (cond, msg) => { assert.ok(cond, msg); checks++; };
const as = async (uid, sql, params) => { await db.exec(`set test.uid='${uid}'`); return db.query(sql, params); };
const fails = async (uid, sql, params, re) => {
  try { await as(uid, sql, params); } catch (e) { return re.test(String(e.message)); }
  return false;
};

// original message from A in conversation 1
const first = (await db.query(`insert into public.messages(conversation_id,sender_id,content) values('${c1}','${a}','السلام عليكم') returning id`)).rows[0].id;
const other = (await db.query(`insert into public.messages(conversation_id,sender_id,content) values('${c2}','${a}','محادثة ثانية') returning id`)).rows[0].id;

await db.exec('set role authenticated');
// B replies to A's message
const reply = (await as(b, 'select public.zameel_send_reply164($1,$2,$3) as r', [c1, '  وعليكم السلام  ', first])).rows[0].r;
ok(reply.reply_to_id === first, 'reply stores the replied message id');
ok(reply.content === 'وعليكم السلام', 'content is trimmed');
ok(reply.reply_preview === 'السلام عليكم', 'preview returns the replied text');
ok(reply.reply_sender_id === a, 'preview returns the author of the replied message');
ok(reply.sender_id === b, 'sender is the caller, never a parameter');

// reply without target works as a plain message
const plain = (await as(b, 'select public.zameel_send_reply164($1,$2,$3) as r', [c1, 'رسالة عادية', null])).rows[0].r;
ok(plain.reply_to_id === null && plain.reply_preview === null, 'null target gives a normal message');

// guards
ok(await fails(b, 'select public.zameel_send_reply164($1,$2,$3)', [c1, 'x', other], /reply_target_not_in_conversation/), 'cannot reply to a message of another conversation');
ok(await fails(stranger, 'select public.zameel_send_reply164($1,$2,$3)', [c1, 'x', first], /conversation_membership_required/), 'non-member cannot send');
ok(await fails(b, 'select public.zameel_send_reply164($1,$2,$3)', [c1, '   ', first], /message_required/), 'empty text refused');
await db.exec('reset role'); await db.exec(`reset test.uid`);
ok(await fails('', 'select public.zameel_send_reply164($1,$2,$3)', [c1, 'x', first], /not_authenticated/), 'anonymous call is refused');
await db.exec(`insert into public.user_blocks values('${a}','${b}')`);
await db.exec('set role authenticated');
ok(await fails(b, 'select public.zameel_send_reply164($1,$2,$3)', [c1, 'x', first], /conversation_blocked/), 'blocked conversation refused');
await db.exec('reset role'); await db.exec('delete from public.user_blocks');

// anon cannot call
await db.exec('set role anon');
let denied = false;
try { await db.query('select public.zameel_send_reply164($1,$2,$3)', [c1, 'x', first]); } catch (e) { denied = /permission denied/i.test(String(e.message)); }
ok(denied, 'anon cannot execute zameel_send_reply164');
await db.exec('reset role');

// listing keeps the old keys and adds the reply keys
await db.exec('set role authenticated');
const list = (await as(a, 'select public.zameel_chat_messages($1) as r', [c1])).rows[0].r;
const row = list.find(m => m.id === reply.id);
for (const key of ['id', 'content', 'sender_id', 'created_at', 'media_url', 'media_type', 'is_read', 'delivered_at', 'read_at', 'deleted', 'likes', 'liked']) ok(key in row, `old key ${key} is still returned`);
ok(row.reply_to_id === first && row.reply_preview === 'السلام عليكم' && row.reply_sender_id === a, 'listing carries the reply info');
ok(list.find(m => m.id === first).reply_to_id === null, 'normal messages have no reply info');

// deleted original: preview shows the deleted notice and the reply survives
await db.exec('reset role');
await db.exec(`insert into public.zameel_deleted_messages values('${first}')`);
await db.exec('set role authenticated');
const afterDelete = (await as(a, 'select public.zameel_chat_messages($1) as r', [c1])).rows[0].r.find(m => m.id === reply.id);
ok(afterDelete.reply_preview === 'تم حذف هذه الرسالة', 'deleted original shows the deleted notice');
await db.exec('reset role');

// removing the original row keeps the reply (on delete set null)
await db.exec(`delete from public.zameel_deleted_messages`);
await db.exec(`delete from public.messages where id='${first}'`);
const left = (await db.query(`select reply_to_id from public.messages where id='${reply.id}'`)).rows[0];
ok(left && left.reply_to_id === null, 'hard-deleting the original keeps the reply and clears the link');

// media original shows an attachment label
const media = (await db.query(`insert into public.messages(conversation_id,sender_id,content,media_url,media_type) values('${c1}','${a}','','path/x.jpg','image') returning id`)).rows[0].id;
await db.exec('set role authenticated');
const mediaReply = (await as(b, 'select public.zameel_send_reply164($1,$2,$3) as r', [c1, 'جميلة', media])).rows[0].r;
ok(mediaReply.reply_preview === '📎 مرفق', 'media original is shown as an attachment label');
await db.exec('reset role');

// both functions are security definer with a pinned search_path
const meta = (await db.query(`select proname, prosecdef, proconfig from pg_proc where proname in ('zameel_send_reply164','zameel_chat_messages')`)).rows;
ok(meta.length === 2 && meta.every(r => r.prosecdef && String(r.proconfig).includes('search_path=')), 'security definer with pinned search_path');

// Dart wiring
const dart = fs.readFileSync(new URL('../lib/screens/chat/chat_screen.dart', import.meta.url), 'utf8');
ok(dart.includes("zameel_send_reply164") && dart.includes("'reply'") && dart.includes('_replyQuote') && dart.includes('_replyBar'), 'chat screen uses reply RPC, menu entry, quote and reply bar');

console.log(`PASS: message reply 164 (${checks} checks): reply link, same-conversation rule, membership/block guards, old list keys kept, deleted/media previews.`);
