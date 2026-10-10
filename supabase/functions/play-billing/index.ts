import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { verifyWithGoogle } from './purchase_validation.mjs';
import { googleAccessToken, providerRequest, seal, unseal, sha256 } from './google_provider.mjs';
import { orderFinance } from './order_finance.mjs';
const env=(key:string)=>Deno.env.get(key)??'';
const db=createClient(env('SUPABASE_URL'),env('SUPABASE_SERVICE_ROLE_KEY'),{auth:{persistSession:false}});
const token=()=>googleAccessToken(env('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));
const key=()=>env('GOOGLE_PLAY_TOKEN_ENCRYPTION_KEY');
const result=(status:number,data:unknown)=>new Response(JSON.stringify(data),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
const ok=(data:Record<string,unknown>)=>result(200,{ok:true,...data});
const uuid=(s:unknown)=>typeof s==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
const requireData=(r:any)=>{if(r.error)throw Error('database_operation_failed');return r.data;};
function intentView(i:any){return {id:i.id,state:i.state,product_id:i.product_id,account_binding:i.account_binding,intent_binding:i.intent_binding};}
async function reconcile(receipt:any) {
 const access=await token();const raw=await unseal(receipt.token_cipher,key());
 const intent=receipt.intent_id?requireData(await db.from('zameel_play_payment_intents').select('*').eq('id',receipt.intent_id).maybeSingle()):null;
 const base='purchases/products/'+encodeURIComponent(receipt.product_id)+'/tokens/'+encodeURIComponent(raw);
 const purchase=await providerRequest(access,base);
 if(purchase.purchaseState===1 || purchase.refundableQuantity===0){requireData(await db.rpc('zameel_play_revoke',{p_token:receipt.token_sha256,p_state:'revoked'}));return;}
 if(purchase.purchaseState!==0 || ![0,1].includes(purchase.consumptionState) || (purchase.quantity??1)!==1)throw Error('payment_not_completed');
 if(purchase.productId && purchase.productId!==receipt.product_id)throw Error('provider_binding_mismatch');
 if(intent && (purchase.obfuscatedExternalAccountId!==intent.account_binding||purchase.obfuscatedExternalProfileId!==intent.intent_binding))throw Error('provider_binding_mismatch');
 const latest=requireData(await db.from('zameel_play_purchase_ledger').select('*').eq('token_sha256',receipt.token_sha256).single());
 const source=intent?requireData(await db.from(intent.kind==='verification'?'zameel_verification_requests':'zameel_post_promotions').select('status').eq('id',intent.request_id).maybeSingle()):null;
 if(latest.settlement_state==='refund_required' || !intent || !intent.user_id || !source || ['rejected','cancelled'].includes(source.status)) {
  if(!purchase.orderId)throw Error('refund_order_missing');
  await providerRequest(access,'orders/'+encodeURIComponent(purchase.orderId)+':refund?revoke=true',{method:'POST'});
  requireData(await db.rpc('zameel_play_revoke',{p_token:receipt.token_sha256,p_state:'refunded'}));return;
 }
 if(['refunded','revoked'].includes(latest.settlement_state))return;
 // Persist the paid pending-review entitlement before consuming. Consumption permits a later new purchase.
 if(purchase.consumptionState===0)await providerRequest(access,base+':consume',{method:'POST'});
 requireData(await db.from('zameel_play_purchase_ledger').update({acknowledgement_state:'completed',provider_checked_at:new Date().toISOString(),last_error:null}).eq('token_sha256',receipt.token_sha256));
 requireData(await db.rpc('zameel_play_activate',{p_token:receipt.token_sha256}));
 // Finance availability must never prevent granting a confirmed purchase.
 if(receipt.order_id && !receipt.is_test){try{const order=await providerRequest(access,'orders/'+encodeURIComponent(receipt.order_id));requireData(await db.from('zameel_play_finance').upsert(orderFinance(order,receipt)));}catch{console.warn('order_finance_pending');}}
}
Deno.serve(async(req:Request)=>{
 if(req.method!=='POST')return result(405,{ok:false,error:'method_not_allowed'});
 if(env('GOOGLE_PLAY_BILLING_ENABLED')!=='true')return result(503,{ok:false,error:'billing_not_enabled'});
 try {
  const text=await req.text();if(text.length>16000)return result(413,{ok:false,error:'request_too_large'});
  const body=JSON.parse(text);if(!body||typeof body!=='object'||Array.isArray(body))throw Error('invalid_request');
  if(body.action==='reconcile') {
   const supplied=req.headers.get('x-zameel-billing-secret')??'';const secret=env('ZAMEEL_BILLING_WORKER_SECRET');
   if(!secret||!supplied||await sha256(supplied)!==await sha256(secret))return result(401,{ok:false,error:'worker_not_authorized'});
   const urgent=requireData(await db.from('zameel_play_purchase_ledger').select('*').not('settlement_state','in','(refunded,revoked)').or('acknowledgement_state.eq.pending,settlement_state.eq.refund_required').order('provider_checked_at',{ascending:true}).limit(10));
   const routine=requireData(await db.from('zameel_play_purchase_ledger').select('*').eq('acknowledgement_state','completed').in('settlement_state',['approved','awaiting_review']).order('provider_checked_at',{ascending:true}).limit(10));
   const rows=[...new Map([...urgent,...routine].map(r=>[r.token_sha256,r])).values()];
   let processed=0,failed=0;
   let next=0;const deadline=Date.now()+30000;
   await Promise.all(Array.from({length:4},async()=>{while(next<rows.length && Date.now()<deadline){const row=rows[next++];try{await reconcile(row);processed++;}catch{failed++;await db.from('zameel_play_purchase_ledger').update({last_error:'provider_reconciliation_failed',provider_checked_at:new Date().toISOString()}).eq('token_sha256',row.token_sha256);}}}));
   return ok({processed,failed});
  }
  const authorization=req.headers.get('Authorization')??'';
  if(!authorization.startsWith('Bearer '))return result(401,{ok:false,error:'authentication_required'});
  const auth=await db.auth.getUser(authorization.slice(7));if(auth.error||!auth.data.user)return result(401,{ok:false,error:'authentication_required'});
  const uid=auth.data.user.id;
  const userDb=createClient(env('SUPABASE_URL'),env('SUPABASE_ANON_KEY'),{global:{headers:{Authorization:authorization}},auth:{persistSession:false}});
  if(body.action==='create') {
   let request;
   if(body.kind==='verification') request=requireData(await userDb.rpc('zameel_play_request_verification'));
   else if(body.kind==='promotion'){
    const p=body.params;if(!p||typeof p!=='object'||Array.isArray(p))throw Error('invalid_parameters');
    const keys=['p_post','p_days','p_audience','p_countrywide','p_cities','p_universities','p_min_age','p_max_age','p_gender','p_notes'];
    if(Object.keys(p).some(k=>!keys.includes(k)))throw Error('invalid_parameters');
    request=requireData(await userDb.rpc('zameel_play_request_promotion',p));
   } else throw Error('invalid_kind');
   const intent=requireData(await db.rpc('zameel_play_prepare_intent',{p_actor:uid,p_kind:body.kind,p_request:request.id}));
   return ok({request:{...request,billing_kind:body.kind},intent:intentView(intent)});
  }
  if(body.action==='status'||body.action==='request_status') {
   let query=db.from('zameel_play_payment_intents').select('*').eq('user_id',uid);
   if(body.action==='status'){if(!uuid(body.intentId))throw Error('invalid_intent');query=query.eq('id',body.intentId);}
   else{if(!uuid(body.requestId)||!['promotion','verification'].includes(body.kind))throw Error('invalid_request');query=query.eq('request_id',body.requestId).eq('kind',body.kind);}
   const intent=requireData(await query.single());
   const receipt=requireData(await db.from('zameel_play_purchase_ledger').select('settlement_state,acknowledgement_state').eq('intent_id',intent.id).maybeSingle());
   return ok({state:receipt?.settlement_state??intent.state,intent:{...intentView(intent),state:receipt?.settlement_state??intent.state}});
  }
  if(body.action==='verify') {
   if(typeof body.binding!=='string'||!/^[a-f0-9]{64}$/.test(body.binding))throw Error('invalid_binding');
   const i=requireData(await db.from('zameel_play_payment_intents').select('*').eq('user_id',uid).eq('intent_binding',body.binding).single());
   if(i.product_id!==body.productId)throw Error('product_mismatch');
   if(typeof body.purchaseToken!=='string'||body.purchaseToken.length>4096)throw Error('invalid_purchase_token');
   const hash=await sha256(body.purchaseToken);
   const existing=requireData(await db.from('zameel_play_purchase_ledger').select('intent_id').eq('token_sha256',hash).maybeSingle());
   if(existing&&existing.intent_id!==i.id)throw Error('purchase_token_already_used');
   const verified=await verifyWithGoogle({input:{intentId:i.id,purchaseToken:body.purchaseToken},authenticatedUserId:uid,
    intent:{id:i.id,userId:i.user_id,kind:i.kind,days:i.days,state:i.state==='cancelled'?'awaiting_payment':i.state,accountBinding:i.account_binding,intentBinding:i.intent_binding},
    getAccessToken:token,allowTest:env('GOOGLE_PLAY_ALLOW_TEST_PURCHASES')==='true',recordedToken:!!existing});
   const cipher=await seal(body.purchaseToken,key());
   const record=requireData(await db.rpc('zameel_play_record_verified_purchase',{p_actor:uid,p_intent:i.id,p_token_sha256:hash,p_product:i.product_id,
    p_account_binding:i.account_binding,p_intent_binding:i.intent_binding,p_purchased_at:new Date(verified.purchasedAt).toISOString(),p_order:verified.orderId,p_is_test:verified.isTest,p_cipher:cipher}));
   const receipt=requireData(await db.from('zameel_play_purchase_ledger').select('*').eq('token_sha256',hash).single());
   try { await reconcile(receipt); } catch { await db.from('zameel_play_purchase_ledger').update({last_error:'provider_reconciliation_failed'}).eq('token_sha256',hash); }
   const refreshed=requireData(await db.from('zameel_play_purchase_ledger').select('settlement_state,acknowledgement_state').eq('token_sha256',hash).single());
   return ok({...record,...refreshed});
  }
  return result(400,{ok:false,error:'unknown_action'});
 }catch{return result(400,{ok:false,error:'billing_request_failed'});}
});
