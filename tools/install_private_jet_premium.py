#!/usr/bin/env python3
"""Install the user-approved NIMZO original photorealistic Private Jet asset."""
from pathlib import Path
import hashlib
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ZIP_NAME = 'NIMZO_Private_Jet_Premium_Artwork.zip'
TARGET = 'nimzo/assets/gifts/premium/private_jet.webp'
ARCHIVE_SHA256 = '22f3461fccb897757b6cdf7412bec0a8cf5d7210848d3b0d9860e64de439893d'
IMAGE_SHA256 = '6a6efc8eb6775a6250560ac2dfe085a20a0f5985bdbe934efaea270e2507f4fc'

def run(filename: str = ZIP_NAME) -> None:
    archive = ROOT / filename
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA256:
        raise ValueError('The approved NIMZO image archive did not match its original SHA256')
    with zipfile.ZipFile(archive) as zf:
        if zf.namelist() != [TARGET] or zf.testzip() is not None:
            raise ValueError('Unexpected image archive contents or broken ZIP')
        photo = zf.read(TARGET)
    if hashlib.sha256(photo).hexdigest() != IMAGE_SHA256:
        raise ValueError('The original NIMZO Private Jet image did not match its SHA256')
    if photo[:4] != b'RIFF' or photo[8:12] != b'WEBP':
        raise ValueError('Not a valid WebP asset header')
    dst = ROOT / TARGET
    if dst.exists() and dst.read_bytes() != photo:
        raise ValueError('An incompatible Private Jet image already exists')
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(photo)
    print('PASS: original NIMZO premium Private Jet image installed.')

if __name__ == '__main__':
    run(sys.argv[1] if len(sys.argv) > 1 else ZIP_NAME)
