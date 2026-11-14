#!/usr/bin/env python3
"""F9.3: exercise the compiled Zevui Zig CLI against an isolated Zig project.

No DVUI installation or network access required. The temporary project is created
by this script because `zevui init` intentionally configures an existing project.
"""
import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

COMPONENTS = ("calendar", "input", "checkbox", "heatmap")
BUILD_ZIG = 'const std = @import("std");\npub fn build(b: *std.Build) void { _ = b; }\n'


def call(cli: Path, *args: str, succeeds: bool = True) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run([str(cli), *args], capture_output=True, text=True, timeout=30, check=False)
    if (proc.returncode == 0) != succeeds:
        raise AssertionError(
            f"Unexpected return code {proc.returncode} for {args!r}:\n"
            f"stdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
        )
    return proc


def smoke(cli: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="zevui-f93-smoke-") as temp:
        project = Path(temp) / "zig-app"
        project.mkdir()

        # An empty directory is NOT a Zig project. Failure must be explicit
        # and leave the tree untouched.
        failure = call(cli, "init", "--project", str(project), succeeds=False)
        assert "build.zig" in failure.stderr, failure.stderr
        assert not (project / "zevui.components.json").exists()

        (project / "build.zig").write_text(BUILD_ZIG)
        call(cli, "init", "--project", str(project))
        config_path = project / "zevui.components.json"
        assert json.loads(config_path.read_text())["zig"] == "0.17.1"

        call(cli, "add", *COMPONENTS, "--project", str(project), "--dry-run")
        assert not (project / ".zevui/components.lock.json").exists()

        call(cli, "add", *COMPONENTS, "--project", str(project))
        lock_path = project / ".zevui/components.lock.json"
        lock_bytes = lock_path.read_bytes()
        lock = json.loads(lock_bytes)
        assert lock["schema"] == 1
        assert set(lock["components"]) == set(COMPONENTS), lock["components"].keys()

        file_count = 0
        for component in COMPONENTS:
            for relative, expected_sha in lock["components"][component]["files"].items():
                assert relative.startswith("src/components/")
                path = project / relative
                assert path.is_file(), relative
                assert hashlib.sha256(path.read_bytes()).hexdigest() == expected_sha, relative
                file_count += 1

        call(cli, "doctor", "--project", str(project))
        call(cli, "diff", "--project", str(project))

        # A user-edited source must not be overwritten, even by an update.
        edited = project / "src/components/calendar.zig"
        edited.write_bytes(edited.read_bytes() + b"\n// user edit: preserve this\n")
        edited_bytes = edited.read_bytes()
        call(cli, "doctor", "--project", str(project), succeeds=False)
        call(cli, "update", "calendar", "--project", str(project), succeeds=False)
        assert edited.read_bytes() == edited_bytes
        assert lock_path.read_bytes() == lock_bytes

        print(f"Zevui CLI smoke PASS: {len(COMPONENTS)} components, {file_count} Zig files, edits protected")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", required=True, type=Path, help="Path to a compiled Zig CLI")
    args = parser.parse_args()
    cli = args.cli.resolve(strict=True)
    if not cli.is_file():
        parser.error(f"CLI is not a file: {cli}")
    smoke(cli)


if __name__ == "__main__":
    main()
