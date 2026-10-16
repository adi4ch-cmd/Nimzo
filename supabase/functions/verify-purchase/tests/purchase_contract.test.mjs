import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
const source=stripTypeScriptTypes(readFileSync(new URL('../purchase_contract.ts',import.meta.url),'utf8'));
const {requireGooglePurchase}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const user='00000000-0000-4000-8000-000000000001';
const valid={purchaseState:0,obfuscatedExternalAccountId:user,quantity:1};
test('only completed provider-owned single-unit account-bound purchases permit settlement',()=>{
 assert.equal(requireGooglePurchase(valid,user),'production');
 assert.throws(()=>requireGooglePurchase({...valid,purchaseState:1},user),/not completed/);
 assert.throws(()=>requireGooglePurchase({...valid,purchaseState:undefined},user),/not completed/);
 assert.throws(()=>requireGooglePurchase({...valid,obfuscatedExternalAccountId:undefined},user),/binding/);
 assert.throws(()=>requireGooglePurchase(valid,'other'),/binding/);
});
test('sandbox, promotional and multi-quantity receipts never credit live balances',()=>{
 assert.throws(()=>requireGooglePurchase({...valid,purchaseType:0},user),/Sandbox.*not credited/);
 assert.throws(()=>requireGooglePurchase({...valid,purchaseType:1},user),/Promotional/);
 assert.throws(()=>requireGooglePurchase({...valid,quantity:2},user),/Multi-quantity/);
});
