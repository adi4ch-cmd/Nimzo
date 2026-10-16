// Transport a locally verified test build through GitHub's authenticated runner.
// This publisher intentionally produces no automatic-update manifest.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');

async function retrieve({github,context,manifest,dir='verified-test-apk'}) {
 if (!manifest || manifest.sourceSha!==context.sha) throw Error('APK source must match the checked-out source');
 if (!['io.nimzo.app','io.nimzo.app.test'].includes(manifest.packageName||'io.nimzo.app')) throw Error('Unsupported test package');
 if (!/^[a-f0-9]{64}$/.test(manifest.sha256) || !Number.isSafeInteger(manifest.bytes) || manifest.bytes<1 || manifest.bytes>512*1024*1024 ||
     !Array.isArray(manifest.blobs) || manifest.blobs.length<1 || manifest.blobs.length>100 || manifest.blobs.some(x=>!/^[a-f0-9]{40}$/.test(x))) throw Error('Invalid APK manifest');
 fs.mkdirSync(dir,{recursive:true});
 const target=path.join(dir,'nimzo-test.apk');
 const output=fs.openSync(target,'w');
 const hash=crypto.createHash('sha256');let bytes=0;
 try {
  for(const sha of manifest.blobs){
   const blob=await github.rest.git.getBlob({...context.repo,file_sha:sha});
   if(blob.data.encoding!=='base64')throw Error('Unsupported blob encoding');
   const data=Buffer.from(blob.data.content,'base64');bytes+=data.length;
   if(bytes>manifest.bytes)throw Error('APK exceeds declared size');
   fs.writeSync(output,data);hash.update(data);
  }
 }finally{fs.closeSync(output);}
 if(bytes!==manifest.bytes || hash.digest('hex')!==manifest.sha256){fs.unlinkSync(target);throw Error('APK checksum/size mismatch');}
 fs.writeFileSync(path.join(dir,'manifest.json'),JSON.stringify(manifest));
}

async function publish({github,context,dir='verified-test-apk'}){
 const tag=`nimzo-test-${context.runId}`;
 const apk=fs.readFileSync(path.join(dir,'nimzo-test.apk'));
 const checksum=crypto.createHash('sha256').update(apk).digest('hex');
 const manifestFile=path.join(dir,'manifest.json');
 const manifest=fs.existsSync(manifestFile)?JSON.parse(fs.readFileSync(manifestFile)):{};
 const parallel=manifest.packageName==='io.nimzo.app.test';
 const downloadName=manifest.compactNativeLibraries===true?'nimzo-compact-test.apk':'nimzo-test.apk';
 fs.writeFileSync(path.join(dir,'nimzo-test.apk.sha256'),`${checksum}  ${downloadName}\n`);
 const release=await github.rest.repos.createRelease({...context.repo,tag_name:tag,target_commitish:context.sha,
  name:parallel?'Nimzo Test — side-by-side install':'NIMZO 1.0.28 — verified TEST APK',draft:true,prerelease:true,
  body:(parallel?'Separate io.nimzo.app.test package: installs alongside the existing Nimzo app. Launcher label: Nimzo Test. Sign in with the existing account. If OAuth shows an app chooser, select Nimzo Test. Real store payments are not supported by this separate test package.':'Verified existing-feature repair APK. TEST signing; cannot update an installation signed with a different certificate.')+' No automatic updater metadata. SHA-256: '+checksum+'\nPhysical-device voice, OAuth and payments remain unverified.'});
 for(const name of ['nimzo-test.apk','nimzo-test.apk.sha256','nimzo-test.apk.signing.txt']){
  const data=fs.readFileSync(path.join(dir,name));
  await github.rest.repos.uploadReleaseAsset({...context.repo,release_id:release.data.id,name:name.replace('nimzo-test.apk',downloadName),data,
   headers:{'content-type':name.endsWith('.apk')?'application/vnd.android.package-archive':'text/plain','content-length':data.length}});
 }
 await github.rest.repos.updateRelease({...context.repo,release_id:release.data.id,draft:false});
 return `https://github.com/${context.repo.owner}/${context.repo.repo}/releases/download/${tag}/${downloadName}`;
}
module.exports={retrieve,publish};
