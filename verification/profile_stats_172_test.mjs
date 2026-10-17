import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
const ME = '10000000-0000-4000-8000-000000000001';
const F1 = '10000000-0000-4000-8000-000000000002'; // accepted friend (I sent)
const F2 = '10000000-0000-4000-8000-000000000003'; // accepted friend (they sent)
const F3 = '10000000-0000-4000-8000-000000000004'; // friend I blocked
const PEND = '10000000-0000-4000-8000-000000000005'; // pending only
const FOL = '10000000-0000-4000-8000-000000000006'; // follower only

await db.exec(`create role anon; create role authenticated; create schema auth;
create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
create table public.posts(id uuid primary key default gen_random_uuid(), user_id uuid, is_hidden boolean default false, upload_state156 text default 'ready', created_at timestamptz default now());
create table public.clips(id uuid primary key default gen_random_uuid(), user_id uuid, is_hidden boolean default false, upload_state156 text default 'ready', views_count bigint default 0, created_at timestamptz default now());
create table public.social_stories(id uuid primary key default gen_random_uuid(), user_id uuid, created_at timestamptz default now());
create table public.likes(user_id uuid, post_id uuid, created_at timestamptz default now());
create table public.clip_likes(user_id uuid, clip_id uuid, created_at timestamptz default now());
create table public.post_comments(id uuid primary key default gen_random_uuid(), user_id uuid, created_at timestamptz default now());
create table public.clip_comments(id uuid primary key default gen_random_uuid(), user_id uuid, created_at timestamptz default now());
create table public.friend_requests(id uuid primary key default gen_random_uuid(), sender_id uuid, receiver_id uuid, status text);
create table public.user_blocks(blocker_id uuid, blocked_id uuid);
create table public.follows(follower_id uuid, following_id uuid);
create table public.saved_posts(user_id uuid, post_id uuid);
create table public.book_listings(id uuid primary key default gen_random_uuid(), owner_id uuid, status text);
`);
await db.exec(fs.readFileSync(new URL('../supabase/migrations/20261017170001_172_profile_stats.sql', import.meta.url), 'utf8'));

let checks = 0;
const ok = (c, m) => { assert.ok(c, m); checks++; };

const p1 = (await db.query(`insert into public.posts(user_id) values($1) returning id`, [ME])).rows[0].id;
await db.query(`insert into public.posts(user_id) values($1)`, [ME]);
await db.query(`insert into public.posts(user_id,is_hidden) values($1,true)`, [ME]); // hidden: not counted
await db.query(`insert into public.posts(user_id,upload_state156) values($1,'pending')`, [ME]); // uploading: not counted
const c1 = (await db.query(`insert into public.clips(user_id,views_count) values($1,40) returning id`, [ME])).rows[0].id;
await db.query(`insert into public.clips(user_id,views_count,is_hidden) values($1,999,true)`, [ME]);
await db.query(`insert into public.social_stories(user_id) values($1),($1)`, [ME]);
await db.query(`insert into public.likes(user_id,post_id) values($1,$2),($3,$2)`, [F1, p1, F2]);
await db.query(`insert into public.clip_likes(user_id,clip_id) values($1,$2)`, [F1, c1]);
await db.query(`insert into public.post_comments(user_id) values($1),($1)`, [ME]);
await db.query(`insert into public.clip_comments(user_id) values($1)`, [ME]);
await db.query(`insert into public.post_comments(user_id) values($1)`, [F1]); // someone else's
await db.query(`insert into public.friend_requests(sender_id,receiver_id,status) values($1,$2,'accepted'),($3,$1,'accepted'),($1,$4,'accepted'),($1,$5,'pending'),($1,$2,'accepted')`, [ME, F1, F2, F3, PEND]);
await db.query(`insert into public.user_blocks values($1,$2)`, [ME, F3]);
await db.query(`insert into public.follows values($1,$2),($3,$2),($2,$4)`, [F1, ME, FOL, F1]);
await db.query(`insert into public.saved_posts values($1,$2)`, [ME, p1]);
await db.query(`insert into public.book_listings(owner_id,status) values($1,'available'),($1,'withdrawn'),($1,'reserved')`, [ME]);

await db.exec(`grant usage on schema public, auth to authenticated; grant select on all tables in schema public to authenticated; grant execute on all functions in schema public to authenticated;`);
await db.exec(`set test.uid = '${ME}'`);
await db.exec('set role authenticated');
const stats = (await db.query(`select public.get_my_activity_stats() s`)).rows[0].s;
ok(stats.posts === 2, 'hidden and uploading posts are not counted');
ok(stats.clips === 1, 'hidden clip is not counted');
ok(stats.stories === 2, 'stories counted');
ok(stats.likes === 3, 'likes received on posts and clips');
ok(stats.comments === 3, 'own comments on posts and clips only');
ok(stats.friends === 2, `colleagues = accepted requests, once each, blocked excluded (got ${stats.friends})`);
ok(stats.followers === 2 && stats.following === 1, 'followers/following');
ok(stats.saved_posts === 1, 'saved posts');
ok(stats.saved_books === 2, 'withdrawn book listing not counted');
ok(Number(stats.clip_views) === 40, 'views only from visible clips');
ok(stats.active_days === 1, 'all activity today is one active day');

const weekly = (await db.query(`select * from public.get_my_weekly_activity()`)).rows;
ok(weekly.length === 7, 'seven days returned');
const today = weekly[weekly.length - 1];
// 4 posts + 2 clips + 2 stories + 2 post comments + 1 clip comment = 11 created by me today
ok(Number(today.activity_count) === 11, `weekly chart counts clips/stories/comments (got ${today.activity_count})`);

await db.exec(`set test.uid = '${FOL}'`);
const other = (await db.query(`select public.get_my_activity_stats() s`)).rows[0].s;
ok(other.posts === 0 && other.friends === 0 && other.followers === 0, 'another user sees only their own numbers');

console.log(`profile stats 172: ${checks} checks passed`);
