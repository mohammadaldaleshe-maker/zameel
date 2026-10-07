import {test} from 'node:test';import assert from 'node:assert/strict';import {build} from 'esbuild';import {readFile} from 'node:fs/promises';import {fileURLToPath} from 'node:url';
test('actual HTTP handler rejects disabled service, invalid sessions, forged worker calls and oversized requests before mutations',async()=>{
 const entry=new URL('../../supabase/functions/play-billing/index.ts',import.meta.url);
 const source=(await readFile(entry,'utf8')).replace("import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';","const createClient=globalThis.billingFixtureClient;");
 let handler;let databaseCalls=0;const values={GOOGLE_PLAY_BILLING_ENABLED:'true',ZAMEEL_BILLING_WORKER_SECRET:'fixture-private-secret'};
 const oldDeno=globalThis.Deno;globalThis.Deno={env:{get:k=>values[k]},serve:fn=>{handler=fn;}};
 globalThis.billingFixtureClient=()=>({auth:{getUser:async()=>({error:{message:'invalid'},data:{user:null}})},from:()=>{databaseCalls++;throw Error('unexpected_db');},rpc:()=>{databaseCalls++;throw Error('unexpected_mutation');}});
 try{const compiled=await build({stdin:{contents:source,loader:'ts',resolveDir:fileURLToPath(new URL('../../supabase/functions/play-billing/',import.meta.url))},bundle:true,format:'esm',platform:'neutral',write:false});await import('data:text/javascript;base64,'+Buffer.from(compiled.outputFiles[0].text).toString('base64'));
 const request=(body,headers={})=>new Request('https://fixture.invalid',{method:'POST',headers,body:JSON.stringify(body)});
 assert.equal((await handler(request({action:'verify'}))).status,401);
 assert.equal((await handler(request({action:'create',kind:'verification'},{Authorization:'Bearer forged'}))).status,401);
 assert.equal((await handler(request({action:'reconcile'},{'x-zameel-billing-secret':'wrong'}))).status,401);
 assert.equal((await handler(new Request('https://fixture.invalid',{method:'GET'}))).status,405);
 assert.equal((await handler(request({action:'verify',data:'x'.repeat(17000)}))).status,413);
 values.GOOGLE_PLAY_BILLING_ENABLED='false';assert.equal((await handler(request({action:'create'}))).status,503);
 assert.equal(databaseCalls,0);
 }finally{globalThis.Deno=oldDeno;delete globalThis.billingFixtureClient;}
});
