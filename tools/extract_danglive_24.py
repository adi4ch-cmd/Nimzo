#!/usr/bin/env python3
"""Extract the 24 confirmed original DangLive media resources with exact hashes.

Local-only tool. Requires the ORIGINAL owner-authorized DangLive-1.1.17.apks
(or its base.apk). Does not fabricate Store products from medals/backgrounds.
Do not commit the full source APK to NIMZO. Run only with rights to reuse assets.

Usage:
  python3 tools/extract_danglive_24.py /path/to/DangLive-1.1.17.apks
Output:
  nimzo/assets/licensed_danglive_original/    (22 SVGA, 1 PAG, 1 MP4)
  nimzo-danglive-24-originals.zip              (small handoff archive)
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import zipfile

EXPECTED_BASE_SHA256 = '76cb8df828c167e76ce8c5d401678ba1fe223d9053f4beb16c3404e475a88208'
EXPECTED = json.loads(r'''[{"source":"assets/flutter_assets/assets/leaderboard/frames/rank1.svga","path":"leaderboard/frames/rank1.svga","bytes":443384,"sha256":"fb925b40b06573f454ab2209df5040bf526188023a80b2b409abe11ad451bc00"},{"source":"assets/flutter_assets/assets/leaderboard/frames/rank2.svga","path":"leaderboard/frames/rank2.svga","bytes":497426,"sha256":"413c1d3762ec2270da8cc6a268a966f97aa27d2d847b928e05a0a8105a254fa4"},{"source":"assets/flutter_assets/assets/leaderboard/frames/rank3.svga","path":"leaderboard/frames/rank3.svga","bytes":466718,"sha256":"513e0934934fc565ab6367ac0a394f94b746b9f54ec34f918f55abc9f1f0a064"},{"source":"assets/flutter_assets/assets/leaderboard/portrait-frames/top1.svga","path":"leaderboard/portrait-frames/top1.svga","bytes":467511,"sha256":"2d31abd6da610471767ebb64ac56d462054b9ea4236250266a9ed06adce3c7b1"},{"source":"assets/flutter_assets/assets/leaderboard/portrait-frames/top2.svga","path":"leaderboard/portrait-frames/top2.svga","bytes":295247,"sha256":"98059625544424cc2bee6ee22676c849458e59e77907d98ba0364725e30a2c24"},{"source":"assets/flutter_assets/assets/leaderboard/portrait-frames/top3.svga","path":"leaderboard/portrait-frames/top3.svga","bytes":290586,"sha256":"98795e51ce598bd900f12580a216b4d0fac893f8f08faef600729cb6f75f0b4b"},{"source":"assets/flutter_assets/assets/pag/profile-intro.pag","path":"pag/profile-intro.pag","bytes":5648507,"sha256":"01e0b3fb4479c4288ed8c8eb640d4546038f2a62f6c424cb9916ba486373c742"},{"source":"assets/flutter_assets/assets/svga/cp-nest-frame-new.svga","path":"svga/cp-nest-frame-new.svga","bytes":238719,"sha256":"4ec6357d9531276015c11bf91946b4baa1a7f063f7bbf8fc818bd26ba4c78f99"},{"source":"assets/flutter_assets/assets/svga/frame-cp.svga","path":"svga/frame-cp.svga","bytes":273093,"sha256":"f1a3eaf116a1017fecb006c43f7162f40fb9cf9b3ebc2fd3a3d0cf70ae8669bc"},{"source":"assets/flutter_assets/assets/svga/frame-family.svga","path":"svga/frame-family.svga","bytes":268708,"sha256":"da20c84ef5b39333a53b17d3d16640b5e3b92e86e15a4265575993c555278c70"},{"source":"assets/flutter_assets/assets/svga/frame-room.svga","path":"svga/frame-room.svga","bytes":314686,"sha256":"841b8d76ebb552b84195c1cd88a0a361e5f0d59a9cb150bfde3633bd2131b6d2"},{"source":"assets/flutter_assets/assets/svga/medals/agency-leader.svga","path":"svga/medals/agency-leader.svga","bytes":363563,"sha256":"776c694bf7605be0415489a3386f7daf71bf7806455ec0161c92ceda86aaf771"},{"source":"assets/flutter_assets/assets/svga/medals/exclusive-identity.svga","path":"svga/medals/exclusive-identity.svga","bytes":102165,"sha256":"018f1e7594f61c674d8f28e87bf12546cebc241543775bd1b388fc5a855e8957"},{"source":"assets/flutter_assets/assets/svga/medals/golden-royalty.svga","path":"svga/medals/golden-royalty.svga","bytes":618836,"sha256":"b66787888746e5dbbc17c7bc782cd247c3fbb627c7c049c04ad845ee2f0d9208"},{"source":"assets/flutter_assets/assets/svga/medals/grand-millionaire.svga","path":"svga/medals/grand-millionaire.svga","bytes":883259,"sha256":"3ee5f746e609f751e0119141633e8a3e2695f5206317b1ab9916549283de1353"},{"source":"assets/flutter_assets/assets/svga/medals/imperial-crown.svga","path":"svga/medals/imperial-crown.svga","bytes":769763,"sha256":"6fbf4e7f7b4192a44221d80c6ba24174d5261ab6852c9d6e2ddb42c5afe1a43f"},{"source":"assets/flutter_assets/assets/svga/medals/loyal-heart.svga","path":"svga/medals/loyal-heart.svga","bytes":904888,"sha256":"71cd5dd3a19aa77e396a81069f7015bdf318b3c5cd057b6e48354c897916b0d1"},{"source":"assets/flutter_assets/assets/svga/medals/millionaire.svga","path":"svga/medals/millionaire.svga","bytes":715536,"sha256":"010ad7bc9d81aed45e1b57381aeb236e3ec29e72743d65129a30845f02047d02"},{"source":"assets/flutter_assets/assets/svga/medals/room-guardian.svga","path":"svga/medals/room-guardian.svga","bytes":407077,"sha256":"b83b3fd380f65969dc0a5c8d6e2d2843fe85ccf6cf4355722b4b95c2e019d5c1"},{"source":"assets/flutter_assets/assets/svga/medals/ruby-legend.svga","path":"svga/medals/ruby-legend.svga","bytes":324356,"sha256":"e21f6581ca735649ef12210c2043a6446fc698e290843e752131119b81f631b9"},{"source":"assets/flutter_assets/assets/svga/medals/supreme-champion.svga","path":"svga/medals/supreme-champion.svga","bytes":451671,"sha256":"c4bd3e3263409486146dd3a9a9105ba127ea64448b145b6ac9ce057043c85bd2"},{"source":"assets/flutter_assets/assets/svga/medals/ultimate-supporter.svga","path":"svga/medals/ultimate-supporter.svga","bytes":438694,"sha256":"eb4ff285496eb336375c5271635bdf4a548aa246adb5f10df2bec39afa8a5f5e"},{"source":"assets/flutter_assets/assets/svga/profile-id-frame.svga","path":"svga/profile-id-frame.svga","bytes":54833,"sha256":"c31ea4ffe51837a09416ab21f4cd8a51e60da3efcdeea78d9d1aaa39f903b4c6"},{"source":"assets/flutter_assets/assets/videos/cp-nest-bg.mp4","path":"videos/cp-nest-bg.mp4","bytes":1224675,"sha256":"5c534ee14bb0153707ab0cba650b360ec2669db9cc6f646db174e77a30dfe781"}]''')

def verified_original(source: Path):
    data = source.read_bytes()
    if zipfile.is_zipfile(io.BytesIO(data)):
        with zipfile.ZipFile(io.BytesIO(data)) as pkg:
            if 'base.apk' in pkg.namelist():
                data = pkg.read('base.apk')
    actual = hashlib.sha256(data).hexdigest()
    if actual != EXPECTED_BASE_SHA256:
        raise ValueError('Original DangLive 1.1.17 base APK SHA-256 mismatch: ' + actual)
    return io.BytesIO(data)

def extract(source: Path, output_root: Path, zip_out: Path):
    files = []
    output_root.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(verified_original(source)) as base:
        if base.testzip() is not None:
            raise ValueError('Corrupt original base.apk CRC')
        for spec in EXPECTED:
            src = spec['source']
            if src not in base.namelist():
                raise ValueError('Missing exact original media path: ' + src)
            payload = base.read(src)
            checksum = hashlib.sha256(payload).hexdigest()
            if checksum != spec['sha256'] or len(payload) != spec['bytes']:
                raise ValueError('Integrity mismatch in: ' + src)
            dest = output_root / spec['path']
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(payload)
            files.append({
                'asset_path': 'assets/licensed_danglive_original/' + spec['path'],
                'source_asset_path': src,
                'bytes': len(payload),
                'sha256': checksum,
                'format': dest.suffix.lower().lstrip('.'),
                'functional_store_item': False,
            })
    if len(files) != 24:
        raise ValueError('Expected 24 original binaries')
    manifest = output_root / 'SOURCE_INVENTORY.json'
    manifest.write_text(json.dumps(files, indent=2) + '\n')
    with zipfile.ZipFile(zip_out, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=8) as archive:
        for file in sorted(output_root.rglob('*')):
            if file.is_file():
                archive.write(file, str(file.relative_to(output_root.parent)))
    print('Original 24 media extracted and SHA-256 verified:', zip_out)
    print('SVGA', sum(x['format'] == 'svga' for x in files),
          'PAG', sum(x['format'] == 'pag' for x in files),
          'MP4', sum(x['format'] == 'mp4' for x in files))
    print('Only source media were extracted. Collect/equip, playback, and PAG SDK are NOT certified.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source_apks', type=Path)
    parser.add_argument('--output-root', type=Path,
        default=Path('nimzo/assets/licensed_danglive_original'))
    parser.add_argument('--zip-out', type=Path,
        default=Path('nimzo-danglive-24-originals.zip'))
    args = parser.parse_args()
    extract(args.source_apks, args.output_root, args.zip_out)
