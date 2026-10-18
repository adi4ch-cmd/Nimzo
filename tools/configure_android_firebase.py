"""Install public Firebase Android configuration into a generated host.
Equivalent resources to the Google Services plugin; no private key or paid SDK.
"""
import argparse
import json
from pathlib import Path
import xml.etree.ElementTree as ET
ANDROID='http://schemas.android.com/apk/res/android'
ET.register_namespace('android',ANDROID)
def configure(android: Path, config: Path):
 data=json.loads(config.read_text())
 client=next((c for c in data.get('client',[]) if c.get('client_info',{}).get('android_client_info',{}).get('package_name')=='io.nimzo.app'),None)
 if client is None: raise ValueError('Firebase config must contain Android package io.nimzo.app')
 project=data['project_info']
 values={'google_app_id':client['client_info']['mobilesdk_app_id'],
         'gcm_defaultSenderId':project['project_number'],
         'project_id':project['project_id'],
         'google_api_key':client['api_key'][0]['current_key']}
 if not all(isinstance(v,str) and v for v in values.values()):raise ValueError('Incomplete Firebase config')
 resources=ET.Element('resources')
 for name,value in values.items():ET.SubElement(resources,'string',{'name':name,'translatable':'false'}).text=value
 target=android/'app/src/main/res/values/nimzo_firebase.xml';target.parent.mkdir(parents=True,exist_ok=True)
 ET.indent(resources);target.write_text(ET.tostring(resources,encoding='unicode'))
 manifest=android/'app/src/main/AndroidManifest.xml';tree=ET.parse(manifest);root=tree.getroot()
 key='{'+ANDROID+'}name'
 if not any(node.get(key)=='android.permission.POST_NOTIFICATIONS' for node in root.findall('uses-permission')):
  ET.SubElement(root,'uses-permission',{key:'android.permission.POST_NOTIFICATIONS'})
 app=root.find('application')
 if app is None:raise ValueError('Android application is missing')
 for name,value in {'firebase_analytics_collection_deactivated':'true','firebase_messaging_auto_init_enabled':'false'}.items():
  node=next((n for n in app.findall('meta-data') if n.get(key)==name),None)
  if node is None:node=ET.SubElement(app,'meta-data',{key:name})
  node.set('{'+ANDROID+'}value',value)
 ET.indent(root);tree.write(manifest,encoding='unicode')
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('android',type=Path);parser.add_argument('config',type=Path)
 args=parser.parse_args();configure(args.android,args.config)
 print('Firebase Android resources installed; Analytics disabled')
