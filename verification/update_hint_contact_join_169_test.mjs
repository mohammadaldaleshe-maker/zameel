import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
const id = n => `10000000-0000-4000-8000-00000000000${n}`;
const [a, b, c, d] = [id(1), id(2), id(3), id(4)];
const h = ch => ch.repeat(64);          // fake 64-char hex hash
const hNew = h('a'), hOther = h('b');

await db.exec(`create role anon; create role authenticated; create role service_role; create schema auth;
create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
create table public.users(id uuid primary key, name text, phone text, phone_hash text);
create table public.user_blocks(blocker_id uuid, blocked_id uuid);
create table public.notifications(id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users(id) on delete cascade,
  actor_id uuid references public.users(id) on delete set null, type text not null, title_ar text not null default '', title_en text not null default '',
  body_ar text not null default '', body_en text not null default '', data jsonb not null default '{}'::jsonb, is_read boolean not null default false, created_at timestamptz not null default now());
create table public.app_releases(id uuid primary key default gen_random_uuid(), platform text, version_name text, build_number int, is_allowed boolean default true,
  is_active boolean default true, download_url text default '', created_at timestamptz default now());
insert into public.users(id,name) values('${a}','أنا'),('${b}','صديق'),('${c}','ثالث'),('${d}','غريب');
grant usage on schema public, auth to authenticated, anon;
grant select on all tables in schema public to authenticated;`);
await db.exec(fs.readFileSync(new URL('../supabase/migrations/20261017150001_169_update_hint_contact_join.sql', import.meta.url), 'utf8'));
// Applying the migration twice must be harmless.
await db.exec(fs.readFileSync(new URL('../supabase/migrations/20261017150001_169_update_hint_contact_join.sql', import.meta.url), 'utf8'));

let checks = 0;
const ok = (cond, msg) => { assert.ok(cond, msg); checks++; };
const as = async (uid, sql, params) => { await db.exec(`set role authenticated; set test.uid='${uid}'`); try { return await db.query(sql, params); } finally { await db.exec('reset role'); } };
const fails = async (uid, sql, params, re) => { try { await as(uid, sql, params); } catch (e) { return re.test(String(e.message)); } return false; };

// ---- (a) release policy
await db.exec(`insert into public.app_releases(platform,version_name,build_number,download_url) values
 ('android','2.0.25',34,'https://play.google.com/x'),('android','2.0.26',35,'https://play.google.com/y')`);
let pol = (await db.query(`select public.zameel_release_policy('android',34) as p`)).rows[0].p;
ok(pol.latest_build === 35 && pol.version_name === '2.0.26', 'policy reports the newest approved build');
ok(pol.allowed === true, 'an older allowed build is still allowed (soft update only)');
await db.exec(`update public.app_releases set is_allowed=false where build_number=34`);
pol = (await db.query(`select public.zameel_release_policy('android',34) as p`)).rows[0].p;
ok(pol.allowed === false && pol.latest_build === 35, 'a stopped build is still blocked and reports the update');
pol = (await db.query(`select public.zameel_release_policy('android',35) as p`)).rows[0].p;
ok(pol.allowed === true && pol.latest_build === 35, 'the newest build is allowed');
let denied = false;
try { await db.exec(`set role anon`); await db.query(`select public.zameel_release_policy('android',35)`); } catch (e) { denied = true; } finally { await db.exec('reset role'); }
ok(!denied, 'release policy stays callable before login');

// ---- (b) contact hashes sync
ok(await fails('', `select public.zameel_sync_contact_hashes165($1)`, [[hNew]], /authentication_required/), 'sync needs a signed-in user');
let saved = (await as(a, `select public.zameel_sync_contact_hashes165($1) as n`, [[hNew, hNew, 'nothex', 'abc', hOther]])).rows[0].n;
ok(saved === 2, 'duplicates and malformed hashes are discarded');
saved = (await as(a, `select public.zameel_sync_contact_hashes165($1) as n`, [[hNew]])).rows[0].n;
ok(saved === 1, 'a new sync replaces the previous list');
let blocked = false;
try { await db.exec('set role authenticated'); await db.query('select * from public.user_contact_hashes165'); } catch (e) { blocked = /permission denied/i.test(String(e.message)); } finally { await db.exec('reset role'); }
ok(blocked, 'nobody can read the stored hashes directly');
await as(b, `select public.zameel_sync_contact_hashes165($1)`, [[hNew]]);
await as(c, `select public.zameel_sync_contact_hashes165($1)`, [[hNew]]);
await as(d, `select public.zameel_sync_contact_hashes165($1)`, [[hOther]]);

// ---- (c) the notification
const newcomer = id(9);
await db.exec(`insert into public.users(id,name) values('${newcomer}','محمد الجديد')`);
let n = (await db.query(`select count(*)::int c from public.notifications where type='contact_joined'`)).rows[0].c;
ok(n === 0, 'no notification while the new user has no phone hash');
await db.exec(`insert into public.user_blocks values('${c}','${newcomer}')`);   // c blocked the newcomer
await db.exec(`update public.users set phone_hash='${hNew}' where id='${newcomer}'`);
const rows = (await db.query(`select user_id,actor_id,title_ar,body_ar,data from public.notifications where type='contact_joined' order by user_id`)).rows;
const targets = rows.map(r => r.user_id).sort();
ok(targets.join() === [a, b].sort().join(), 'holders of the number are notified; the blocker and strangers are not');
ok(rows[0].actor_id === newcomer && rows[0].data.joined_user_id === newcomer, 'notification points at the new user');
ok(rows[0].body_ar.includes('محمد الجديد') && rows[0].body_ar.includes('أضفه زميلاً لك'), 'Arabic text names the user and invites to add them');
await db.exec(`update public.users set phone_hash='${hOther}' where id='${newcomer}'`);
await db.exec(`update public.users set phone_hash='${hNew}' where id='${newcomer}'`);
n = (await db.query(`select count(*)::int c from public.notifications where type='contact_joined'`)).rows[0].c;
ok(n === 2, 'changing the number later does not notify again');

// opt-out and no self notification
const hidden = id(8);
await db.exec(`insert into public.users(id,name) values('${hidden}','مخفي')`);
await as(hidden, `select public.zameel_set_contact_join_visible165(false)`);
ok((await as(hidden, `select public.zameel_get_contact_join_visible165() as v`)).rows[0].v === false, 'opt-out is stored');
await as(hidden, `select public.zameel_sync_contact_hashes165($1)`, [[h('c')]]);
await db.exec(`update public.users set phone_hash='${h('c')}' where id='${hidden}'`);
n = (await db.query(`select count(*)::int c from public.notifications where (data->>'joined_user_id')='${hidden}'`)).rows[0].c;
ok(n === 0, 'a user who opted out is not announced, and never notifies himself');
await as(hidden, `select public.zameel_set_contact_join_visible165(true)`);
ok((await as(hidden, `select public.zameel_get_contact_join_visible165() as v`)).rows[0].v === true, 'opt-in again works');

// ---- security
const meta = (await db.query(`select proname,prosecdef,proconfig from pg_proc where proname like '%165' and proname like 'zameel_%'`)).rows;
ok(meta.length >= 4 && meta.every(r => r.prosecdef && String(r.proconfig).includes('search_path=')), 'all new functions are security definer with a pinned search_path');
let anonDenied = false;
try { await db.exec('set role anon'); await db.query(`select public.zameel_sync_contact_hashes165($1)`, [[hNew]]); } catch (e) { anonDenied = /permission denied/i.test(String(e.message)); } finally { await db.exec('reset role'); }
ok(anonDenied, 'anon cannot sync contact hashes');

// ---- Dart wiring
const gate = fs.readFileSync(new URL('../lib/services/app_release_gate.dart', import.meta.url), 'utf8');
ok(gate.includes("latest_build") && gate.includes('_updateBanner') && gate.includes('_hintDismissed'), 'release gate shows the soft update banner');
const prompt = fs.readFileSync(new URL('../lib/services/app_permissions_prompt.dart', import.meta.url), 'utf8');
ok(prompt.includes('maybeAsk') && prompt.includes('requestPermission') && prompt.includes('hasPermission'), 'permission prompt requests location, contacts and microphone');
const home = fs.readFileSync(new URL('../lib/features/home_feed.dart', import.meta.url), 'utf8');
ok(home.includes('AppPermissionsPrompt.maybeAsk') && home.includes('ContactJoinSync165.sync'), 'home screen triggers the prompt and the contact sync');

console.log(`PASS: update hint + contact joined 169 (${checks} checks).`);
