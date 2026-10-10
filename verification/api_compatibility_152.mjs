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
