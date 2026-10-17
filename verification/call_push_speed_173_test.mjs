import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
await db.exec(`create role anon; create role authenticated; create role service_role;
create schema vault; create table vault.decrypted_secrets(name text, decrypted_secret text);
insert into vault.decrypted_secrets values('zameel_push_webhook_secret','unit-test-secret');
create schema net; create table net.calls(url text, headers jsonb, body jsonb);
create function net.http_post(url text, headers jsonb default '{}', body jsonb default '{}', timeout_milliseconds int default 1000) returns bigint
 language plpgsql as $$ begin insert into net.calls values(url,headers,body); return 1; end $$;
create table public.notifications(id uuid primary key default gen_random_uuid(), type text not null);
create table public.push_notification_queue(id uuid primary key default gen_random_uuid(), notification_id uuid not null, status text not null default 'pending', attempts int not null default 0, last_error text, processed_at timestamptz, created_at timestamptz not null default now());`);
const read = f => fs.readFileSync(new URL(`../supabase/migrations/${f}`, import.meta.url), 'utf8');
await db.exec(read('20261017140002_169_push_dispatch_targeted.sql'));
const m173 = read('20261017180001_173_call_push_speed.sql');
await db.exec(m173);
await db.exec(m173); // safe to run twice
await db.exec(`create trigger zameel_push_notifications after insert on public.push_notification_queue for each row execute function public.zameel_dispatch_queued_push();`);

let checks = 0;
const ok = (c, m) => { assert.ok(c, m); checks++; };

const ids = {};
for (const t of ['incoming_voice_call', 'incoming_video_call', 'message']) {
  ids[t] = (await db.query(`insert into public.notifications(type) values($1) returning id`, [t])).rows[0].id;
}
await db.query(`insert into public.push_notification_queue(notification_id) values($1)`, [ids.incoming_voice_call]);
await db.query(`insert into public.push_notification_queue(notification_id) values($1)`, [ids.incoming_video_call]);
ok((await db.query('select count(*)::int c from net.calls')).rows[0].c === 0, 'call invitations do not trigger a second general dispatch');
await db.query(`insert into public.push_notification_queue(notification_id) values($1)`, [ids.message]);
const calls = (await db.query('select * from net.calls')).rows;
ok(calls.length === 1 && calls[0].body.notification_id === ids.message, 'chat messages are still dispatched immediately');
ok(calls[0].headers['x-zameel-push-secret'] === 'unit-test-secret', 'secret still comes from Vault');
ok(!m173.includes('unit-test-secret'), 'no secret in the migration');

// stuck rows are released, fresh processing rows are untouched
await db.exec(`delete from public.push_notification_queue;
 insert into public.push_notification_queue(notification_id,status,created_at) values('00000000-0000-4000-8000-000000000001','processing', now() - interval '10 minutes');
 insert into public.push_notification_queue(notification_id,status,created_at) values('00000000-0000-4000-8000-000000000002','processing', now());`);
await db.exec(m173.slice(m173.indexOf('-- Release pushes')));
const rows = (await db.query(`select notification_id, status from public.push_notification_queue order by notification_id`)).rows;
ok(rows[0].status === 'failed', 'a push stuck in processing is released');
ok(rows[1].status === 'processing', 'a push being sent right now is left alone');

ok((await db.query(`select 1 from information_schema.columns where table_name='push_notification_queue' and column_name='processing_started_at'`)).rows.length === 1, 'the processing-time column is installed even if migration 069 was never applied');
// worker source: caller fast path, parallel devices, timeout, no stuck rows
const worker = fs.readFileSync(new URL('../supabase/functions/send-push-notifications/index.ts', import.meta.url), 'utf8');
ok(worker.includes('call_room') && worker.includes('auth.getUser(bearer)'), 'caller fast path is verified by the caller login token');
ok(worker.includes('Promise.all((tokens ?? []).map(async (device)'), 'devices are pushed in parallel');
ok(worker.includes('AbortSignal.timeout(8000)'), 'FCM call has a time limit');
ok(worker.includes('2 * 60 * 1000'), 'stale processing limit is two minutes');
ok(worker.includes('firstItemError'), 'item errors release the row and are still reported');
// app wiring
const src = f => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8');
ok(src('lib/screens/chat/chat_screen.dart').includes('CallPushFastPath.ring(roomId)'), 'caller app asks for the push right after the call row exists');
ok(src('lib/services/call_push_fastpath.dart').includes("'call_room'"), 'fast path sends the call room only');
ok(src('lib/main.dart').includes("data['action']?.toString() == 'accept' && quickCallerId.isNotEmpty"), 'Answer goes straight into the call');
ok(src('lib/main.dart').includes('await NativeIncomingCallService.finishDecline();\n        return;\n      }\n      if (!await FeatureControl.instance.check'), 'app closes itself after a call answered on the lock screen');
const kt = src('android/app/src/main/kotlin/com/zameel/app/ZameelIncomingCall.kt');
ok(kt.includes('action == "accept" && isVideo'), 'only video asks to unlock; voice is answered over the lock screen');
ok(src('android/app/src/main/kotlin/com/zameel/app/MainActivity.kt').includes('in listOf("decline", "accept")'), 'answered call shows over the lock screen');
ok(src('lib/services/app_permissions_prompt.dart').includes('maybeAskFullScreen') && src('lib/features/home_feed.dart').includes('maybeAskFullScreen'), 'full-screen call permission is requested from the home screen');
console.log(`PASS: call push speed 173 (${checks} checks)`);
