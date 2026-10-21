#!/usr/bin/env python3
"""Audit real Store assets inside supplied .apks/.apk files without publishing.

Never equate an extracted icon, game effect or source filename with an
approved/saleable product. Default mode creates a read-only report.
--stage verifies exact original bytes and copies eligible files to a local
staging directory; it NEVER changes Supabase, wallet, pubspec or production
Store catalog. An Android Flutter playback review remains mandatory.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile
import zipfile
import zlib

SUPPORTED = {"svga", "mp4", "png", "webp", "jpg", "jpeg"}
MAX_ASSET_BYTES = 32 * 1024 * 1024
HEX = re.compile(r"^[0-9a-f]{64}$")
PATH_PATTERN = re.compile(r"^([^!]+)!/([^!]+)$")
CATEGORIES = {
    "Avatar Frame": (
        re.compile(r"(?:avatar[_-]?frame|profile[_-]?frame|frame[_-]?avatar|"
                   r"head[_-]?frame|face[_-]?frame)", re.I),
        {"svga", "png", "webp"},
    ),
    "Chat Bubble": (
        re.compile(r"(?:chat[_-]?bubble|bubble[_-]?chat|msg[_-]?bubble|"
                   r"message[_-]?bubble)", re.I),
        {"svga", "png", "webp"},
    ),
    "Party Theme": (
        re.compile(r"(?:room[_-]?theme|chatroom[_-]?(?:bg|background)|"
                   r"room[_-]?background|party[_-]?theme)", re.I),
        {"svga", "png", "webp", "jpg", "jpeg"},
    ),
    "Mic Wave": (
        re.compile(r"(?:mic[_-]?wave|mic[_-]?seat[_-]?anim|"
                   r"mic[_-]?speaking[_-]?wave)", re.I),
        {"svga", "png", "webp"},
    ),
    "Rides": (
        re.compile(r"(?:user[_-]?entrance|vehicle[_-]?entry|"
                   r"ride[_-]?entrance|vehicle[_-]?entrance|"
                   r"car[_-]?entrance|user[_-]?entry[_-]?effect)", re.I),
        {"svga", "mp4"},
    ),
    "ID Frame": (
        re.compile(r"(?:id[_-]?frame|nameplate[_-]?frame|"
                   r"profile[_-]?id[_-]?frame)", re.I),
        {"svga", "png", "webp"},
    ),
}
# Aggressive exclusion: a visually appealing resource is not automatically
# an equipable Store item. Review source context and rights separately.
EXCLUDE = re.compile(
    r"(?:^|[/_-])(?:game|domino|teenpatti|ludo|jackpot|"
    r"rank[0-9]*|leaderboard|agency|owner|admin|badge|icon|tab|"
    r"svip|vip|trial|reward|prize|shop|purchase|gift|rocket|"
    r"celebration|broadcaster|online_notice|tutorial|demo)(?:$|[/_.-])",
    re.I,
)


def source_parts(raw: str) -> tuple[str, str] | None:
    """Expected original path: base.apk!/assets/full_name.svga"""
    match = PATH_PATTERN.fullmatch(raw)
    if match is None:
        return None
    container, name = match.groups()
    if not container.endswith(".apk"):
        return None
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or "\\" in name:
        return None
    return container, name


def category_for(path: str, fmt: str) -> str | None:
    if fmt not in SUPPORTED:
        return None
    basename = PurePosixPath(path).name
    # Android drawable/mipmap/UI state icons and Flutter density variants
    # are internal decoration assets, not complete user-equippable products.
    normalized = "/" + path.lower().lstrip("/")
    if (normalized.startswith("/res/") or
        "/2.0x/" in normalized or "/3.0x/" in normalized or
        "/icons/" in normalized or
        "_preview" in normalized or "_settled" in normalized or
        "_active" in normalized or
        basename.lower().startswith(("btn_", "ic_", "icon_", "bg_btn_"))):
        return None
    if EXCLUDE.search(path) or EXCLUDE.search(basename):
        return None
    hits = [name for name, (match, formats) in CATEGORIES.items()
            if fmt in formats and match.search(basename)]
    return hits[0] if len(hits) == 1 else None


def read_candidates(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("status") != "CANDIDATES_ONLY":
        raise ValueError("Unexpected candidate audit status")
    result = []
    for category, files in data.get("categories", {}).items():
        for item in files:
            raw = item.get("source", "")
            components = source_parts(raw)
            if not components:
                continue
            classified = category_for(components[1], item.get("format", ""))
            result.append({
                "source_package": item.get("package"),
                "source": raw,
                "candidate_from_audit": category,
                "proposed_store_category": classified,
                "format": item.get("format"),
                "bytes": item.get("bytes"),
                "sha256": item.get("sha256"),
                "audit_rights": item.get("rights"),
                "exclusion": None if classified is not None
                             else "not a confirmed Store-equipped asset",
            })
    return result


def discover_from_full_audit(path: Path) -> list[dict]:
    """The 91k-entry source can have nested layouts; recursively collect rows.

    Listing uses audit metadata as a hint only, never as proof that bytes work.
    """
    import gzip
    with gzip.open(path, "rt", encoding="utf-8") as source:
        payload = json.load(source)
    results = []
    stack = [(payload, None)]
    while stack:
        node, parent_package = stack.pop()
        if isinstance(node, list):
            stack.extend((entry, parent_package) for entry in node)
            continue
        if not isinstance(node, dict):
            continue
        parent_candidate = node.get("filename") or node.get("package")
        if isinstance(parent_candidate, str) and parent_candidate.endswith(".apks"):
            parent_package = parent_candidate
        original = node.get("source") or node.get("path")
        digest = node.get("sha256")
        if isinstance(original, str) and isinstance(digest, str):
            container = source_parts(original)
            fmt = str(node.get("format") or PurePosixPath(original).suffix.lstrip(".")).lower()
            if container and HEX.fullmatch(digest):
                cat = category_for(container[1], fmt)
                if cat is not None:
                    package = (node.get("package") or node.get("filename")
                               or node.get("source_package") or parent_package)
                    results.append({
                        "source_package": package,
                        "source": original,
                        "candidate_from_audit": node.get("category"),
                        "proposed_store_category": cat,
                        "format": fmt,
                        "bytes": node.get("bytes"),
                        "sha256": digest,
                        "audit_rights": "individual asset rights not proven by filename",
                        "exclusion": None,
                    })
        stack.extend((v, parent_package) for v in node.values()
                     if isinstance(v, (dict, list)))
    return results


class ApkSources:
    """Read nested base.apk only, cache each opened member once per archive."""
    def __init__(self, root: Path, extracted: Path | None = None):
        self.root = root
        self.extracted = extracted.resolve() if extracted else None
        self.extracted_index: dict[str, list[Path]] | None = None
        self.stack = contextlib.ExitStack()
        self.apks: dict[tuple[str, str], zipfile.ZipFile] = {}
        self.temp_root = Path(self.stack.enter_context(
            tempfile.TemporaryDirectory(prefix="nimzo-apk-review-")))

    def original_extracted_file(self, row: dict) -> bytes | None:
        if self.extracted is None or not self.extracted.is_dir():
            return None
        if self.extracted_index is None:
            self.extracted_index = {}
            visited = 0
            for directory, dirs, names in os.walk(self.extracted):
                dirs[:] = [d for d in dirs if d not in {
                    ".git", ".gradle", ".dart_tool", "node_modules",
                    "build", ".pub-cache", ".venv", "__pycache__"}]
                for name in names:
                    visited += 1
                    if visited > 300000:
                        raise ValueError("Extracted media index scan capped")
                    if Path(name).suffix.lower().lstrip(".") not in SUPPORTED:
                        continue
                    candidate = Path(directory) / name
                    if candidate.is_symlink():
                        continue
                    self.extracted_index.setdefault(name, []).append(candidate)
        parsed = source_parts(row["source"])
        if parsed is None:
            return None
        basename = PurePosixPath(parsed[1]).name
        for candidate in self.extracted_index.get(basename, []):
            try:
                if not candidate.resolve().is_relative_to(self.extracted):
                    continue
                size = candidate.stat().st_size
                if size < 1 or size > MAX_ASSET_BYTES:
                    continue
                if row["bytes"] is not None and size != int(row["bytes"]):
                    continue
                payload = candidate.read_bytes()
                if hashlib.sha256(payload).hexdigest() == row["sha256"]:
                    return payload
            except OSError:
                continue
        return None

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.stack.close()

    def inner(self, package_name: str, apk_name: str) -> zipfile.ZipFile:
        key = package_name, apk_name
        if key in self.apks:
            return self.apks[key]
        outer_path = self.root / PurePosixPath(package_name).name
        if not outer_path.is_file():
            raise FileNotFoundError(f"Source APKS missing: {outer_path}")
        outer = self.stack.enter_context(zipfile.ZipFile(outer_path))
        if apk_name not in outer.namelist():
            raise ValueError(f"Required {apk_name} missing from {package_name}")
        out = self.temp_root / (
            hashlib.sha256(f"{package_name}:{apk_name}".encode()).hexdigest()+".apk")
        with outer.open(apk_name) as source, out.open("wb") as target:
            shutil.copyfileobj(source, target, length=2**20)
        inner = self.stack.enter_context(zipfile.ZipFile(out))
        self.apks[key] = inner
        return inner

    def payload(self, row: dict) -> bytes:
        archive_name = row["source_package"]
        parsed = source_parts(row["source"])
        if parsed is None:
            raise ValueError("Original source member path not specified")
        if not isinstance(archive_name, str) or not (
                self.root / PurePosixPath(archive_name).name).is_file():
            original = self.original_extracted_file(row)
            if original is not None:
                return original
            raise FileNotFoundError(
                f"Original APKS missing and no matching extracted SHA256: "
                f"{archive_name} / {row['source']}")
        inner = self.inner(archive_name, parsed[0])
        member = inner.getinfo(parsed[1])
        if member.file_size < 1 or member.file_size > MAX_ASSET_BYTES:
            raise ValueError("Invalid/oversized Store media")
        if row["bytes"] is not None and member.file_size != int(row["bytes"]):
            raise ValueError("Source size differs from Codex inventory")
        with inner.open(member) as f:
            data = f.read(MAX_ASSET_BYTES + 1)
        if len(data) != member.file_size:
            raise ValueError("Truncated source data")
        if hashlib.sha256(data).hexdigest() != row["sha256"]:
            raise ValueError("SHA256 mismatch against original APK audit")
        return data


def verify_structural_media(data: bytes, kind: str) -> tuple[str, str]:
    """Container validation, not a claim of Android decoder success."""
    if kind == "svga":
        try:
            with zipfile.ZipFile(io.BytesIO(data)) as anim:
                names = set(anim.namelist())
                if "movie.binary" not in names:
                    raise ValueError("SVGA archive missing movie.binary")
                if anim.testzip() is not None:
                    raise ValueError("SVGA archive CRC failure")
                if anim.getinfo("movie.binary").file_size < 12:
                    raise ValueError("SVGA animation movie too small")
        except zipfile.BadZipFile:
            # Some SVGA producers use zlib-compressed protobuf.
            try:
                inflated = zlib.decompress(data)
            except zlib.error as exc:
                raise ValueError("SVGA format invalid") from exc
            if len(inflated) < 50:
                raise ValueError("SVGA animation empty")
        return "svga", "structure_only_flutter_decode_required"
    if kind == "mp4":
        if b"ftyp" not in data[:32]:
            raise ValueError("Invalid MP4 header")
        if b"vapc" not in data:
            raise ValueError("MP4 has no VAP alpha metadata; not a ride effect")
        return "vap", "structure_only_android_vap_playback_required"
    if kind == "png":
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError("PNG signature invalid")
    elif kind == "webp":
        if not (data[:4] == b"RIFF" and data[8:12] == b"WEBP"):
            raise ValueError("WEBP signature invalid")
    elif kind in ("jpg", "jpeg"):
        if not data.startswith(b"\xff\xd8\xff"):
            raise ValueError("JPEG signature invalid")
    else:
        raise ValueError("Unsupported Store media codec")
    return "image", "structure_only_flutter_render_required"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidates", type=Path, default=Path(
        "docs/validation/best-source-candidates-20261021.json"))
    parser.add_argument("--full-audit", type=Path, default=Path(
        "docs/validation/drive-media-audit-20261021.json.gz"))
    parser.add_argument("--existing", type=Path, default=Path(
        "nimzo/assets/premium_store/manifest.json"))
    parser.add_argument("--sources-dir", type=Path, default=Path(
        os.environ.get("NIMZO_APK_SOURCES", "/workspaces/nimzo-apk-sources")))
    parser.add_argument("--extracted-dir", type=Path,
                        default=Path(os.environ["NIMZO_EXTRACTED_DIR"])
                        if os.environ.get("NIMZO_EXTRACTED_DIR") else None,
                        help="Original Codex-extracted APK media tree (SHA checked)")
    parser.add_argument("--out", type=Path, default=Path(
        "nimzo/assets/staged_store_verified"))
    parser.add_argument("--report", type=Path, default=Path(
        "docs/validation/store-apk-stage-local.json"))
    parser.add_argument("--use-full-audit", action="store_true",
                        help="Include exact path/hash candidates found in all 91k entries")
    parser.add_argument("--stage", action="store_true",
                        help="Copy SHA-checked verified containers to local staging")
    args = parser.parse_args()
    existing = json.loads(args.existing.read_text(encoding="utf-8"))
    known = {row["sha256"] for row in existing}
    candidates = read_candidates(args.candidates)
    if args.use_full_audit:
        candidates += discover_from_full_audit(args.full_audit)
    distinct: dict[str, dict] = {}
    for candidate in candidates:
        digest = candidate.get("sha256")
        if not isinstance(digest, str) or not HEX.fullmatch(digest):
            continue
        if digest in known:
            continue
        original = distinct.get(digest)
        if original is None or (original.get("proposed_store_category") is None
                                and candidate.get("proposed_store_category")):
            distinct[digest] = candidate

    results = []
    with ApkSources(args.sources_dir, extracted=args.extracted_dir) as source:
        for row in sorted(distinct.values(), key=lambda r: (
                r.get("proposed_store_category") or "~", r["source"])):
            review = dict(row)
            review["status"] = "excluded_from_store"
            if row.get("proposed_store_category") is None:
                results.append(review)
                continue
            review["status"] = "awaiting_original_file"
            if not args.stage:
                results.append(review)
                continue
            try:
                data = source.payload(row)
                media_kind, status = verify_structural_media(data, row["format"])
                slug = hashlib.sha256(
                    (row["source_package"] + "/" + row["source"]).encode()
                ).hexdigest()[:14]
                suffix = ".mp4" if media_kind == "vap" else "." + row["format"]
                dest = args.out / row["proposed_store_category"].lower().replace(" ", "_") / (
                    "apk-" + slug + "-" + row["sha256"][:16] + suffix)
                dest.parent.mkdir(parents=True, exist_ok=True)
                if dest.exists() and hashlib.sha256(dest.read_bytes()).hexdigest() != row["sha256"]:
                    raise ValueError("Destination exists with different bytes")
                if not dest.exists():
                    dest.write_bytes(data)
                review.update({
                    "status": "staged_requires_native_review",
                    "media_kind": media_kind, "container_check": status,
                    "local_asset_path": dest.as_posix(),
                    "sellable": False,
                    "active": False,
                    "coin_price": None,
                    "rights_verified": False,
                })
            except (OSError, ValueError, zipfile.BadZipFile, KeyError) as exc:
                review["status"] = "blocked"
                review["reason"] = str(exc)[:240]
            results.append(review)
    summary = {
        "mode": "local_staging" if args.stage else "dry_run",
        "source_inventory": args.full_audit.as_posix() if args.use_full_audit
                            else args.candidates.as_posix(),
        "original_media_not_sold_or_activated": True,
        "existing_catalog_items_preserved": len(existing),
        "candidates_after_sha256_dedupe": len(results),
        "structurally_staged": sum(
            r["status"] == "staged_requires_native_review" for r in results),
        "blocked": sum(r["status"] == "blocked" for r in results),
        "requires": [
            "media owner commercial reuse approval for each asset",
            "Flutter device decode, animations, alpha and sound verification",
            "manual category/canvas review and entitlement/equipment tests",
            "admin-approved CDN/Storage publish and explicit price agreement",
        ],
        "entries": results,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(summary, indent=2, ensure_ascii=False)+"\n",
                           encoding="utf-8")
    print(json.dumps({k: v for k, v in summary.items() if k != "entries"},
                     indent=2))
    print("Audit saved:", args.report)
    if args.stage:
        print("New assets are LOCAL-ONLY and NOT live Store products.")


if __name__ == "__main__":
    main()
