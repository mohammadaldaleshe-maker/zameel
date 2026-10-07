const enc = new TextEncoder();
const b64 = bytes => btoa(String.fromCharCode(...new Uint8Array(bytes)));
const unb64 = text => Uint8Array.from(atob(text), c => c.charCodeAt(0));
const url64 = data => b64(typeof data === 'string' ? enc.encode(data) : data).replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');
export async function sha256(text) { return [...new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(text)))].map(v=>v.toString(16).padStart(2,'0')).join(''); }
export async function seal(token,keyText) {
 const bytes=unb64(keyText);if(bytes.length!==32)throw Error('invalid_token_key');
 const key=await crypto.subtle.importKey('raw',bytes,'AES-GCM',false,['encrypt']);
 const iv=crypto.getRandomValues(new Uint8Array(12));
 const data=await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:enc.encode('zameel:google-play:v1')},key,enc.encode(token));
 return `${b64(iv)}.${b64(data)}`;
}
export async function unseal(value,keyText) {
 const [iv,data]=value.split('.');const bytes=unb64(keyText);if(bytes.length!==32)throw Error('invalid_token_key');
 const key=await crypto.subtle.importKey('raw',bytes,'AES-GCM',false,['decrypt']);
 return new TextDecoder().decode(await crypto.subtle.decrypt({name:'AES-GCM',iv:unb64(iv),additionalData:enc.encode('zameel:google-play:v1')},key,unb64(data)));
}
let cached;
export async function googleAccessToken(serviceJson) {
 if(cached && cached.expires>Date.now()+60000)return cached.token;
 const service=JSON.parse(serviceJson);
 if(typeof service.client_email!=='string'||typeof service.private_key!=='string')throw Error('invalid_google_service');
 const now=Math.floor(Date.now()/1000);
 const payload={iss:service.client_email,scope:'https://www.googleapis.com/auth/androidpublisher',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600};
 const base=url64(JSON.stringify({alg:'RS256',typ:'JWT'}))+'.'+url64(JSON.stringify(payload));
 const pem=service.private_key.replace(/-----[^-]+-----/g,'').replace(/\s/g,'');
 const key=await crypto.subtle.importKey('pkcs8',unb64(pem),{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
 const signature=await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,enc.encode(base));
 const response=await fetch('https://oauth2.googleapis.com/token',{method:'POST',redirect:'error',signal:AbortSignal.timeout(10000),headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion:base+'.'+url64(signature)})});
 if(!response.ok)throw Error('google_credentials_unavailable');
 const data=await response.json();if(typeof data.access_token!=='string'||!Number.isFinite(data.expires_in))throw Error('google_credentials_unavailable');
 cached={token:data.access_token,expires:Date.now()+Math.min(data.expires_in,3600)*1000};return cached.token;
}
export async function providerRequest(accessToken,path,{method='GET',body}={}) {
 const response=await fetch('https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.zameel.app/'+path,{method,redirect:'error',signal:AbortSignal.timeout(10000),headers:{Authorization:'Bearer '+accessToken,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body)});
 if(!response.ok)throw Error('google_provider_request_failed');
 return response.status===204?null:response.text().then(text=>text?JSON.parse(text):null);
}
