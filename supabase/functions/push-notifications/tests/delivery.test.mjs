import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import {runInNewContext} from 'node:vm';
import {generateKeyPairSync, webcrypto} from 'node:crypto';
const pair=generateKeyPairSync('rsa',{modulusLength:2048});
const account={project_id:'nimzo-1f296',client_email:'sender@nimzo-test.iam.gserviceaccount.com',private_key:pair.privateKey.export({format:'pem',type:'pkcs8'})};
const job={notification_id:'00000000-0000-4000-8000-000000000101',user_id:'alice',device_token:'real-device',lease_id:'lease'};
function handler({configured=true,fcmStatus=200,fcmBody={name:'sent'}}={}) {
 const calls=[];let serve;
 const env={SUPABASE_URL:'https://project.supabase.co',SUPABASE_SERVICE_ROLE_KEY:'private-service-key',...(configured?{FCM_SERVICE_ACCOUNT_JSON:JSON.stringify(account)}:{})};
 const source=stripTypeScriptTypes(readFileSync(new URL('../index.ts',import.meta.url),'utf8'));
 runInNewContext(source,{Deno:{env:{get:k=>env[k]},serve:h=>serve=h},Response,TextEncoder,Uint8Array,URLSearchParams,AbortSignal,Date,JSON,Math,atob,btoa,crypto:webcrypto,
 fetch:async(url,init)=>{calls.push({url,init});
 if(url.endsWith('get_push_firebase_service_account'))return configured ? Response.json(account) : Response.json({}, {status:503});
 if(url.endsWith('authorize_push_dispatch'))return Response.json(true);
 if(url.endsWith('claim_push_batch'))return Response.json([job]);
 if(url.endsWith('finish_push'))return Response.json(true);
 if(url==='https://oauth2.googleapis.com/token')return Response.json({access_token:'google-access',expires_in:3600});
 if(url.startsWith('https://fcm.googleapis.com/'))return Response.json(fcmBody,{status:fcmStatus});
 throw Error('Unexpected network request');}});
 return {calls,serve};
}
const request=(key='private-service-key')=>new Request('https://worker',{method:'POST',headers:{Authorization:'Bearer '+key}});
test('rejects normal user calls before touching database or Firebase',async()=>{const h=handler();assert.equal((await h.serve(request('user-jwt'))).status,401);assert.equal(h.calls.length,0);});
test('missing Firebase credentials leaves queued jobs untouched',async()=>{const h=handler({configured:false});assert.equal((await h.serve(request())).status,503);assert.equal(h.calls.some(c=>c.url.endsWith('claim_push_batch')),false);});
test('sends only generic notification and identity; settles successful lease',async()=>{
 const h=handler();assert.equal((await h.serve(request())).status,200);
 const fcm=h.calls.find(c=>c.url.startsWith('https://fcm.googleapis.com/'));
 const message=JSON.parse(fcm.init.body).message;
 assert.equal(message.token,'real-device');assert.equal(message.data.notification_id,job.notification_id);assert.equal(message.data.user_id,'alice');
 assert.equal(message.notification.body,'Open NIMZO to view your notification.');
 assert.equal(JSON.parse(h.calls.at(-1).init.body).p_result,'sent');
 const oauth=h.calls.find(c=>c.url==='https://oauth2.googleapis.com/token');
 const jwt=new URLSearchParams(oauth.init.body).get('assertion');const [header,body,sig]=jwt.split('.');
 assert.equal(JSON.parse(Buffer.from(body,'base64url')).scope,'https://www.googleapis.com/auth/firebase.messaging');
 const key=await webcrypto.subtle.importKey('spki',pair.publicKey.export({format:'der',type:'spki'}),{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['verify']);
 assert.equal(await webcrypto.subtle.verify('RSASSA-PKCS1-v1_5',key,Buffer.from(sig,'base64url'),new TextEncoder().encode(header+'.'+body)),true);
});
test('only an explicit UNREGISTERED FCM token is invalidated',async()=>{
 const h=handler({fcmStatus:404,fcmBody:{error:{details:[{errorCode:'UNREGISTERED'}]}}});await h.serve(request());assert.equal(JSON.parse(h.calls.at(-1).init.body).p_result,'invalid');
});
test('temporary Firebase failure retries instead of dropping the device',async()=>{
 const h=handler({fcmStatus:503});await h.serve(request());assert.equal(JSON.parse(h.calls.at(-1).init.body).p_result,'retry');
});

test('scheduled request authenticates its one-time signed dispatch before reading Vault',async()=>{const h=handler();const r=await h.serve(new Request('https://worker',{method:'POST',headers:{Authorization:'Bearer public-project-jwt','X-Nimzo-Dispatch-Time':'123','X-Nimzo-Dispatch-Nonce':'00000000-0000-4000-8000-000000000104','X-Nimzo-Dispatch-Signature':'a'.repeat(64)}}));assert.equal(r.status,200);assert.equal(h.calls[0].url.endsWith('authorize_push_dispatch'),true);});
