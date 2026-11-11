#!/usr/bin/env python3
"""F6C native SQLite portability gate: no implicit SQLite vendor downloads.

Prerequisites: Zig 0.17.1; Node and compiled Initializr TypeScript; reviewed
vendored SQLite files in addons/storage-sqlite/vendor/. Run on each native OS.
Zig may fetch explicitly pinned DVUI packages on cache miss and writes Zig caches.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addons/storage-sqlite"
VENDOR = ADDON / "vendor"
FILES = ("sqlite3.c", "sqlite3.h", "CHECKSUMS.json")


def run(*args: str, cwd: Path = ROOT) -> None:
    print("+", " ".join(args), f"(cwd={cwd})", flush=True)
    subprocess.run(args, cwd=cwd, check=True)


def gate(*, system: bool, gui: bool) -> None:
    run(sys.executable, str(ROOT / "scripts/zig_preflight.py"))
    run(sys.executable, str(ADDON / "tools/vendor_sqlite.py"), "--check")
    if not (ROOT / "packages/initializr-core/dist/generator.js").is_file():
        raise RuntimeError("Compile Initializr TypeScript first: tsc -p packages/initializr-core/tsconfig.json")
    for mode in ("off", "bundled", *(("system",) if system else ())):
        run("zig", "build", "test", f"-Dsqlite={mode}", "-Doptimize=ReleaseSafe", cwd=ADDON)

    with tempfile.TemporaryDirectory(prefix="zevui-f6c-") as tmp:
        run("node", "packages/initializr-core/scripts/new.mjs", "sqlite-portability", "--addon", "sqlite", "--output", tmp)
        starter = Path(tmp) / "sqlite-portability"
        assert (starter / "mise.toml").read_text(encoding="utf-8") == '[tools]\nzig = "0.17.1"\n'
        dest = starter / "src/addons/sqlite_vendor"
        dest.mkdir(parents=True)
        for name in FILES:
            shutil.copyfile(VENDOR / name, dest / name)
        # Verify copied sources using the generated project's own provenance tool.
        run(sys.executable, "src/addons/sqlite_vendor.py", "--check", cwd=starter)
        for mode in ("off", "bundled", *(("system",) if system else ())):
            run("zig", "build", "test", f"-Dsqlite={mode}", "-Doptimize=ReleaseSafe", cwd=starter)
        if gui:
            # Full native SDL3/DVUI build (different from the isolated addon gate).
            run("zig", "build", "-Dsqlite=bundled", "-Dportable-gui=true", "-Doptimize=ReleaseSafe", cwd=starter)
    print("F6C SQLite native portability gate PASS", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--system", action="store_true", help="also link to host system SQLite3 (host must provide development libs)")
    parser.add_argument("--gui", action="store_true", help="also attempt a full native DVUI/SDL3 build")
    args = parser.parse_args()
    try:
        gate(system=args.system, gui=args.gui)
        return 0
    except (OSError, subprocess.CalledProcessError, RuntimeError, AssertionError) as error:
        print(f"F6C portability FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
