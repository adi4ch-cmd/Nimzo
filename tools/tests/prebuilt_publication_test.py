"""Execute publication policy; no requests or credentials leave this test."""
from pathlib import Path
import subprocess,tempfile,unittest,yaml

ROOT=Path(__file__).resolve().parents[2]

class PrebuiltPublicationTest(unittest.TestCase):
 def test_draft_tag_and_existing_release_integrity(self):
  workflow=yaml.safe_load((ROOT/'.github/workflows/nimzo-publish-verified.yml').read_text())
  script=next(s['with']['script'] for s in workflow['jobs']['publish']['steps'] if s.get('name')=='Publish complete verified release')
  harness=r'''
const realRequire=module.require.bind(module), assert=realRequire('assert'), crypto=realRequire('crypto');
const sourceSha='a'.repeat(40), tag='nimzo-release-'+sourceSha.slice(0,12), calls=[];
const apkUrl='https://github.com/adi4ch-cmd/Nimzo/releases/download/'+tag+'/app-release.apk';
const update={version:'1.0.6',buildNumber:106,apkSha256:'b'.repeat(64),apkUrl};
const files={'verified-apk/nimzo-update.json':JSON.stringify(update), 'verified-apk/prebuilt.json':JSON.stringify({sourceSha}),
'verified-apk/app-release.apk':'public-apk-fixture','verified-apk/app-release.apk.sha256':'public-checksum','verified-apk/app-release.apk.signing.txt':'public-certificate'};
const fs={readFileSync:p=>{assert(p in files);return files[p];}};
const require=name=>name==='fs'?fs:realRequire(name);
const context={repo:{owner:'adi4ch-cmd',repo:'Nimzo'}};
const core={summary:{addLink:()=>({write:async()=>{}})}};
let all=[];
const github={paginate:async()=>all,rest:{repos:{listReleases:()=>{},
createRelease:async body=>{calls.push(['create',body]);return {data:{id:1,tag_name:'untagged-fixture',assets:[]}};},
updateRelease:async body=>calls.push(['update',body]),
uploadReleaseAsset:async body=>calls.push(['asset',body]),
deleteReleaseAsset:async body=>calls.push(['delete',body])}}};
'''
  harness+='async function publish(){\n'+script+'\n}\n'
  harness+=r'''
(async()=>{
 await publish();assert.strictEqual(calls[0][0],'create');assert.strictEqual(calls[0][1].draft,true);
 assert.strictEqual(calls.filter(c=>c[0]==='asset').length,4);
 assert.strictEqual(calls.at(-1)[1].draft,false);assert.strictEqual(calls.at(-1)[1].tag_name,tag);
 const assets=[{name:'app-release.apk',digest:'sha256:'+update.apkSha256,browser_download_url:apkUrl},
 {name:'nimzo-update.json',digest:'sha256:'+crypto.createHash('sha256').update(files['verified-apk/nimzo-update.json']).digest('hex')},
 {name:'app-release.apk.sha256'},{name:'app-release.apk.signing.txt'}];
 all=[{id:1,draft:false,tag_name:tag,body:'NIMZO_BUILD_NUMBER=106',assets}];calls.length=0;
 await publish();assert.strictEqual(calls.length,0);
 assets[0].digest='sha256:'+'c'.repeat(64);
 await assert.rejects(publish(),/refusing to overwrite/);assert.strictEqual(calls.length,0);
 all=[{draft:false,tag_name:'newer-release',body:'NIMZO_BUILD_NUMBER=107'}];
 await assert.rejects(publish(),/increase build number/);assert.strictEqual(calls.length,0);
})().catch(error=>{console.error(error);process.exitCode=1});
'''
  with tempfile.TemporaryDirectory() as tmp:
   file=Path(tmp)/'publication.cjs';file.write_text('(async function(){\n'+harness+'\n})();')
   subprocess.run(['node',str(file)],check=True)
