#!/usr/bin/env python3
"""Read-only host/SDK preflight for DVUI + SDL3, not an installer.

A positive result says the *attempt* is supported, not that the binary will
link, package, start or pass a GUI smoke test on the target OS.
"""
from __future__ import annotations

import argparse
import platform
import shutil
import subprocess
import sys

from targets import validate


def requirements(target: str, host: str) -> tuple[list[str], list[str]]:
    os_name, _, _ = validate(target)
    notes: list[str] = ["Zig 0.17.1 + DVUI SDL3; optional components disabled by -Dportable-gui=true"]
    blockers: list[str] = []
    if os_name == "macOS":
        notes.append("macOS SDK / AppKit / Cocoa frameworks supplied by Apple (Xcode CLT or Xcode)")
        if host != "Darwin":
            blockers.append("Build the macOS GUI on a macOS host/runner with Xcode SDK; Linux does not provide Apple's headers or frameworks")
        elif not shutil.which("xcrun"):
            blockers.append("xcrun not found; install Xcode Command Line Tools, then run xcode-select -p")
        else:
            r = subprocess.run(["xcrun", "--sdk", "macosx", "--show-sdk-path"], capture_output=True, text=True)
            if r.returncode or not r.stdout.strip():
                blockers.append("macOS SDK not found by xcrun; select installed Xcode or CLT")
            else:
                notes.append("Apple SDK: " + r.stdout.strip())
        notes.append("Signing and notarization are release steps, not part of this compilation recipe")
    elif os_name == "Windows":
        notes.append("GNU ABI: Zig's target toolchain is the first attempt; no MSVC SDK promised")
        notes.append("Run on Windows to verify SDL renderer, libraries and UI input before release")
    else:
        notes.append("GNU libc target: verify glibc compatibility, system graphics drivers and display server on Linux")
        notes.append("Build-only cross targets must be exercised on native/VM/QEMU machines")
    if not shutil.which("zig"):
        blockers.append("zig is not on PATH (requires Zig 0.17.1)")
    return notes, blockers


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--target", required=True)
    p.add_argument("--require-build", action="store_true", help="Fail if an essential GUI SDK is missing")
    args = p.parse_args(argv)
    try:
        notes, blockers = requirements(args.target, platform.system())
    except ValueError as exc:
        p.error(str(exc))
    print(f"SDK preflight: {args.target} (host: {platform.system()})")
    for note in notes:
        print("  INFO: " + note)
    for blocker in blockers:
        print("  BLOCKER: " + blocker, file=sys.stderr)
    if blockers and args.require_build:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
