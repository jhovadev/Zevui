#!/usr/bin/env python3
"""F6C native SQLite portability gate: no implicit SQLite vendor downloads.

Prerequisites: Zig 0.17.1; Node and compiled Initializr TypeScript; reviewed
vendored SQLite files in addons/storage-sqlite/vendor/. Run on each native OS.
Zig may fetch explicitly pinned DVUI packages on cache miss and writes Zig caches.
"""
from __future__ import annotations

import argparse
import json
import platform
import shutil
import subprocess
import sys
import tempfile
import time
import traceback
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addons/storage-sqlite"
VENDOR = ADDON / "vendor"
FILES = ("sqlite3.c", "sqlite3.h", "CHECKSUMS.json")


def run(*args: str, cwd: Path = ROOT, steps: list[dict] | None = None) -> None:
    """Run a build step; record a failed command before raising its error."""
    print("+", " ".join(args), f"(cwd={cwd})", flush=True)
    start = time.monotonic()
    result = {"argv": list(args), "cwd": str(cwd), "status": "passed"}
    try:
        subprocess.run(args, cwd=cwd, check=True)
    except (OSError, subprocess.CalledProcessError) as error:
        result["status"] = "failed"
        result["error"] = str(error)
        raise
    finally:
        result["duration_ms"] = round((time.monotonic() - start) * 1000)
        if steps is not None:
            steps.append(result)


def gate(*, system: bool, gui: bool, steps: list[dict] | None = None) -> None:
    def step(*args: str, cwd: Path = ROOT) -> None:
        run(*args, cwd=cwd, steps=steps)
    step(sys.executable, str(ROOT / "scripts/zig_preflight.py"))
    step(sys.executable, str(ADDON / "tools/vendor_sqlite.py"), "--check")
    if not (ROOT / "packages/initializr-core/dist/generator.js").is_file():
        raise RuntimeError("Compile Initializr TypeScript first: tsc -p packages/initializr-core/tsconfig.json")
    for mode in ("off", "bundled", *(("system",) if system else ())):
        step("zig", "build", "test", f"-Dsqlite={mode}", "-Doptimize=ReleaseSafe", cwd=ADDON)

    with tempfile.TemporaryDirectory(prefix="zevui-f6c-") as tmp:
        step("node", "packages/initializr-core/scripts/new.mjs", "sqlite-portability", "--addon", "sqlite", "--output", tmp)
        starter = Path(tmp) / "sqlite-portability"
        assert (starter / "mise.toml").read_text(encoding="utf-8") == '[tools]\nzig = "0.17.1"\n'
        dest = starter / "src/addons/sqlite_vendor"
        dest.mkdir(parents=True)
        for name in FILES:
            shutil.copyfile(VENDOR / name, dest / name)
        # Verify copied sources using the generated project's own provenance tool.
        step(sys.executable, "src/addons/sqlite_vendor.py", "--check", cwd=starter)
        for mode in ("off", "bundled", *(("system",) if system else ())):
            step("zig", "build", "test", f"-Dsqlite={mode}", "-Doptimize=ReleaseSafe", cwd=starter)
        if gui:
            # Full native SDL3/DVUI build (different from the isolated addon gate).
            step("zig", "build", "-Dsqlite=bundled", "-Dportable-gui=true", "-Doptimize=ReleaseSafe", cwd=starter)
    print("F6C SQLite native portability gate PASS", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--system", action="store_true", help="also link to host system SQLite3 (host must provide development libs)")
    parser.add_argument("--gui", action="store_true", help="also attempt a full native DVUI/SDL3 build")
    parser.add_argument("--report", type=Path, help="write a machine-readable pass/fail JSON report (including failures)")
    args = parser.parse_args()
    report: dict = {
        "schema_version": 1,
        "host": platform.platform(),
        "python_version": platform.python_version(),
        "zig_version_required": "0.17.1",
        "system": args.system,
        "gui": args.gui,
        "status": "failed",
        "steps": [],
        "error": None,
    }
    try:
        gate(system=args.system, gui=args.gui, steps=report["steps"])
    except Exception as error:
        report["error"] = {"type": type(error).__name__, "message": str(error)}
        print(f"F6C portability FAIL: {error}", file=sys.stderr)
        traceback.print_exc()
    else:
        report["status"] = "passed"
    if args.report is not None:
        try:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        except OSError as error:
            print(f"F6C portability report write failed: {error}", file=sys.stderr)
            return 1
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
