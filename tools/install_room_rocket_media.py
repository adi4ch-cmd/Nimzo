#!/usr/bin/env python3
"""Install only verified Haza room Rocket VAP media into NIMZO.

Accepts either the original user-provided Haza 4.9.0 XAPK or the extracted
NIMZO_Room_Rocket_12_VAP_Assets.zip. No Android APK is built.
"""
import argparse
from io import BytesIO
from pathlib import Path
from tempfile import TemporaryDirectory
from zipfile import ZipFile

from verify_room_rocket_media import SHA256, verify

HAZA_PREFIX = "assets/flutter_assets/packages/room_voice/assets/vap/rocket/"
PACK_PREFIX = "nimzo/assets/room_rocket/"


def unpack(archive: Path, repo: Path) -> None:
    if not archive.is_file():
        raise FileNotFoundError(archive)
    with ZipFile(archive) as outer:
        names = set(outer.namelist())
        base = "com.tinytaala.chat.apk"
        is_xapk = base in names
        if not is_xapk and not all(PACK_PREFIX + n in names for n in SHA256):
            raise ValueError("Archive is not a matching Haza 4.9.0 XAPK or Rocket pack")
        inner = ZipFile(BytesIO(outer.read(base))) if is_xapk else outer
        try:
            with TemporaryDirectory() as td:
                root = Path(td)
                target = root / PACK_PREFIX
                target.mkdir(parents=True)
                for filename in SHA256:
                    source = HAZA_PREFIX + filename if is_xapk else PACK_PREFIX + filename
                    data = inner.read(source)
                    (target / filename).write_bytes(data)
                verify(root)  # exact per-clip hashes and VAP box, before any copy
                destination = repo / PACK_PREFIX
                destination.mkdir(parents=True, exist_ok=True)
                for filename in SHA256:
                    (destination / filename).write_bytes((target / filename).read_bytes())
                verify(repo)
        finally:
            if is_xapk:
                inner.close()
    print("Room Rocket VAP files installed and verified; no APK was built.")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--repo-root", type=Path,
                        default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    unpack(args.archive, args.repo_root)


if __name__ == "__main__":
    main()
