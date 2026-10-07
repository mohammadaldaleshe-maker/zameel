import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateInput, validateGooglePurchase, verifyWithGoogle, productForIntent } from '../supabase/functions/play-billing/purchase_validation.mjs';
const uid='4e5b6367-9a88-48aa-a330-39b685883840';
const intent={id:'306e5ee1-1562-42ce-a291-524e643a892d',userId:uid,kind:'promotion',days:7,state:'awaiting_payment',accountBinding:'a'.repeat(64),intentBinding:'b'.repeat(64)};
const input={intentId:intent.id,purchaseToken:'opaque/token?example'};
const expected={...validateInput(input,uid,intent),accountBinding:intent.accountBinding,intentBinding:intent.intentBinding};
const valid={purchaseState:0,consumptionState:0,acknowledgementState:0,quantity:1,refundableQuantity:1,purchaseTimeMillis:'1791342000000',productId:expected.productId,obfuscatedExternalAccountId:intent.accountBinding,obfuscatedExternalProfileId:intent.intentBinding};
const rejects=(fn,code)=>assert.throws(fn,e=>e.code===code);
test('30 durations remain distinct and verification has no automatic renewal product',()=>{
 for(let days=1;days<=30;days++)assert.equal(productForIntent({...intent,days}),`zameel_promotion_${String(days).padStart(2,'0')}_days`);
 assert.equal(productForIntent({...intent,kind:'verification',days:null}),'zameel_verification_month');
 rejects(()=>productForIntent({...intent,days:31}),'invalid_intent_product');
});
test('anonymous and other-account submissions are denied before provider requests',()=>{
 rejects(()=>validateInput(input,null,intent),'authentication_required');
 rejects(()=>validateInput(input,'306e5ee1-1562-42ce-a291-524e643a892d',intent),'intent_owner_mismatch');
});
test('client cannot choose package, product, price or verification URL',()=>{
 for(const key of ['packageName','productId','price','url','userId'])rejects(()=>validateInput({...input,[key]:'untrusted'},uid,intent),'unexpected_input');
});
test('unknown intent, removed intent and missing binding are denied',()=>{
 rejects(()=>validateInput({...input,intentId:uid},uid,intent),'intent_mismatch');
 rejects(()=>validateInput(input,uid,{...intent,state:'cancelled'}),'intent_unavailable');
 rejects(()=>validateInput(input,uid,{...intent,intentBinding:null}),'missing_purchase_binding');
});
test('pending and cancelled payments never pass verification',()=>{
 rejects(()=>validateGooglePurchase({...valid,purchaseState:2},expected),'purchase_pending');
 rejects(()=>validateGooglePurchase({...valid,purchaseState:1},expected),'purchase_not_completed');
});
test('another product or account or intent cannot claim this payment',()=>{
 rejects(()=>validateGooglePurchase({...valid,productId:'other'},expected),'product_mismatch');
 for(const field of ['obfuscatedExternalAccountId','obfuscatedExternalProfileId'])rejects(()=>validateGooglePurchase({...valid,[field]:'c'.repeat(64)},expected),'purchase_binding_mismatch');
});
test('refunds and multiple quantities are rejected',()=>{
 rejects(()=>validateGooglePurchase({...valid,refundableQuantity:0},expected),'purchase_refunded');
 rejects(()=>validateGooglePurchase({...valid,quantity:2},expected),'unsupported_quantity');
});
test('consumed purchase requires an existing matching ledger record',()=>{
 rejects(()=>validateGooglePurchase({...valid,consumptionState:1},expected),'unrecognized_consumed_purchase');
 assert.equal(validateGooglePurchase({...valid,consumptionState:1},expected,{recordedToken:true}).consumed,true);
});
test('test purchases require explicit server configuration',()=>{
 rejects(()=>validateGooglePurchase({...valid,purchaseType:0},expected),'test_purchase_disabled');
 assert.equal(validateGooglePurchase({...valid,purchaseType:0},expected,{allowTest:true}).isTest,true);
});
test('purchase without order ID remains valid',()=>assert.equal(validateGooglePurchase(valid,expected).orderId,null));
test('provider URL is fixed; opaque token is encoded and redirects are blocked',async()=>{
 let url,options;
 const result=await verifyWithGoogle({input,authenticatedUserId:uid,intent,getAccessToken:async()=> 'server-only',fetchImpl:async(u,o)=>{url=u;options=o;return new Response(JSON.stringify(valid),{status:200});}});
 assert.equal(new URL(url).hostname,'androidpublisher.googleapis.com');
 assert.ok(url.endsWith('opaque%2Ftoken%3Fexample'));assert.equal(options.redirect,'error');assert.equal(result.productId,expected.productId);
});
test('provider error bodies cannot leak tokens or credentials',async()=>{
 await assert.rejects(verifyWithGoogle({input,authenticatedUserId:uid,intent,getAccessToken:async()=> 'server-only',fetchImpl:async()=> new Response('sensitive provider body',{status:403})}),e=>e.code==='google_verification_unavailable'&&!e.message.includes('sensitive'));
});
test('network failures and malformed response fail closed',async()=>{
 for(const fetchImpl of [async()=>{throw Error('secret');},async()=>new Response('invalid json')])await assert.rejects(verifyWithGoogle({input,authenticatedUserId:uid,intent,getAccessToken:async()=> 'server-only',fetchImpl}));
});
