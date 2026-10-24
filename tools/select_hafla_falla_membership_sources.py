#!/usr/bin/env python3
"""Select owner-requested exact-tier originals from existing authorized APK archives.
Never changes entitlements, backend data, or original media bytes; retains old files.
"""
import argparse,hashlib,io,json,zipfile
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('packages',type=Path);a=p.parse_args()
    app=ROOT/'nimzo';out=app/'assets/membership/packs'
    prov=json.loads((out/'provenance.json').read_text())
    verification=json.loads((out/'verification_manifest.json').read_text())
    renders={r['id']:r for r in verification['items']}
    known={}
    for path in (app/'assets').rglob('*'):
        if path.is_file() and path.suffix.lower() in ['.png','.webp','.svga','.jpg']:
            known.setdefault(hashlib.sha256(path.read_bytes()).hexdigest(),path.relative_to(app).as_posix())
    changed=[]
    def select(z,package,pkgsha,entry,kind,tier,slot,role):
        data=z.read(entry);sha=hashlib.sha256(data).hexdigest()
        asset=known.get(sha,f'assets/membership/packs/{sha}{Path(entry).suffix}')
        dest=app/asset
        if dest.exists():assert dest.read_bytes()==data
        else:dest.write_bytes(data)
        known[sha]=asset
        image=Image.open(io.BytesIO(data));w,h=image.size
        row=dict(status='source-audited',source_package=package,source_package_sha256=pkgsha,
                 source_archive_path='base.apk!/'+entry,source_sha256=sha,sha256=sha,
                 source_kind=kind,source_tier=tier,path=asset,real_role=role,
                 dimensions=[w,h],animation=None,notes='Owner-selected source family; untouched original bytes. No source-app equip-behavior claim.')
        if slot=='avatar_frame':
            bbox=image.convert('RGBA').getbbox()
            row['crop']=[bbox[0],bbox[1],bbox[2]-bbox[0],bbox[3]-bbox[1],w,h]
        elif entry.endswith('.9.png'):
            row['crop']=[1,1,w-2,h-2,w,h]
            row['notes']+=' Android nine-patch control border excluded by canvas crop; source bytes retained.'
        pack=f'{kind}{tier}';prov[pack][slot]=row
        rid=f'membership-{pack}-{slot}'
        renders[rid]=dict(id=rid,asset=asset,name=f'{pack} {slot}',bytes=len(data),sha256=sha,media_kind='image',width=w,height=h,frames=1,fps=1)
        changed.append(dict(pack=pack,slot=slot,package=package,source=entry,sha256=sha))
    for package in ['Falla-V9.23.0.apks','Hafla-1.7.2.apks']:
        raw=(a.packages/package).read_bytes();pkgsha=hashlib.sha256(raw).hexdigest()
        expected={r['source_package_sha256'] for slots in prov.values() for r in slots.values() if r.get('source_package')==package and r.get('source_package_sha256')}
        assert expected and pkgsha in expected, 'Authorized source archive hash changed: '+package
        with zipfile.ZipFile(io.BytesIO(raw)) as outer:
            with zipfile.ZipFile(io.BytesIO(outer.read('base.apk'))) as z:
                if package.startswith('Falla'):
                    for tier in range(1,11):
                        for slot,entry,role in [
                            ('avatar_frame',f'res/drawable-xxhdpi-v4/ic_svip_level_up_avatar_bg_{tier}.webp','Empty original level-up portrait frame; used around the actual avatar'),
                            ('medal',f'res/drawable-xxhdpi-v4/icon_svip{tier}_medal.webp','Original static tier medal; animated main presentation remains separate'),
                            ('nameplate',f'res/drawable-xxhdpi-v4/ic_svip{tier}.webp','Original numbered SVIP identity badge')]:
                            select(z,package,pkgsha,entry,'svip',tier,slot,role)
                else:
                    for tier in range(1,9):
                        entry=(f'res/mipmap-xxhdpi-v4/icon_big_vip{tier}.png' if tier<=5 else
                               'res/mipmap-xhdpi-v4/'+{6:'icon_vip6_big.png',7:'bog_medal_vip7.png',8:'icon_vip8_big.png'}[tier])
                        for slot in ['medal','membership_hero']:
                            select(z,package,pkgsha,entry,'vip',tier,slot,'Original numbered Hafla VIP crest / medal (static)')
                        identity_entry=(f'res/mipmap-xxhdpi-v4/leave_vip{tier}_icon.png' if tier<=5 else
                                        'res/mipmap-xhdpi-v4/'+{6:'icon_vip6_small.png',7:'icon_vip7_long.png',8:'icon_vip8_long.png'}[tier])
                        for slot in ['nameplate','membership_badge']:
                            select(z,package,pkgsha,identity_entry,'vip',tier,slot,'Original numbered Hafla identity badge / VIP7–8 nameplate')
                        if tier<=5:
                            select(z,package,pkgsha,f'res/drawable-xhdpi-v4/icon_mess_vip{tier}.9.png','vip',tier,'chat_bubble','Original empty tier-specific chat bubble')
    (out/'provenance.json').write_text(json.dumps(prov,indent=2)+'\n')
    # Multiple genuine slots may share one original crest; render each byte sequence once.
    verification['items']=list({r['sha256']:r for r in renders.values()}.values())
    (out/'verification_manifest.json').write_text(json.dumps(verification,indent=2)+'\n')
    index={}
    for pack,slots in prov.items():
        index[pack]={slot:dict(path=r['path'],source=r['source_package']+'!/'+r['source_archive_path'],kind=r['source_kind'],tier=r['source_tier'],format='svga' if r.get('animation') else 'image',bytes=(app/r['path']).stat().st_size,sha256=r['sha256'],crop=r.get('crop')) for slot,r in slots.items()}
    dart='// Generated from source-audited originals; original checksums in bundled provenance.json.\nconst membershipOriginalAssets = <String, Map<String, Map<String, Object?>>>'+json.dumps(index,indent=2)+';\n'
    (app/'lib/features/premium/membership_original_assets.dart').write_text(dart)
    print('Selected',len(changed),'exact-tier source slots;',sum(map(len,prov.values())),'source mappings;',len(verification['items']),'distinct originals. Old files retained.')

if __name__=='__main__':main()
