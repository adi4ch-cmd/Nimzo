#!/usr/bin/env python3
"""Import known MIT-licensed free gifts from pinned upstream GitHub blobs.
No user data, gift prices, balances or backend tables are modified here.
"""
from pathlib import Path
import hashlib
import io
import sys
import zlib
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "nimzo/assets/gifts/free"
INPUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/tmp/nimzo_free_gifts")
PINNED = {
    "heart.png": "c3bad7ca779313e3c83fdc6c2b24c4f4cbf3266f",
    "rose.png": "f73699b0ac57017ce3390038e46ecdcc23ccf085",
    "diamond.png": "ed5f053afcd14494f0b882a946a8cc9bf61314b3",
    "crown.png": "6da77937df669be860074d07292b956e4616bc84",
    "rocket.png": "ca74e8b2788ccc0669e7df1c67d3e2b7e81acc3c",
    "rocket.svga": "437169c38893c0f2150138eebcdc71b157ce6a44",
    "sports_car.svga": "7b5ce3b1fdb1915bfb872a30735ff7c7259d069d",
}


def parse_fields(buf):
    """Simple read-only protobuf wire parser, no decoding of external instructions."""
    ix = 0

    def varint():
        nonlocal ix
        out = 0
        for shift in range(0, 70, 7):
            if ix >= len(buf):
                raise ValueError("Malformed protobuf varint")
            b = buf[ix]
            ix += 1
            out |= (b & 0x7F) << shift
            if b < 128:
                return out
        raise ValueError("Varint too large")

    while ix < len(buf):
        header = varint()
        field, wire = header >> 3, header & 7
        if wire == 0:
            value = varint()
        elif wire == 1:
            value, ix = buf[ix:ix+8], ix+8
        elif wire == 2:
            length = varint()
            if length > len(buf) - ix:
                raise ValueError("Invalid protobuf length")
            value, ix = buf[ix:ix+length], ix+length
        elif wire == 5:
            value, ix = buf[ix:ix+4], ix+4
        else:
            raise ValueError(f"Unsupported protobuf wire {wire}")
        yield field, value


def extract_sprites(data):
    raw = zlib.decompress(data)
    images = {}
    for key, value in parse_fields(raw):
        if key != 3:
            continue
        entry = dict(parse_fields(value))
        if 1 not in entry or 2 not in entry:
            continue
        name = entry[1].decode("utf-8", errors="replace")[:180]
        payload = entry[2]
        try:
            img = Image.open(io.BytesIO(payload)).convert("RGBA")
            if img.width > 32 and img.height > 32:
                images[name] = img
        except Exception:
            pass
    return images


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for name, sha in PINNED.items():
        blob = (INPUT / name).read_bytes()
        actual = hashlib.sha1(f"blob {len(blob)}\0".encode()+blob).hexdigest()
        if sha != actual:
            raise ValueError(f"Upstream asset mismatch: {name}: {actual}")
        if name.endswith(".png"):
            Image.open(io.BytesIO(blob)).verify()
        else:
            if not blob.startswith((b"x\x9c", b"x\xda", b"x\x01")):
                raise ValueError(f"SVGA is not a zlib movie: {name}")
            if not extract_sprites(blob):
                raise ValueError(f"No usable sprites inside {name}")
        out = DEST / name
        if out.exists() and out.read_bytes() != blob:
            raise ValueError(f"Refusing to overwrite modified file: {name}")
        out.write_bytes(blob)
        print(name, len(blob), sha)

    images = extract_sprites((DEST/"sports_car.svga").read_bytes())
    if "seq_0_110" not in images:
        raise ValueError("Source animation lacks verified Sports Car sprite frame")
    photo = images["seq_0_110"].copy()
    photo.thumbnail((512, 512), Image.Resampling.LANCZOS)
    photo.save(DEST / "sports_car.png", optimize=True)
    ranked = sorted(images.items(), key=lambda v: v[1].width*v[1].height, reverse=True)
    print("SPORTS_CAR_SPRITES", [(k, im.size) for k, im in ranked[:30]])
    candidates = ranked[:30]
    tile = 220
    sheet = Image.new("RGB", (tile * 5, tile * ((len(candidates)+4)//5)), "#22232c")
    d = ImageDraw.Draw(sheet)
    for idx, (name, sprite) in enumerate(candidates):
        x, y = (idx%5)*tile, (idx//5)*tile
        im = sprite.copy()
        im.thumbnail((tile - 24, tile - 55), Image.Resampling.LANCZOS)
        bg = Image.new("RGBA", im.size, "#292d42")
        bg.alpha_composite(im)
        sheet.paste(bg.convert("RGB"), (x + (tile-im.width)//2, y+8))
        d.text((x+6,y+tile-42), name[:27], fill="white")
        d.text((x+6,y+tile-24), str(sprite.size), fill="#ddd")
    sheet.save("/tmp/nimzo_free_sports_car_sprite_preview.jpg", quality=88)

    (DEST/"LICENSE_SOURCES.md").write_text("""# Free gift asset licenses and pinned upstream sources

The following files are redistributed from third-party repositories that
provide their source under the MIT License. Retain upstream copyright and
permission notices. This does NOT authorize copying third-party brand marks.

* heart.png, rose.png, diamond.png, crown.png, rocket.png,
  rocket.svga: AgoraIO-Usecase/agora-live at
  0651c5f04f965015221232afc2a1e834287f65bc
  https://github.com/AgoraIO-Usecase/agora-live/blob/main/LICENSE
  Copyright (c) 2023 Agora.io Usecase (MIT)
* sports_car.svga: Tencent-RTC/TUILiveKit at
  c00fa47f3b2cfd29268c811c169b8cd91a95b8e7
  https://github.com/Tencent-RTC/TUILiveKit/blob/main/LICENSE
  Copyright (c) 2024 Tencent RTC Community (MIT)

The animation files are source demo media, not proof of proprietary Hilo/Yo2
gift art. Keep source attribution and the upstream license files.
""")
    print("Imported verified originals; generated separate sprite preview")


if __name__ == "__main__":
    main()
