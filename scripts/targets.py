#!/usr/bin/env python3
"""Documented desktop cross targets. Only validates requested triples.

This does NOT test host toolchain availability or guarantee a successful SDL3
cross build. Running foreign executables is never attempted.
"""
from __future__ import annotations

import argparse
import sys

# Explicit allowlist prevents shell injection in the justfile's target and path.
TARGETS = {
    "x86_64-linux-gnu": ("Linux", "x86-64", "experimental"),
    "aarch64-linux-gnu": ("Linux", "ARM64", "experimental"),
    "x86_64-windows-gnu": ("Windows", "x86-64", "experimental"),
    "aarch64-windows-gnu": ("Windows", "ARM64", "experimental"),
    "x86_64-macos": ("macOS", "x86-64", "SDK required"),
    "aarch64-macos": ("macOS", "ARM64", "SDK required"),
}


def validate(target: str) -> tuple[str, str, str]:
    """Reject unknown targets before passing them to Zig or output paths."""
    if target not in TARGETS:
        raise ValueError(f"unsupported target {target!r}; run `just targets`")
    return TARGETS[target]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", nargs="?", help="Zig target triple")
    parser.add_argument("--list", action="store_true", help="show target table")
    args = parser.parse_args(argv)
    if args.list:
        print("Target                         OS       Arch      Status")
        for name, (os_name, arch, status) in TARGETS.items():
            print(f"{name:<30} {os_name:<8} {arch:<9} {status}")
        return 0
    if not args.target:
        parser.error("provide a target or use --list")
    try:
        os_name, arch, status = validate(args.target)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    print(f"Target: {args.target} ({os_name}, {arch}); status: {status}")
    if os_name == "macOS":
        print("Note: DVUI/SDL3 may require Apple SDK headers and frameworks.")
    else:
        print("Note: cross-compilation is experimental until verified on CI/host.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
