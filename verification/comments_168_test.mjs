import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
const A = '10000000-0000-4000-8000-000000000001'; // post owner
const B = '10000000-0000-4000-8000-000000000002'; // commenter
const C = '10000000-0000-4000-8000-000000000003'; // replier / liker
const P = '20000000-0000-4000-8000-000000000001';
const K = '20000000-0000-4000-8000-000000000002';

await db.exec(`create role anon; create role authenticated;
create table public.users(id uuid primary key, name text);
insert into public.users values('${A}','أحمد'),('${B}','بسمة'),('${C}','جود');
create table public.notifications(id uuid primary key default gen_random_uuid(), user_id uuid, actor_id uuid, type text,
  title_ar text, title_en text, body_ar text, body_en text, data jsonb default '{}'::jsonb);
create table public.posts(id uuid primary key, user_id uuid);
create table public.clips(id uuid primary key, user_id uuid);
create table public.post_comments(id uuid primary key default gen_random_uuid(), post_id uuid, user_id uuid, parent_comment_id uuid);
create table public.post_comment_likes(comment_id uuid, user_id uuid, primary key(comment_id,user_id));
create table public.clip_comments(id uuid primary key default gen_random_uuid(), clip_id uuid, user_id uuid, parent_comment_id uuid);
create table public.clip_comment_likes(comment_id uuid, user_id uuid, primary key(comment_id,user_id));
insert into public.posts values('${P}','${A}');
insert into public.clips values('${K}','${A}');
create function public.notify_on_post_comment() returns trigger language plpgsql as $$ begin return new; end $$;
create function public.notify_on_clip_comment() returns trigger language plpgsql as $$ begin return new; end $$;
create trigger t_old1 after insert on public.post_comments for each row execute function public.notify_on_post_comment();
create trigger t_old2 after insert on public.clip_comments for each row execute function public.notify_on_clip_comment();
`);
await db.exec(fs.readFileSync(new URL('../supabase/migrations/20261017140001_168_comment_notifications.sql', import.meta.url), 'utf8'));
// the migration replaces functions only; the original triggers stay attached.
let checks = 0;
const ok = (c, m) => { assert.ok(c, m); checks++; };
const n = async (where = 'true') => (await db.query(`select * from public.notifications where ${where} order by type`)).rows;
const cnt = async (type, uid) => (await db.query(`select count(*)::int c from public.notifications where type=$1 and user_id=$2`, [type, uid])).rows[0].c;

// 1. plain comment on post -> owner notified once
const c1 = (await db.query(`insert into public.post_comments(post_id,user_id) values($1,$2) returning id`, [P, B])).rows[0].id;
ok(await cnt('post_comment', A) === 1, 'owner gets post_comment');
// 2. reply by C to B's comment -> B gets comment_reply; A (owner) also gets post_comment
const r1 = (await db.query(`insert into public.post_comments(post_id,user_id,parent_comment_id) values($1,$2,$3) returning id`, [P, C, c1])).rows[0].id;
ok(await cnt('comment_reply', B) === 1, 'comment author gets reply');
ok(await cnt('post_comment', A) === 2, 'owner still gets post comment for reply to someone else');
const rep = (await n(`type='comment_reply'`))[0];
ok(rep.body_ar.includes('جود') && rep.data.parent_comment_id === c1 && rep.data.post_id === P, 'reply payload');
// 3. replying to your own comment -> nothing
await db.query(`insert into public.post_comments(post_id,user_id,parent_comment_id) values($1,$2,$3)`, [P, B, c1]);
ok(await cnt('comment_reply', B) === 1, 'no self reply notification');
// 4. owner's own comment replied by C -> only reply notification, no post_comment for owner
const ownC = (await db.query(`insert into public.post_comments(post_id,user_id) values($1,$2) returning id`, [P, A])).rows[0].id;
const before = await cnt('post_comment', A);
await db.query(`insert into public.post_comments(post_id,user_id,parent_comment_id) values($1,$2,$3)`, [P, C, ownC]);
ok(await cnt('post_comment', A) === before, 'owner not double notified');
ok(await cnt('comment_reply', A) === 1, 'owner gets reply to own comment');
// 5. like on comment
await db.query(`insert into public.post_comment_likes values($1,$2)`, [c1, C]);
ok(await cnt('comment_like', B) === 1, 'like notifies author');
await db.query(`delete from public.post_comment_likes where comment_id=$1 and user_id=$2`, [c1, C]);
ok(await cnt('comment_like', B) === 0, 'unlike removes notification');
await db.query(`insert into public.post_comment_likes values($1,$2)`, [c1, C]);
ok(await cnt('comment_like', B) === 0, 'like-unlike-like does not notify again');
// 6. self-like nothing
await db.query(`insert into public.post_comment_likes values($1,$2)`, [c1, B]);
ok(await cnt('comment_like', B) === 0, 'self like silent');
// 7. deleting the comment removes its notifications
const c2 = (await db.query(`insert into public.post_comments(post_id,user_id) values($1,$2) returning id`, [P, B])).rows[0].id;
await db.query(`insert into public.post_comment_likes values($1,$2)`, [c2, A]);
ok(await cnt('comment_like', B) === 1, 'second like notifies');
await db.query(`delete from public.post_comments where id=$1`, [c2]);
ok(await cnt('comment_like', B) === 0, 'delete comment cleans like notifications');

// clips
const k1 = (await db.query(`insert into public.clip_comments(clip_id,user_id) values($1,$2) returning id`, [K, B])).rows[0].id;
ok(await cnt('clip_comment', A) === 1, 'clip owner notified');
await db.query(`insert into public.clip_comments(clip_id,user_id,parent_comment_id) values($1,$2,$3)`, [K, C, k1]);
ok(await cnt('clip_comment_reply', B) === 1, 'clip reply notifies comment author');
await db.query(`insert into public.clip_comment_likes values($1,$2)`, [k1, C]);
ok(await cnt('clip_comment_like', B) === 1, 'clip like notifies');
await db.query(`delete from public.clip_comment_likes where comment_id=$1 and user_id=$2`, [k1, C]);
ok(await cnt('clip_comment_like', B) === 0, 'clip unlike cleans');
// idempotent rerun
await db.exec(fs.readFileSync(new URL('../supabase/migrations/20261017140001_168_comment_notifications.sql', import.meta.url), 'utf8'));
ok(true, 'migration reruns');
console.log(`comments_168_test: ${checks} checks passed`);
