#!/usr/bin/env python3
"""Check the exact Zig toolchain supported by this Zevui snapshot.

Version errors can appear in transitive build scripts (DVUI, Aro, translate_c),
which makes them look like SQLite C compilation failures. This check runs
before any Zig build and intentionally never writes to or modifies the toolchain.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

EXPECTED = "0.17.1"


def verify(zig: str) -> tuple[bool, str]:
    candidate = shutil.which(zig)
    if candidate is None:
        return False, f"Zig executable not found: {zig!r}. Check PATH (`type -a zig`)."
    try:
        result = subprocess.run(
            [candidate, "version"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, f"Could not execute {candidate!r} version: {exc}"

    version = result.stdout.strip()
    if result.returncode != 0 or version != EXPECTED:
        reported = version or result.stderr.strip() or f"exit code {result.returncode}"
        return False, (
            f"Zevui requires Zig {EXPECTED}; got {reported!r} from "
            f"{str(Path(candidate).resolve())!r}.\n"
            "Inspect `type -a zig`, `zig version`, and `zig env`. "
            "Select a single Zig 0.17.1 installation before rebuilding.\n"
            "Do not edit generated zig-pkg/ or third-party package caches."
        )
    return True, f"Zig toolchain OK: {EXPECTED} ({Path(candidate).resolve()})"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zig", default="zig", help="Zig executable/path; defaults to PATH")
    args = parser.parse_args(argv)
    ok, message = verify(args.zig)
    print(message, file=sys.stdout if ok else sys.stderr)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
