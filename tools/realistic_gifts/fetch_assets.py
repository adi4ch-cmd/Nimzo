"""Fetch only pinned, free licensed car/studio source files; no marketplace login."""
import argparse
import hashlib
from pathlib import Path
import urllib.request

COMMIT='edc7c9e67c639d230715049ee31f9a96a6babbbe'
MODEL_URL=f'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/{COMMIT}/Models/CarConcept/glTF-Binary/CarConcept.glb'
FILES={
 'CarConcept.glb':(MODEL_URL,'c272098089d78c5cd9fd9f24ff50ee8acf8d932c55f2d55fc10adb6c8998966b'),
 'studio_small_09_1k.exr':('https://dl.polyhaven.org/file/ph-assets/HDRIs/exr/1k/studio_small_09_1k.exr','44dcbed056512ecd8afd2a3d7ba73d2dd4c24694d0c72005fafcb2469bbc8fd4'),
}
def fetch(folder):
 folder=Path(folder);folder.mkdir(parents=True,exist_ok=True)
 for name,(url,sha) in FILES.items():
  path=folder/name
  if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest()!=sha:
   with urllib.request.urlopen(url,timeout=120) as response:data=response.read()
   if hashlib.sha256(data).hexdigest()!=sha:raise ValueError('Source checksum mismatch: '+name)
   path.write_bytes(data)
 for name,tail in [('CAR_LICENSE.md','LICENSE.md'),('CAR_SOURCE_README.md','README.md')]:
  url=f'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/{COMMIT}/Models/CarConcept/{tail}'
  (folder/name).write_bytes(urllib.request.urlopen(url,timeout=60).read())
 print('Pinned CC-BY model and CC0 studio downloaded and checksum verified')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('folder');fetch(p.parse_args().folder)
