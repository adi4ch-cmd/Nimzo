"""Verify actual release APK notification/Firebase contracts without logging keys."""
import base64,json,os,re,subprocess,sys,zipfile
from pathlib import Path

def verify(apk):
 root=Path(__file__).resolve().parents[1]
 config=json.loads((root/'nimzo/tool/firebase_android_client.json').read_text())
 client=next(c for c in config['client'] if c['client_info']['android_client_info']['package_name']=='io.nimzo.app')
 tools=sorted(Path(os.environ['ANDROID_HOME']).glob('build-tools/*/aapt'))[-1]
 manifest=subprocess.check_output([str(tools),'dump','xmltree',str(apk),'AndroidManifest.xml'],text=True)
 badging=subprocess.check_output([str(tools),'dump','badging',str(apk)],text=True)
 assert 'application-debuggable' not in badging,'APK is debuggable instead of release mode'
 for value in ['android.permission.POST_NOTIFICATIONS','com.google.firebase.messaging.default_notification_channel_id','nimzo_activity','com.google.firebase.messaging.default_notification_icon','firebase_analytics_collection_deactivated']:
  assert value in manifest,'Missing notification manifest contract: '+value
 resources=subprocess.check_output([str(tools),'dump','--values','resources',str(apk)],text=True)
 for value in [config['project_info']['project_id'],client['client_info']['mobilesdk_app_id']]:
  assert value in resources,'Owner Firebase project resources missing'
 with zipfile.ZipFile(apk) as archive:
  for name in archive.namelist():
   if not (name.endswith('libapp.so') or name.startswith('assets/') and name.endswith(('.json','.txt','.env'))):continue
   data=archive.read(name)
   assert not re.search(rb'-----BEGIN (?:RSA )?PRIVATE KEY-----[\r\n]+[A-Za-z0-9+/=\r\n]{80,}',data),'Private key material in APK'
   for token in re.findall(rb'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',data):
    try:payload=json.loads(base64.urlsafe_b64decode(token.split(b'.')[1]+b'==='))
    except Exception:continue
    assert payload.get('role')!='service_role','Privileged service JWT in mobile artifact'
 result='PASS: release mode, Android13 permission/channel/icon, configured Firebase project and no detected privileged client credential.\n'
 apk.with_suffix('.apk.fcm-verification.txt').write_text(result)
 print(result.strip())
if __name__=='__main__':verify(Path(sys.argv[1]))
