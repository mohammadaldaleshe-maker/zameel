import test from 'node:test';
import assert from 'node:assert/strict';
import { incomingCallData, isNativeCallDevice, callEndRecipients } from '../supabase/functions/send-push-notifications/call_push.mjs';
const now = Date.parse('2026-10-06T00:00:00Z');
const session = {room_id:'room', status:'ringing', caller_id:'caller', callee_id:'callee', created_at:new Date(now-2000).toISOString()};
const notification = {user_id:'callee',data:{room_id:'room'}};
test('live invitation derives caller, recipient and absolute expiry from session', () => {
 const data = incomingCallData(session,notification,'محمد',now);
 assert.equal(data.caller_id,'caller'); assert.equal(data.recipient_id,'callee');
 assert.equal(Number(data.expires_at_ms),now+43000);
});
test('cancelled, stale, future, wrong-room and wrong-recipient invitations cannot ring', () => {
 for (const patch of [{status:'ended'},{status:'active'},{created_at:new Date(now-45000).toISOString()},
 {created_at:new Date(now+1).toISOString()},{room_id:'other'},{callee_id:'another'}]) {
   assert.equal(incomingCallData({...session,...patch},notification,'name',now),null);
 }
});
test('older clients keep standard call notifications; native data only explicitly supported', () => {
 assert.equal(isNativeCallDevice('android'),false);
 assert.equal(isNativeCallDevice('ios'),false);
 assert.equal(isNativeCallDevice('android_call_v3'),true);
});
test('stop recipients come only from a non-ringing authoritative session', () => {
 assert.deepEqual(callEndRecipients(session),[]);
 assert.deepEqual(callEndRecipients({...session,status:'declined'}),['caller','callee']);
 assert.deepEqual(callEndRecipients(null),[]);
});

test('call invitation expires at 45 seconds, not one millisecond earlier', () => {
 assert.ok(incomingCallData({...session,created_at:new Date(now-44999).toISOString()},notification,'name',now));
 assert.equal(incomingCallData({...session,created_at:new Date(now-45000).toISOString()},notification,'name',now),null);
});
