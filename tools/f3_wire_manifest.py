#!/usr/bin/env python3
"""F3 workspace wiring: preserve every existing Zig package URL and hash.

Usage: python3 tools/f3_wire_manifest.py
No user package source is modified. Atomic write, idempotent, fail closed.
"""
from __future__ import annotations

import os
from pathlib import Path
import re
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "build.zig.zon"
ANCHOR = "    .dependencies = .{\n"
ENTRY = '        .zevui = .{ .path = "framework" },\n'


def wire_manifest(path: Path = MANIFEST) -> bool:
    data = path.read_text(encoding="utf-8")
    if not (path.parent / "framework" / "build.zig.zon").is_file():
        raise ValueError("Missing framework/build.zig.zon; apply the F3 patch first")
    if data.count(ANCHOR) != 1:
        raise ValueError("Expected one standard .dependencies block; manifest unchanged")
    if re.search(r"(?m)^\s*\.zevui\s*=", data):
        if ENTRY not in data:
            raise ValueError("A different zevui dependency exists; review manually")
        return False
    updated = data.replace(ANCHOR, ANCHOR + ENTRY, 1)
    fd, tmp = tempfile.mkstemp(prefix=".build.zon-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as f:
            f.write(updated)
        os.chmod(tmp, path.stat().st_mode & 0o777)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)
    return True


if __name__ == "__main__":
    print("Added local .zevui package" if wire_manifest() else "Local .zevui already configured")
