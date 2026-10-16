"""Validate a public, already-signed APK; never receives signing credentials."""
from pathlib import Path
import hashlib,json,os,re,subprocess,zipfile

folder=Path('verified-apk');manifest=json.loads((folder/'prebuilt.json').read_text());source=manifest['sourceSha']
subprocess.run(['git','merge-base','--is-ancestor',source,'HEAD'],check=True)
def source_file(name): return subprocess.check_output(['git','show',source+':'+name],text=True)
version,build=re.search(r'^version:\s*([^+\n]+)\+(\d+)',source_file('nimzo/pubspec.yaml'),re.M).groups();build=int(build)
expected=source_file('nimzo/native/vivox/android/release-signing-certificate.sha256').strip()
apk=folder/'app-release.apk';digest=hashlib.sha256(apk.read_bytes()).hexdigest();assert digest==manifest['sha256'],'APK checksum mismatch'
tools=sorted(Path(os.environ['ANDROID_HOME']).glob('build-tools/*/apksigner'))[-1].parent
signature=subprocess.check_output([str(tools/'apksigner'),'verify','--verbose','--print-certs',str(apk)],text=True)
print(signature)  # Public certificate details only; no signing credentials.
certificates={value.replace(':','').lower() for value in re.findall(r'certificate SHA-256 digest:\s*([a-fA-F0-9:]+)',signature)}
assert certificates=={expected}, 'Permanent certificate mismatch or unreadable signer output'
cert=expected
badging=subprocess.check_output([str(tools/'aapt'),'dump','badging',str(apk)],text=True)
assert "package: name='io.nimzo.app'" in badging and f"versionCode='{build}'" in badging and f"versionName='{version}'" in badging,'Package/version mismatch'
assert 'android.permission.REQUEST_INSTALL_PACKAGES' in badging,'Installer permission missing'
xml=subprocess.check_output([str(tools/'aapt'),'dump','xmltree',str(apk),'AndroidManifest.xml'],text=True);assert 'io.nimzo.app.apk_updates' in xml,'Scoped update FileProvider missing'
with zipfile.ZipFile(apk) as archive:
 assert archive.testzip() is None, 'APK ZIP integrity failed'
 for abi in ('arm64-v8a','armeabi-v7a','x86_64'):
  for library in ('libvivox_bridge.so','libvivox-sdk.so'):
   assert archive.read(f'lib/{abi}/{library}')[:4]==b'\x7fELF','Native library missing/invalid'
 assert any(b'nimzo_verified_update' in archive.read(n) for n in archive.namelist() if re.fullmatch(r'classes\d*\.dex',n)),'Latest update lifecycle missing'
url=f'https://github.com/adi4ch-cmd/Nimzo/releases/download/nimzo-release-{source[:12]}/app-release.apk'
update=dict(version=version,buildNumber=build,packageName='io.nimzo.app',signingCertificateSha256=cert,apkSha256=digest,apkUrl=url)
(folder/'nimzo-update.json').write_text(json.dumps(update,indent=2)+'\n');(folder/'app-release.apk.sha256').write_text(digest+'  app-release.apk\n');(folder/'app-release.apk.signing.txt').write_text(signature)
subprocess.run(['python3','tools/verify_vivox_callback.py',str(apk)],check=True)
print('Prebuilt APK checksum, permanent signing identity, package/version, update lifecycle and Vivox libraries: PASS')

subprocess.run(["python3", "tools/verify_vivox_login.py", str(apk)], check=True)
