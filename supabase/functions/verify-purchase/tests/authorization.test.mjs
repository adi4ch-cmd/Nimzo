import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
const helper=stripTypeScriptTypes(readFileSync(new URL('../purchase_contract.ts',import.meta.url),'utf8'));
const {requireGooglePurchase}=await import('data:text/javascript;base64,'+Buffer.from(helper).toString('base64'));
let source=readFileSync(new URL('../index.ts',import.meta.url),'utf8').replace(/^import .*\n/gm,'');
// OAuth transport is isolated here; real provider credentials are never used in tests.
const begin=source.indexOf('async function googleAccessToken('),end=source.indexOf('async function verifyGoogle(');
source=source.slice(0,begin)+'async function googleAccessToken(){return "fixture-provider-token";}\n'+source.slice(end);
source=stripTypeScriptTypes(source);
const user='00000000-0000-4000-8000-000000000001';
function setup(data, configured=true){
 let handler,calls=[];
 const Deno={env:{get:n=>n==='GOOGLE_PLAY_SERVICE_ACCOUNT'?(configured?'fixture':undefined):'fixture'},serve:h=>handler=h};
 const admin={auth:{getUser:async token=>token==='session'?{data:{user:{id:user}}}:{data:{},error:{}}},rpc:async(name,args)=>{
  calls.push({name,args});return {data:{status:'credited',product_id:args.p_product,transaction_id:args.p_txn,coins:500000},error:null};
 }};
 new Function('Deno','createClient','fetch','requireGooglePurchase',source)(Deno,()=>admin,async()=>new Response(JSON.stringify(data),{status:200}),requireGooglePurchase);
 return {calls,request:async(body,token='session')=>handler(new Request('https://example.invalid/verify-purchase',{method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(body)}))};
}
const body={store:'google_play',product_id:'coins_1usd',receipt:'receipt-fixture',user_id:'attacker',coins:99999999};
test('configuration requires authentication and reports capabilities without claiming payment success',async()=>{
 const s=setup({});assert.equal((await s.request({action:'configuration'},'invalid')).status,401);
 const r=await (await s.request({action:'configuration'})).json();assert.deepEqual(r,{account_binding:true,ready_stores:['google_play'],environment:'store-managed'});assert.equal(s.calls.length,0);
 assert.deepEqual((await (await setup({},false).request({action:'configuration'})).json()).ready_stores,[]);
});
for(const [name,data] of [
 ['pending',{purchaseState:2,obfuscatedExternalAccountId:user}],
 ['wrong account',{purchaseState:0,obfuscatedExternalAccountId:'other'}],
 ['unbound',{purchaseState:0}],
 ['sandbox',{purchaseState:0,obfuscatedExternalAccountId:user,purchaseType:0}],
 ['multi quantity',{purchaseState:0,obfuscatedExternalAccountId:user,quantity:2}],
]) test(name+' never reaches settlement',async()=>{const s=setup(data);assert.equal((await s.request(body)).status,400);assert.equal(s.calls.length,0);});
test('confirmed bound Google provider purchase settles authenticated user only',async()=>{
 const s=setup({purchaseState:0,obfuscatedExternalAccountId:user,quantity:1});
 const r=await s.request(body);assert.equal(r.status,200);const result=await r.json();assert.equal(result.ok,true);assert.equal(result.environment,'production');
 assert.deepEqual(s.calls,[{name:'apply_recharge',args:{p_user:user,p_store:'google_play',p_txn:'receipt-fixture',p_product:'coins_1usd'}}]);
});
test('Apple legacy receipt and malformed request cannot settle',async()=>{
 const s=setup({});assert.equal((await s.request({...body,store:'app_store'})).status,503);assert.equal((await s.request(null)).status,400);assert.equal(s.calls.length,0);
});
