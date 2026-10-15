import assert from 'node:assert/strict';import {incomingCallData} from '../supabase/functions/send-push-notifications/call_push.mjs';
const now=Date.now(),session={created_at:new Date(now-1000).toISOString(),status:'ringing',callee_id:'recipient',caller_id:'caller',room_id:'room'},notification={user_id:'recipient',data:{room_id:'room'}};
const image='https://jwuqyykjmltroneqtjoc.supabase.co/storage/v1/object/public/profiles/photo.jpg';
assert.equal(incomingCallData(session,notification,'Caller',now,image).caller_image,image);
for(const value of ['http://example.test/face.jpg','data:image/png;base64,AAAA','https://evil.test/face.jpg','https://supabase.co.evil.test/storage/v1/object/face.jpg','https://x.supabase.co/not-storage'])assert.equal(incomingCallData(session,notification,'Caller',now,value).caller_image,undefined);
assert.equal(incomingCallData({...session,status:'ended'},notification,'Caller',now,image),null);
console.log('PASS: caller avatar comes only from bounded HTTPS storage URL; invalid images do not suppress valid calls and ended calls never ring.');
