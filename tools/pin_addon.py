#!/usr/bin/env python3
"""Pin or verify a published Zig addon with the *real* `zig fetch` content hash.

Never guesses hashes. Does not execute user-controlled shell commands; `zig fetch`
is invoked with argv. No network is used by registry-build/check itself.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HASH_LINE = re.compile(r"^[A-Za-z0-9._+-]{20,200}$")


def fetch_hash(url: str, zig: str) -> str:
    if not url.startswith(("git+https://", "https://")) or any(c.isspace() for c in url) or len(url) > 2048:
        raise ValueError("URL must be a non-whitespace git+https:// or https:// address")
    if url.startswith("git+https://") and not re.search(r"#[0-9a-fA-F]{40}$", url):
        raise ValueError("Git addon URLs must pin a full commit SHA (#40 hex), not a mutable branch")
    result = subprocess.run([zig, "fetch", url], capture_output=True, text=True, check=True, timeout=180)
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if len(lines) != 1 or not HASH_LINE.fullmatch(lines[0]):
        raise ValueError("Unexpected zig fetch hash output; refusing to pin")
    return lines[0]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("id", choices=["memory_store", "design_tokens"])
    parser.add_argument("--url", help="immutable tarball URL or git+https ref pinned to commit SHA")
    parser.add_argument("--zig", default="zig", help="Zig 0.17.1 binary")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true", help="write real URL/hash to manifest")
    group.add_argument("--verify", action="store_true", help="fetch and compare existing immutable pin")
    args = parser.parse_args(argv)
    directory = {"memory_store": "memory-store", "design_tokens": "design-tokens"}[args.id]
    manifest_path = ROOT / "addons" / directory / "addon.json"
    try:
        data = json.loads(manifest_path.read_text())
        stored = data.get("package")
        if args.verify:
            if stored is None:
                raise ValueError("No published pin recorded; use --write --url after publishing")
            if args.url and args.url != stored["url"]:
                raise ValueError("Provided URL does not match the recorded immutable pin")
            url = stored["url"]
        else:
            if not args.url:
                raise ValueError("--write requires --url")
            if stored is not None and stored["url"] != args.url:
                raise ValueError("A pin already exists; review changes manually before replacing")
            url = args.url
        actual = fetch_hash(url, args.zig)
        if args.verify:
            if actual != stored["hash"]:
                raise ValueError(f"Pin mismatch for {args.id}: fetched hash differs from manifest")
            print(f"Verified content pin for {args.id}: {actual}")
        else:
            if stored is not None and stored["hash"] != actual:
                raise ValueError("Existing pin differs from fetched content; refusing silent repin")
            data["package"] = {"url": url, "hash": actual}
            # Do not toggle 'delivery' to 'package': F5 owns the consumer/build changes.
            manifest_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
            print(f"Pinned {args.id} to Zig content hash {actual}; run registry-build after review")
        return 0
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as exc:
        print(f"pin-addon: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
