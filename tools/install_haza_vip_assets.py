#!/usr/bin/env python3
"""Install 32 owner-approved Haza VIP/SVIP files into NIMZO, with pinned SHA256.

Run: python3 tools/install_haza_vip_assets.py NIMZO_Haza_VIP_SVIP_Approved_32_Assets.zip
No APK is built or signed by this tool. Keep membership ledger and users intact.
"""
from __future__ import annotations

import csv
import hashlib
import io
import pathlib
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEST = ROOT / "nimzo" / "assets" / "haza_membership"
EXPECTED_ZIP_SHA256 = "e0f224c29d5457199d76fb9031cb4fec44c131003d2799d8a55f082971eb5aab"
ASSET_PREFIX = "nimzo/assets/haza_membership/"
EXPECTED_COUNT = 32
EXPECTED_BADGES = {
    f"{ASSET_PREFIX}vip/ic_vip_tag_{tier}.png"
    for tier in range(1, 8)
}
EXPECTED_SCENES = {
    f"{ASSET_PREFIX}vip/ic_vip_bg_{tier}.webp"
    for tier in range(1, 5)
} | {
    f"{ASSET_PREFIX}vip/ic_vip_border_{tier}.webp"
    for tier in range(1, 5)
}
EXPECTED_SVIP = {
    f"{ASSET_PREFIX}svip/bg_svip_upgrade_dialog.webp",
    f"{ASSET_PREFIX}svip/ic_svip_privileges_bg.webp",
}

def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python3 tools/install_haza_vip_assets.py <approved-zip>")
        return 2
    archive = pathlib.Path(sys.argv[1]).expanduser().resolve()
    if not archive.is_file():
        raise FileNotFoundError(archive)
    data = archive.read_bytes()
    actual_hash = hashlib.sha256(data).hexdigest()
    if actual_hash != EXPECTED_ZIP_SHA256:
        raise ValueError("Unapproved/tampered Haza membership asset archive")
    ready: dict[str, bytes] = {}
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        if zf.testzip() is not None:
            raise ValueError("Haza VIP ZIP CRC verification failed")
        rows = list(csv.DictReader(
            io.StringIO(zf.read("SHA256_MANIFEST.csv").decode("utf-8"))
        ))
        if len(rows) != EXPECTED_COUNT:
            raise ValueError("Wrong VIP asset manifest length")
        names = {r["path"] for r in rows}
        if len(names) != EXPECTED_COUNT or not (
            EXPECTED_BADGES | EXPECTED_SCENES | EXPECTED_SVIP
        ).issubset(names):
            raise ValueError("Missing or duplicated approved VIP/SVIP media")
        if set(zf.namelist()) != names | {"SHA256_MANIFEST.csv"}:
            raise ValueError("VIP archive contains unexpected files")
        for row in rows:
            p = row["path"]
            if not p.startswith(ASSET_PREFIX):
                raise ValueError(f"Invalid asset target: {p}")
            parts = pathlib.PurePosixPath(p).parts
            if ".." in parts or len(parts) != 5 or parts[3] not in ("vip", "svip"):
                raise ValueError(f"Unsafe VIP asset path: {p}")
            if not p.lower().endswith((".png", ".webp", ".svg")):
                raise ValueError(f"Unsupported media format: {p}")
            item = zf.read(p)
            if (hashlib.sha256(item).hexdigest() != row["sha256"]
                or len(item) != int(row["bytes"])):
                raise ValueError(f"Original media checksum changed: {p}")
            ready[p] = item

    # Check every destination BEFORE writing anything.
    for p, item in ready.items():
        target = ROOT / p
        if target.exists() and target.read_bytes() != item:
            raise FileExistsError(f"Conflicting existing VIP asset: {target}")
    for p, item in ready.items():
        target = ROOT / p
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(item)
    print(f"PASS: installed {len(ready)} owner-approved Haza VIP/SVIP assets")
    print("Original 7 VIP badges, 4 background themes, 4 borders and SVIP decor present")
    print("No app accounts, purchases, VIP levels or wallet balances modified")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
