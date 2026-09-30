import test from 'node:test';
import assert from 'node:assert/strict';
import { processDeletion } from '../../supabase/functions/account-deletion/worker.mjs';
function fixture(files = []) {
 const calls = []; let stored = [...files];
 const job = {id:'job-a',user_id:'user-a',data_removed:false};
 const io = {
  ban: async id => calls.push(['ban',id]),
  discover: async j => calls.push(['discover',j.id]),
  removeData: async j => calls.push(['data',j.id]),
  files: async (id,limit) => stored.slice(0,limit),
  removeStorage: async (bucket,names) => calls.push(['storage',bucket,...names]),
  ackFiles: async (id,bucket,names) => { calls.push(['ack',id]); stored=stored.filter(f=>f.bucket_id!==bucket||!names.includes(f.name)); },
  deleteAuth: async id=>calls.push(['auth',id]),
  finish: async j=>calls.push(['finish',j.id]),
 };
 return {calls,job,io,remaining:()=>stored};
}
test('cleanup is ordered; only the claimed account is passed to auth', async()=>{
 const f=fixture([{bucket_id:'posts',name:'user-a/a.jpg'}]);
 assert.equal(await processDeletion(f.job,f.io),'completed');
 const names=f.calls.map(c=>c[0]);
 assert.ok(names.indexOf('ban')<names.indexOf('data'));
 assert.ok(names.indexOf('data')<names.indexOf('storage'));
 assert.ok(names.indexOf('ack')<names.indexOf('auth'));
 assert.deepEqual(f.calls.find(c=>c[0]==='auth'),['auth','user-a']);
 assert.equal(names.at(-1),'finish');
});
test('database failure leaves storage and auth intact',async()=>{
 const f=fixture([{bucket_id:'posts',name:'a'}]);
 f.io.removeData=async()=>{throw Error('db');};
 await assert.rejects(processDeletion(f.job,f.io));
 assert.ok(!f.calls.some(c=>['storage','auth','finish'].includes(c[0])));
});
test('storage failure retains the retry manifest and never deletes auth',async()=>{
 const f=fixture([{bucket_id:'posts',name:'a'}]);
 f.io.removeStorage=async()=>{throw Error('storage');};
 await assert.rejects(processDeletion(f.job,f.io));
 assert.equal(f.remaining().length,1);
 assert.ok(!f.calls.some(c=>['auth','finish','ack'].includes(c[0])));
});
test('auth failure cannot mark a job complete',async()=>{
 const f=fixture();f.io.deleteAuth=async()=>{throw Error('auth');};
 await assert.rejects(processDeletion(f.job,f.io));
 assert.ok(!f.calls.some(c=>c[0]==='finish'));
});
test('large account yields and can resume without replaying data deletion',async()=>{
 const files=Array.from({length:230},(_,i)=>({bucket_id:'posts',name:`a${i}`}));
 const f=fixture(files);
 assert.equal(await processDeletion(f.job,f.io,1),'pending');
 assert.equal(f.remaining().length,130);
 f.job.data_removed=true;
 assert.equal(await processDeletion(f.job,f.io),'completed');
 assert.equal(f.calls.filter(c=>c[0]==='data').length,1);
});
test('malformed file manifest is not acknowledged',async()=>{
 const f=fixture([{bucket_id:'posts',name:''}]);
 await assert.rejects(processDeletion(f.job,f.io),/invalid_file_manifest/);
 assert.ok(!f.calls.some(c=>c[0]==='ack'));
});
test('upload discovered before auth removal receives another cleanup pass',async()=>{
 const f=fixture();let checks=0;let pending=false;
 f.io.discover=async()=>{checks++;if(checks===2)pending=true;};
 f.io.files=async()=>pending?[{bucket_id:'posts',name:'late.jpg'}]:[];
 f.io.ackFiles=async()=>{pending=false;};
 assert.equal(await processDeletion(f.job,f.io),'completed');
 assert.ok(f.calls.some(c=>c[0]==='storage'&&c[2]==='late.jpg'));
});
