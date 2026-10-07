import {test} from 'node:test';
import assert from 'node:assert/strict';
import {seal,unseal,sha256,providerRequest,googleAccessToken} from '../supabase/functions/play-billing/google_provider.mjs';
const key=Buffer.alloc(32,7).toString('base64');
test('purchase tokens are encrypted with unique nonces and tampering/wrong keys fail',async()=>{
 const a=await seal('private-purchase-token',key),b=await seal('private-purchase-token',key);
 assert.notEqual(a,b);assert.ok(!a.includes('private-purchase-token'));assert.equal(await unseal(a,key),'private-purchase-token');
 await assert.rejects(unseal(a,Buffer.alloc(32,9).toString('base64')));
 await assert.rejects(unseal(a.slice(0,-4)+'AAAA',key));
 await assert.rejects(seal('x','eA=='),/invalid_token_key/);
 assert.equal((await sha256('token')).length,64);
});
test('provider operations use fixed package/host and empty consume/refund bodies',async()=>{
 const original=globalThis.fetch;const calls=[];
 try{globalThis.fetch=async(url,options)=>{calls.push({url,options});return new Response('',{status:200});};
  await providerRequest('credential','orders/GPA.fixture:refund?revoke=true',{method:'POST'});
  await providerRequest('credential','purchases/products/zameel_verification_month/tokens/opaque:consume',{method:'POST'});
  for(const c of calls){assert.ok(c.url.startsWith('https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.zameel.app/'));assert.equal(c.options.body,undefined);assert.equal(c.options.redirect,'error');assert.equal(c.options.headers.Authorization,'Bearer credential');}
  globalThis.fetch=async()=>new Response('sensitive provider detail',{status:403});await assert.rejects(providerRequest('credential','orders/test'),/^Error: google_provider_request_failed$/);
 }finally{globalThis.fetch=original;}
});
test('Google OAuth JWT has bounded publisher scope and ignores supplied token URI',async()=>{
 const pair=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
 const der=await crypto.subtle.exportKey('pkcs8',pair.privateKey);const private_key='-----BEGIN PRIVATE KEY-----\n'+Buffer.from(der).toString('base64')+'\n-----END PRIVATE KEY-----';
 const original=globalThis.fetch;let calls=0;
 try{globalThis.fetch=async(url,options)=>{calls++;assert.equal(url,'https://oauth2.googleapis.com/token');assert.equal(options.redirect,'error');const jwt=options.body.get('assertion'),[head,payload,sig]=jwt.split('.');const claims=JSON.parse(Buffer.from(payload,'base64url'));assert.equal(claims.iss,'billing@fixture.invalid');assert.equal(claims.scope,'https://www.googleapis.com/auth/androidpublisher');assert.equal(claims.aud,url);assert.equal(claims.exp-claims.iat,3600);assert.ok(await crypto.subtle.verify('RSASSA-PKCS1-v1_5',pair.publicKey,Buffer.from(sig,'base64url'),new TextEncoder().encode(head+'.'+payload)));return Response.json({access_token:'test-access',expires_in:3600});};
 const settings=JSON.stringify({client_email:'billing@fixture.invalid',private_key,token_uri:'http://internal.invalid'});assert.equal(await googleAccessToken(settings),'test-access');assert.equal(await googleAccessToken(settings),'test-access');assert.equal(calls,1);
 }finally{globalThis.fetch=original;}
});
