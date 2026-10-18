"""Install the approved identity into a generated Android host."""
from pathlib import Path
import argparse
import shutil
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('android', type=Path)
parser.add_argument('icon', type=Path)
args = parser.parse_args()
if not args.icon.is_file():
    parser.error('Brand icon is missing')
resources = args.android / 'app/src/main/res/drawable-nodpi'
resources.mkdir(parents=True, exist_ok=True)
shutil.copyfile(args.icon, resources / 'nimzo_brand_icon.png')
manifest = args.android / 'app/src/main/AndroidManifest.xml'
ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')
tree = ET.parse(manifest)
app = tree.getroot().find('application')
if app is None:
    raise SystemExit('Android application is missing')
for attr in ['icon', 'roundIcon']:
    app.set('{http://schemas.android.com/apk/res/android}' + attr, '@drawable/nimzo_brand_icon')
tree.write(manifest, encoding='utf-8', xml_declaration=True)
print('Installed approved Purple Gold NIMZO icon')
