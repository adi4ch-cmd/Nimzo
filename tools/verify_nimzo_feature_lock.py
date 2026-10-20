#!/usr/bin/env python3
"""Non-destructive NIMZO feature-lock source and Flutter asset guard."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "nimzo"
LOCK = APP / "FEATURES.lock.json"


def main() -> None:
    config = json.loads(LOCK.read_text(encoding="utf-8"))
    failures = []
    if config.get("schema_version") != 1:
        failures.append("Unsupported FEATURES.lock.json schema_version")
    pubspec = (APP / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$", pubspec, re.M)
    if not match:
        failures.append("pubspec.yaml version is missing or invalid")
    else:
        actual = tuple(map(int, match.groups()))
        minimum = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)\+(\d+)", config["min_app_version"])
        if minimum is None or actual < tuple(map(int, minimum.groups())):
            failures.append("pubspec.yaml version must be at least " + config["min_app_version"])

    for name in config.get("required_files", []):
        rel = Path(name)
        if rel.is_absolute() or ".." in rel.parts:
            failures.append("Unsafe locked path: " + name)
            continue
        path = ROOT / rel
        if not path.is_file() or path.stat().st_size == 0:
            failures.append("Missing or empty locked file: " + name)

    declarations = {line.strip() for line in pubspec.splitlines()}
    for asset in config.get("required_flutter_assets", []):
        if "- " + asset not in declarations:
            failures.append("Missing Flutter pubspec asset declaration: " + asset)
        if not (APP / asset).is_dir():
            failures.append("Missing Flutter asset directory: " + asset)

    for name, tokens in config.get("required_source_tokens", {}).items():
        path = ROOT / name
        if not path.is_file():
            failures.append("Missing source contract file: " + name)
            continue
        source = path.read_text(encoding="utf-8")
        for token in tokens:
            if token not in source:
                failures.append("Missing source contract: " + name + " => " + token)

    if failures:
        for failure in failures:
            print("FEATURE LOCK ERROR:", failure)
        raise SystemExit("NIMZO feature lock failed with " + str(len(failures)) + " issue(s)")
    print("NIMZO feature lock PASS:", len(config["required_files"]),
          "source files and media,", len(config["required_flutter_assets"]),
          "asset declarations, routes and integrations")


if __name__ == "__main__":
    main()
