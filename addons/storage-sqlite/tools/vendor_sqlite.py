#!/usr/bin/env python3
"""One-time, explicitly invoked SQLite vendor bootstrap (never part of zig build)."""
from __future__ import annotations
import argparse
import hashlib
import json
import sys
import tempfile
import urllib.request
import zipfile
from io import BytesIO
from pathlib import Path

VERSION = "3.54.1"
ARCHIVE_ROOT = "sqlite-amalgamation-3540100"
URL = f"https://www.sqlite.org/2026/{ARCHIVE_ROOT}.zip"
SHA3_256 = "92281c86e2957f9b9305890f9ac04204caa7b677cc868dc326d942689df28e30"
VENDOR = Path(__file__).resolve().parents[1] / "vendor"
FILES = ("sqlite3.c", "sqlite3.h")


def check_vendor() -> None:
    manifest = json.loads((VENDOR / "CHECKSUMS.json").read_text(encoding="utf-8"))
    if manifest.get("version") != VERSION or manifest.get("sha3_256_archive") != SHA3_256:
        raise ValueError("Vendor provenance/version is not pinned")
    for filename in FILES:
        path = VENDOR / filename
        expected = manifest["files"][filename]
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError(f"Vendor file differs from pinned SHA-256: {filename}")
    print(f"SQLite {VERSION} vendored source verified")


def download() -> None:
    if any((VENDOR / filename).exists() for filename in (*FILES, "CHECKSUMS.json")):
        raise ValueError("Vendor files already exist; use --check or explicitly remove after review")
    request = urllib.request.Request(URL, headers={"User-Agent": "zevui-vendor-sqlite/0.1"})
    with urllib.request.urlopen(request, timeout=30) as response:
        blob = response.read(7_000_001)
    if len(blob) > 7_000_000:
        raise ValueError("Unexpectedly large SQLite vendor archive")
    if hashlib.sha3_256(blob).hexdigest() != SHA3_256:
        raise ValueError("SQLite official SHA3-256 mismatch; NOTHING EXTRACTED")
    with zipfile.ZipFile(BytesIO(blob)) as zf:
        data = {}
        for name in FILES:
            member = zf.getinfo(f"{ARCHIVE_ROOT}/{name}")
            if not 0 < member.file_size < 25_000_000:
                raise ValueError(f"Unexpected source file size: {name}")
            data[name] = zf.read(member)
    VENDOR.mkdir(parents=True, exist_ok=True)
    checksums = {name: hashlib.sha256(data[name]).hexdigest() for name in FILES}
    meta = {"version": VERSION, "url": URL, "sha3_256_archive": SHA3_256, "files": checksums}
    # Write after all checks. An interrupted write may leave partial vendor files,
    # which --check rejects and cannot be treated as a successful bootstrap.
    with tempfile.TemporaryDirectory(dir=VENDOR) as stage:
        tempdir = Path(stage)
        for name in FILES:
            (tempdir / name).write_bytes(data[name])
        (tempdir / "CHECKSUMS.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
        for name in (*FILES, "CHECKSUMS.json"):
            (tempdir / name).replace(VENDOR / name)
    check_vendor()


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--check", action="store_true", help="verify an already downloaded vendor tree")
    args = p.parse_args()
    try:
        if args.check:
            check_vendor()
        else:
            download()
        return 0
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as exc:
        print(f"SQLite vendor: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
