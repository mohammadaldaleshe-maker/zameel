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
create table public.push_notification_queue(id uuid primary key default gen_random_uuid(), notification_id uuid not null, status text not null default 'pending', attempts int not null default 0, created_at timestamptz not null default now());`);
await db.exec(fs.readFileSync(new URL('../supabase/migrations/20261017140002_169_push_dispatch_targeted.sql', import.meta.url), 'utf8'));
// the migration only replaces the function; attach the trigger the same way production has it
await db.exec(`create trigger zameel_push_notifications after insert on public.push_notification_queue for each row execute function public.zameel_dispatch_queued_push();`);

let checks = 0;
const ok = (c, m) => { assert.ok(c, m); checks++; };
const n1 = '30000000-0000-4000-8000-000000000001', n2 = '30000000-0000-4000-8000-000000000002';

await db.query(`insert into public.push_notification_queue(notification_id) values($1)`, [n1]);
let calls = (await db.query('select * from net.calls')).rows;
ok(calls.length === 1, 'one worker call per queued notification');
ok(calls[0].body.notification_id === n1, 'the worker is asked for exactly that notification');
ok(calls[0].headers['x-zameel-push-secret'] === 'unit-test-secret', 'secret comes from Vault, not from the migration');
ok(!fs.readFileSync(new URL('../supabase/migrations/20261017140002_169_push_dispatch_targeted.sql', import.meta.url), 'utf8').includes('unit-test-secret'), 'no secret in source');
ok(calls[0].url.endsWith('/functions/v1/send-push-notifications'), 'same worker URL as before');

// retry sweep: nothing waiting -> no call
await db.exec(`update public.push_notification_queue set status='sent'; delete from net.calls`);
let waiting = (await db.query('select public.zameel_push_retry_169() as n')).rows[0].n;
ok(waiting === 0 && (await db.query('select * from net.calls')).rows.length === 0, 'sweep does nothing when the queue is clean');
// waiting failed row with attempts<5 -> one empty-body call
await db.query(`insert into public.push_notification_queue(notification_id,status,attempts) values($1,'failed',2)`, [n2]);
await db.exec('delete from net.calls');
waiting = (await db.query('select public.zameel_push_retry_169() as n')).rows[0].n;
calls = (await db.query('select * from net.calls')).rows;
ok(waiting === 1 && calls.length === 1 && Object.keys(calls[0].body).length === 0, 'sweep posts one empty-body call when a retry is waiting');
// exhausted rows are not swept
await db.exec(`update public.push_notification_queue set attempts=5; delete from net.calls`);
waiting = (await db.query('select public.zameel_push_retry_169() as n')).rows[0].n;
ok(waiting === 0, 'rows with 5 attempts are not retried');
// missing secret: trigger must not break inserts
await db.exec(`delete from vault.decrypted_secrets; delete from net.calls`);
await db.query(`insert into public.push_notification_queue(notification_id) values('30000000-0000-4000-8000-000000000003')`);
ok((await db.query('select count(*)::int c from public.push_notification_queue')).rows[0].c >= 3, 'insert still succeeds when the secret is missing');
// grants
const g = (await db.query(`select has_function_privilege('anon','public.zameel_push_retry_169()','execute') a, has_function_privilege('authenticated','public.zameel_push_retry_169()','execute') b`)).rows[0];
ok(!g.a && !g.b, 'sweep is not callable by clients');
// worker contract: fresh rows first
const worker = fs.readFileSync(new URL('../supabase/functions/send-push-notifications/index.ts', import.meta.url), 'utf8');
ok(worker.indexOf('.order("attempts", { ascending: true })') > 0 && worker.indexOf('.order("attempts"') < worker.indexOf('.order("created_at"'), 'worker handles never-tried rows before old retries');
ok(worker.includes('accessTokenFor(serviceAccount)'), 'worker reuses the Google access token');
console.log(`PASS: push dispatch 169 (${checks} checks): targeted dispatch, Vault secret, retry sweep, client denial, fresh-first worker order.`);
