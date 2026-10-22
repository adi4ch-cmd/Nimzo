#!/usr/bin/env python3
"""Read-only verification of exact accepted Voku/Rocket/control bytes in an APK."""
import argparse,hashlib,json
from pathlib import Path
from zipfile import ZipFile
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('apk',type=Path);a=p.parse_args()
 app=ROOT/'nimzo';manifest=json.loads((app/'assets/membership/voku/manifest.json').read_text())
 rows=manifest['records'];assert len(rows)==40
 paths=set()
 for row in rows:
  path=app/row['asset'];assert hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256'];paths.add(path)
 for folder in ['assets/room_rocket','assets/nimzo/gift_controls']:
  paths.update(path for path in (app/folder).rglob('*') if path.is_file())
 with ZipFile(a.apk) as archive:
  assert archive.testzip() is None
  for path in paths:
   name='assets/flutter_assets/'+path.relative_to(app).as_posix()
   assert archive.read(name)==path.read_bytes(), 'APK media mismatch: '+name
 print(f'PASS: {len(paths)} exact Voku, Rocket and gift control assets packaged')
if __name__=='__main__':main()
