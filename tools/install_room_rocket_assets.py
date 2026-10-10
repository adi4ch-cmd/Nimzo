#!/usr/bin/env python3
"""Install the 12 user-supplied Rocket VAP videos with SHA256 verification.

Run from the Nimzo repository root, *after* uploading
NIMZO_Room_Rocket_12_VAP_Assets.zip there. Does not run or build an APK.
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
MEDIA = ROOT / "nimzo" / "assets" / "room_rocket"
EXPECTED = {
    "vap_rocket_fly_1.mp4": "c82c04d3136c57949e0507fbaff1a3c66fe859e29deed2ac64f6cd60ee13aadc",
    "vap_rocket_reward_1.mp4": "0188090003c1f42bfb1d47e352b62f15ca67c0931864af57b6a7a881d76b115e",
    "vap_rocket_fly_2.mp4": "b1ecd9a861e5eebd535b73b962a365cfb701cef2980761770eff0399181878eb",
    "vap_rocket_reward_2.mp4": "1cf36d4a7ec75216e4a74ede6375a842f009d7613507f0e04a83a90cd57b5f38",
    "vap_rocket_fly_3.mp4": "2a96acf80c34bb530df39dad96d1c3e7799c5f6b8ac02966d6e70b87800988c5",
    "vap_rocket_reward_3.mp4": "352642effd22491cff2bed42cb74ff989f0a18764af628bf5394a09e991c122b",
    "vap_rocket_fly_4.mp4": "d7884cf6a2597926c52cd40f696e6f9e700bebd84693631d8245f821b9f43ddb",
    "vap_rocket_reward_4.mp4": "cffd9eab89d89977800db96c3cccdc4d6fad2d88b22d46c866e81f995140924d",
    "vap_rocket_fly_5.mp4": "8de2958cbc3edbefc8af30ac7635104f9bf9e96928defbe4724a53b0bfdd9aac",
    "vap_rocket_reward_5.mp4": "744bd8f9b9608c9d72d3d3639f49b86d43e0e4d627a86151c3b774948b021ae9",
    "vap_rocket_fly_6.mp4": "5a04a93e919bbd44d9818d0e6bf0512b20ae9bd3c67532a7531ab5d606ed19a8",
    "vap_rocket_reward_6.mp4": "146aea9c91eefe10dc0802a7da838b4b53a2629667fe71fd6ae89005a17deb92",
}


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python3 tools/install_room_rocket_assets.py <asset_pack.zip>")
        return 2
    archive = pathlib.Path(sys.argv[1]).expanduser().resolve()
    if not archive.is_file():
        print(f"ZIP not found: {archive}")
        return 2

    # Validate every clip and hash BEFORE installing any bytes; partial
    # extraction would make it appear that some levels are complete.
    ready: dict[str, bytes] = {}
    with zipfile.ZipFile(archive) as zf:
        for name, checksum in EXPECTED.items():
            rel = f"nimzo/assets/room_rocket/{name}"
            data = zf.read(rel)
            if hashlib.sha256(data).hexdigest() != checksum:
                raise ValueError(f"SHA256 mismatch for {name}")
            if b"vapc" not in data:
                raise ValueError(f"Missing VAP alpha-video metadata: {name}")
            ready[name] = data
    MEDIA.mkdir(parents=True, exist_ok=True)
    for name, data in ready.items():
        dest = MEDIA / name
        if dest.exists() and dest.read_bytes() != data:
            raise FileExistsError(f"Different media already installed: {dest}")
    for name, data in ready.items():
        (MEDIA / name).write_bytes(data)
    print("Verified and installed all 12 original Rocket VAP videos.")
    print("Run flutter analyze + flutter test before any final APK.")
    print("Do not redistribute these source media without suitable permission.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
