import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {transformSync}=require('esbuild');
import {incomingCallData,isNativeCallDevice,callEndRecipients} from '../supabase/functions/send-push-notifications/call_push.mjs';
const original=fs.readFileSync(new URL('../supabase/functions/send-push-notifications/index.ts',import.meta.url),'utf8');
const source=transformSync(original.replace(/^import .*;\r?\n/gm,''),{loader:'ts',format:'cjs'}).code;
async function run({type='message',suppress=false,visibilityError=null,secret='expected'}={}) {
 let handler;const deliveries=[],outgoing=[],rpcCalls=[],queueUpdates=[];
 const notification={id:'notice',user_id:'recipient',actor_id:'sender',type,title_en:'Title',body_en:'Body',data:{conversation_id:'chat',message_id:'message'}};
 const database={rpc:async(name,args)=>{rpcCalls.push({name,args});return {data:suppress,error:visibilityError};},from(table){
   let op='read',payload=null,selected='',filters={};
   const q={select(s){selected=s;return q;},update(p){op='update';payload=p;return q;},upsert(p){op='upsert';payload=p;return q;},delete(){op='delete';return q;},eq(k,v){filters[k]=v;return q;},lt(){return q;},in(){return q;},order(){return q;},limit(){return q;},maybeSingle(){return Promise.resolve(result(true));},then(resolve,reject){return Promise.resolve(result(false)).then(resolve,reject);}};
   function result(single){
     if(op!=='read'){
       if(table==='push_notification_deliveries')deliveries.push(payload);
       if(table==='push_notification_queue')queueUpdates.push(payload);
       return {data:selected==='id'?{id:'queue'}:null,error:null};
     }
     if(table==='push_notification_queue')return {data:[{id:'queue',notification_id:'notice',attempts:0}],error:null};
     if(table==='notifications')return {data:notification,error:null};
     if(table==='users')return {data:filters.id==='sender'?{name:'Sender',profile_image:''}:{notifications_enabled:true,notification_sounds_enabled:true},error:null};
     if(table==='push_device_tokens')return {data:[{id:'device',token:'token',locale:'en',platform:'android_call_v3_alert151'}],error:null};
     if(table==='messages')return {data:{content:'Message preview',media_type:null},error:null};
     if(table==='feature_flags')return {data:{enabled:false},error:null};
     return {data:single?null:[],error:null};
   }
   return q;
 }};
 const context=vm.createContext({Deno:{env:{get(name){return name==='FCM_SERVICE_ACCOUNT_JSON'?JSON.stringify({project_id:'test'}):name==='ZAMEEL_PUSH_WEBHOOK_SECRET'?'expected':'test';}},serve(f){handler=f;}},createClient:()=>database,incomingCallData,isNativeCallDevice,callEndRecipients,Response,Request,Date,JSON,console,TextEncoder,URLSearchParams,btoa,atob,
   fetch:async(url,opts)=>{outgoing.push(JSON.parse(opts.body));return new Response('{}',{status:200});}});
 vm.runInContext(source+'\ngetAccessToken = async () => "test-token";',context);
 const response=await handler(new Request('https://worker.test',{method:'POST',headers:{'x-zameel-push-secret':secret,'content-type':'application/json'},body:'{}'}));
 return {status:response.status,result:await response.json(),outgoing,deliveries,rpcCalls,queueUpdates};
}
let r=await run({suppress:true});assert.equal(r.status,200);assert.equal(r.outgoing.length,0);assert.equal(r.deliveries[0].last_error,'conversation_visible');assert.equal(r.queueUpdates.at(-1).status,'sent');
r=await run();assert.equal(r.status,200);assert.equal(r.outgoing.length,1);assert.equal(r.outgoing[0].message.data.type,'message');assert.equal(r.rpcCalls[0].name,'zameel_chat_should_suppress_push_153');
r=await run({type:'post_like',suppress:true});assert.equal(r.outgoing.length,1);assert.equal(r.rpcCalls.length,0);
r=await run({visibilityError:{message:'database_unavailable'}});assert.equal(r.status,500);assert.equal(r.outgoing.length,0);assert.notEqual(r.queueUpdates.at(-1).status,'sent');
r=await run({secret:'wrong'});assert.equal(r.status,401);assert.equal(r.rpcCalls.length,0);assert.equal(r.outgoing.length,0);
console.log('PASS: actual push HTTP worker suppresses visible chat, delivers inactive chat, preserves likes, rejects unauthorized invocation, and exposes/retries RPC failure rather than dropping messages.');
