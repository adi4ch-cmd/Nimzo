"""Execute release publication logic against mocked GitHub, never production."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[2]


class ReleaseWorkflowTest(unittest.TestCase):
    def test_release_is_published_only_after_all_compatible_metadata_assets(self):
        workflow = yaml.safe_load((ROOT / '.github/workflows/nimzo-apk-build.yml').read_text())
        script = next(s['with']['script'] for s in workflow['jobs']['build']['steps'] if s['name'] == 'Publish testing APK')
        harness = r'''
const assert=module.require('assert');
const calls=[];
const realRequire=require;
const files={'nimzo/pubspec.yaml':'version: 1.0.6+106\n',
'nimzo/build/app/outputs/flutter-apk/app-release.apk.signing.txt':'Signer (minSdkVersion=24, maxSdkVersion=32) certificate SHA-256 digest: '+'e'.repeat(64)+'\nSigner #1 certificate SHA-256 digest: '+'e'.repeat(64),
'nimzo/build/app/outputs/flutter-apk/app-release.apk':Buffer.from('test-apk'),
'nimzo/build/app/outputs/flutter-apk/app-release.apk.sha256':'checksum'};
const fs={readFileSync:(p)=>{assert(p in files);return files[p];},writeFileSync:(p,v)=>files[p]=v};
const context={sha:'a'.repeat(40),repo:{owner:'adi4ch-cmd',repo:'Nimzo'}};
const core={info:()=>{},summary:{addLink:()=>({write:async()=>{}})}};
const github={paginate:async()=>previous,rest:{repos:{listReleases:()=>{},
createRelease:async(v)=>{calls.push(['create',v]);return {data:{id:1}};},
uploadReleaseAsset:async(v)=>{calls.push(['asset',v]);return {data:{browser_download_url:'verified-url'}};},
updateRelease:async(v)=>calls.push(['publish',v])}}};
const require=(name)=>name==='fs'?fs:realRequire(name);
let previous=[];
'''
        harness = harness.replace('const realRequire=require;', 'const realRequire=module.require.bind(module);')
        harness += 'async function publish(){\n' + script + '\n}\n'
        harness += r'''
(async()=>{
await publish();
assert.strictEqual(calls[0][0],'create');assert.strictEqual(calls[0][1].draft,true);
assert.deepStrictEqual(calls.filter(c=>c[0]==='asset').map(c=>c[1].name),['app-release.apk','app-release.apk.sha256','app-release.apk.signing.txt','nimzo-update.json']);
assert.strictEqual(calls.at(-1)[0],'publish');assert.strictEqual(calls.at(-1)[1].draft,false);
const manifest=JSON.parse(files['nimzo/build/app/outputs/flutter-apk/nimzo-update.json']);
assert.strictEqual(manifest.buildNumber,106);assert.strictEqual(manifest.packageName,'io.nimzo.app');
assert.strictEqual(manifest.signingCertificateSha256,'e'.repeat(64));assert.strictEqual(manifest.apkSha256.length,64);
assert.strictEqual(manifest.apkUrl,'https://github.com/adi4ch-cmd/Nimzo/releases/download/nimzo-release-aaaaaaaaaaaa/app-release.apk');
calls.length=0;previous=[{draft:false,body:'NIMZO_BUILD_NUMBER=106'}];
await assert.rejects(publish(),/Increase Flutter build number/);assert.strictEqual(calls.length,0);
previous=[{draft:false,body:'NIMZO_BUILD_NUMBER=107'}];await assert.rejects(publish());assert.strictEqual(calls.length,0);
})().catch(e=>{console.error(e);process.exitCode=1});
'''
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'release.cjs'
            # CommonJS has an injected require binding; use a function scope.
            path.write_text('(async function(){\n' + harness + '\n})();')
            subprocess.run(['node', str(path)], check=True)

    def test_existing_signing_config_replaces_debug_selection_before_reference(self):
        spec = importlib.util.spec_from_file_location('signing', ROOT / 'tools/configure_android_signing.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'build.gradle.kts'
            path.write_text('plugins { id("com.android.application") }\nandroid { buildTypes { release { signingConfig = signingConfigs.getByName("debug") } } }')
            module.configure(path)
            value = path.read_text()
            self.assertNotIn('getByName("debug")', value)
            self.assertLess(value.index('create("release")'), value.index('getByName("release")'))
            self.assertIn('System.getenv("NIMZO_KEYSTORE_PASSWORD")', value)
            self.assertTrue(value.startswith('plugins'))


if __name__ == '__main__':
    unittest.main()
