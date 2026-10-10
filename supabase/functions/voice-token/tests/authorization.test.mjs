import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import {runInNewContext} from 'node:vm';
import {webcrypto} from 'node:crypto';
const room='00000000-0000-4000-8000-000000000201';
const user='00000000-0000-4000-8000-000000000102';
function handler({allowed=true,canTransmit=false,authOk=true,rpcOk=true,signingKey='test-signing-key'}={}) {
 let serve; const calls=[];
 const env={SUPABASE_URL:'https://example.invalid',SUPABASE_SERVICE_ROLE_KEY:'test-service',VIVOX_TOKEN_KEY:signingKey};
 const source=stripTypeScriptTypes(readFileSync(new URL('../index.ts',import.meta.url),'utf8').replace(/^import[^\n]*\n/,''));
 runInNewContext(source,{Deno:{env:{get:k=>env[k]},serve:h=>{serve=h}},Response,TextEncoder,btoa,crypto:webcrypto,Date,fetch:async(url,init)=>{calls.push({url,init});return url.endsWith('/auth/v1/user')?Response.json({id:user},{status:authOk?200:401}):Response.json({allowed,canTransmit},{status:rpcOk?200:503});}});
 return {serve,calls};
}
function request(body={room},auth=true){return new Request('https://example.invalid',{method:'POST',headers:{...(auth?{Authorization:'Bearer test-user-token'}:{}),'Content-Type':'application/json'},body:JSON.stringify(body)});}
test('rejects missing/invalid session before authorization',async()=>{assert.equal((await handler().serve(request({},false))).status,401);assert.equal((await handler({authOk:false}).serve(request())).status,401);});
test('requires exact room UUID',async()=>{const h=handler();assert.equal((await h.serve(request({room:'private/another-room'}))).status,400);assert.equal(h.calls.length,1);});
test('denies departed/banned/non-member according to database authority',async()=>{assert.equal((await handler({allowed:false}).serve(request())).status,403);});
test('fails closed when authorization service fails',async()=>{assert.equal((await handler({rpcOk:false}).serve(request())).status,503);});
test('listeners receive signed room-bound login/join credentials with transmit disabled',async()=>{const h=handler();const r=await h.serve(request());assert.equal(r.status,200);const data=await r.json();assert.equal(data.canTransmit,false);assert.equal(data.channelUri,'sip:confctl-g-18968-nimzo-13904.'+room+'@mtu1xp.vivox.com');assert.equal(data.accountUri,'sip:.18968-nimzo-13904.'+user+'.@mtu1xp.vivox.com');assert.equal(data.server,'https://unity.vivox.com/appconfig/18968-nimzo-13904');for(const [key,action]of[['loginToken','login'],['channelToken','join_muted']]){const parts=data[key].split('.');const payload=JSON.parse(Buffer.from(parts[1],'base64url'));assert.equal(payload.vxa,action);assert.equal(payload.f,data.accountUri);if(action==='join_muted')assert.equal(payload.t,data.channelUri);const secret=await webcrypto.subtle.importKey('raw',new TextEncoder().encode('test-signing-key'),{name:'HMAC',hash:'SHA-256'},false,['verify']);assert.equal(await webcrypto.subtle.verify('HMAC',secret,Buffer.from(parts[2],'base64url'),new TextEncoder().encode(parts[0]+'.'+parts[1])),true);}assert.deepEqual(JSON.parse(h.calls[1].init.body),{p_room:room,p_user:user});});
test('authorized seat receives join token and transmit state',async()=>{const data=await(await handler({canTransmit:true}).serve(request())).json();assert.equal(data.canTransmit,true);assert.equal(JSON.parse(Buffer.from(data.channelToken.split('.')[1],'base64url')).vxa,'join');});

test('production Vivox identity is pinned while private signing key stays server-only',async()=>{const data=await(await handler().serve(request())).json();assert.equal(data.accountUri.startsWith('sip:.18968-nimzo-13904.'),true);assert.equal(data.channelUri.endsWith('@mtu1xp.vivox.com'),true);assert.equal(data.server,'https://unity.vivox.com/appconfig/18968-nimzo-13904');assert.equal(Object.prototype.hasOwnProperty.call(data,'tokenKey'),false);assert.equal(JSON.stringify(data).includes('test-signing-key'),false);});

test('pasted signing secret whitespace is normalized before creating a Vivox token',async()=>{
 const data=await(await handler({signingKey:'  test-signing-key\\n'}).serve(request())).json();
 for (const property of ['loginToken','channelToken']) {
  const parts=data[property].split('.');
  const expected=await webcrypto.subtle.importKey('raw',new TextEncoder().encode('test-signing-key'),{name:'HMAC',hash:'SHA-256'},false,['verify']);
  assert.equal(await webcrypto.subtle.verify('HMAC',expected,Buffer.from(parts[2],'base64url'),new TextEncoder().encode(parts[0]+'.'+parts[1])),true);
 }
});
