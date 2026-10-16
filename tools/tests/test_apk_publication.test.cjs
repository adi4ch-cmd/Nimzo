const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const crypto=require('node:crypto');
const {retrieve,publish}=require('../publish_test_apk.cjs');

test('reassembles only checksum-verified APK blobs for the current source',async()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nimzo-apk-'));
 try {
  const bytes=Buffer.from('verified-test-apk');
  const context={sha:'a'.repeat(40),repo:{owner:'o',repo:'r'}};
  const manifest={sourceSha:context.sha,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length,blobs:['b'.repeat(40)]};
  const github={rest:{git:{getBlob:async()=>({data:{encoding:'base64',content:bytes.toString('base64')}})}}};
  await retrieve({github,context,manifest,dir});
  assert.deepEqual(fs.readFileSync(path.join(dir,'nimzo-test.apk')),bytes);
  await assert.rejects(retrieve({github,context,manifest:{...manifest,sourceSha:'c'.repeat(40)},dir}),/source/);
  await assert.rejects(retrieve({github,context,manifest:{...manifest,packageName:'com.other.app'},dir}),/package/);
  await retrieve({github,context,manifest:{...manifest,packageName:'io.nimzo.app.test'},dir});
  assert.equal(JSON.parse(fs.readFileSync(path.join(dir,'manifest.json'))).packageName,'io.nimzo.app.test');
  await assert.rejects(retrieve({github,context,manifest:{...manifest,sha256:'d'.repeat(64)},dir}),/checksum/);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});

test('test APK release excludes automatic-update metadata and publishes after uploads',async()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nimzo-publish-'));
 try {
  fs.writeFileSync(path.join(dir,'nimzo-test.apk'),'apk');
  fs.writeFileSync(path.join(dir,'manifest.json'),JSON.stringify({packageName:'io.nimzo.app.test',compactNativeLibraries:true}));
  fs.writeFileSync(path.join(dir,'nimzo-test.apk.signing.txt'),'test-signature');
  const calls=[];
  const github={rest:{repos:{createRelease:async x=>{calls.push(['create',x]);return {data:{id:1}};},
   uploadReleaseAsset:async x=>calls.push(['asset',x.name]),updateRelease:async x=>calls.push(['publish',x])}}};
  const context={sha:'a'.repeat(40),runId:123,repo:{owner:'o',repo:'r'}};
  const url=await publish({github,context,dir});
  assert.equal(calls[0][1].draft,true);assert.equal(calls[0][1].prerelease,true);
  assert.deepEqual(calls.filter(c=>c[0]==='asset').map(c=>c[1]),['nimzo-compact-test.apk','nimzo-compact-test.apk.sha256','nimzo-compact-test.apk.signing.txt']);
  assert.equal(calls.at(-1)[0],'publish');assert.equal(calls.at(-1)[1].draft,false);
  assert.match(url,/https:\/\/github.com\/o\/r\/releases\/download\/nimzo-test-123\/nimzo-compact-test.apk/);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
