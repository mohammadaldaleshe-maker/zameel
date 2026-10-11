import fs from 'node:fs';
const source=fs.readFileSync(new URL('../lib/config.dart',import.meta.url),'utf8');
const config=name=>{
 const match=source.match(new RegExp("'"+name+"'[\\s\\S]*?defaultValue:\\s*'([^']+)'"));
 if(!match)throw new Error('Configuration missing: '+name);return match[1];
};
const base=config('SUPABASE_URL'),key=config('SUPABASE_PUBLISHABLE_KEY');
for(const [table,select] of [
 ['posts','id,users(name,profile_image,verification_expires_at)'],
 ['messages','id,users(name,profile_image)'],
]){
 const url=new URL(base+'/rest/v1/'+table);url.searchParams.set('select',select);url.searchParams.set('limit','0');
 const response=await fetch(url,{headers:{apikey:key},signal:AbortSignal.timeout(30000)});
 if(!response.ok)throw new Error(table+' compatibility HTTP '+response.status+': '+await response.text());
 console.log('PASS: '+table+' legacy author embedding accepted; no rows requested.');
}
const rpc=await fetch(base+'/rest/v1/rpc/zameel_chat_inbox_153',{
 method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:'{}',signal:AbortSignal.timeout(30000),
});
const result=await rpc.json();
if(![401,403].includes(rpc.status)||result.code!=='42501')throw new Error('153 inbox RPC unavailable or unexpected anonymous access: HTTP '+rpc.status+' '+JSON.stringify(result));
console.log('PASS: 153 inbox RPC exists and anonymous access is denied; no account records requested.');

const protectedRead=await fetch(base+'/rest/v1/rpc/zameel_admin_read_154',{
 method:'POST',headers:{apikey:key,'Content-Type':'application/json'},
 body:JSON.stringify({p_actor:'00000000-0000-4000-8000-000000000001',p_key:'users'}),signal:AbortSignal.timeout(30000)
});
const protectedResult=await protectedRead.json();
if(![401,403].includes(protectedRead.status)||protectedResult.code!=='42501')throw new Error('154 private RPC unavailable or anonymous access not denied: '+protectedRead.status);
console.log('PASS: 154 private reader exists and denies anonymous access; no account records requested.');
