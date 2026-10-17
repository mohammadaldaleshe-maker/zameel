import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { secretsEqual } from '../../supabase/functions/_shared/secure_compare.mjs';

test('equal secrets are accepted', async () => {
  assert.equal(await secretsEqual('worker-secret-123', 'worker-secret-123'), true);
  assert.equal(await secretsEqual('سر-عربي-١٢٣', 'سر-عربي-١٢٣'), true);
});

test('different, truncated, extended and case-changed secrets are rejected', async () => {
  assert.equal(await secretsEqual('worker-secret-124', 'worker-secret-123'), false);
  assert.equal(await secretsEqual('worker-secret-12', 'worker-secret-123'), false);
  assert.equal(await secretsEqual('worker-secret-1234', 'worker-secret-123'), false);
  assert.equal(await secretsEqual('WORKER-SECRET-123', 'worker-secret-123'), false);
});

test('missing or empty values never authorise a request', async () => {
  assert.equal(await secretsEqual(null, 'secret'), false);
  assert.equal(await secretsEqual(undefined, 'secret'), false);
  assert.equal(await secretsEqual('', 'secret'), false);
  assert.equal(await secretsEqual('secret', ''), false);
  assert.equal(await secretsEqual('', ''), false);
  assert.equal(await secretsEqual(null, null), false);
  assert.equal(await secretsEqual(123, 123), false);
});

test('webhook functions use the constant-time helper and keep their empty-secret guard', async () => {
  const push = await readFile(new URL('../../supabase/functions/send-push-notifications/index.ts', import.meta.url), 'utf8');
  const daily = await readFile(new URL('../../supabase/functions/daily-social-maintenance/index.ts', import.meta.url), 'utf8');
  for (const source of [push, daily]) {
    assert.match(source, /secretsEqual\(/);
    assert.match(source, /_shared\/secure_compare\.mjs/);
    assert.match(source, /!expected(Secret)?\s*\|\|/);
    assert.doesNotMatch(source, /!==\s*expected(Secret)?\b/);
  }
});

test('the Gemini key is sent in a header, never in the request URL', async () => {
  const ai = await readFile(new URL('../../supabase/functions/zameel-ai/index.ts', import.meta.url), 'utf8');
  assert.match(ai, /"x-goog-api-key":\s*geminiKey/);
  assert.doesNotMatch(ai, /generateContent\?key=/);
});
