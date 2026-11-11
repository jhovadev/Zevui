"""F6B.1: prove toolchain mismatch errors are caught before native builds."""
from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "scripts" / "zig_preflight.py"


class ZigToolchainPreflight(unittest.TestCase):
    def run_fake_zig(self, version: str, status: int = 0) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as tmp:
            binary = Path(tmp) / "zig"
            binary.write_text(
                "#!/bin/sh\n"
                'if [ "$1" != version ]; then exit 97; fi\n'
                f"printf '%s\\n' '{version}'\n"
                f"exit {status}\n",
                encoding="utf-8",
            )
            binary.chmod(0o755)
            return subprocess.run(
                [sys.executable, str(SCRIPT), "--zig", str(binary)],
                capture_output=True, text=True, check=False,
            )

    def test_accepts_exact_pin(self):
        result = self.run_fake_zig("0.17.1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("toolchain OK", result.stdout)

    def test_rejects_older_zig_with_actionable_diagnostic(self):
        result = self.run_fake_zig("0.16.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires Zig 0.17.1", result.stderr)
        self.assertIn("type -a zig", result.stderr)
        self.assertIn("zig-pkg", result.stderr)

    def test_rejects_dev_builds_and_unexpected_versions(self):
        for version in ("0.17.0-dev.100", "0.17.2", "0.17.1-dev.3"):
            with self.subTest(version=version):
                self.assertNotEqual(self.run_fake_zig(version).returncode, 0)

    def test_rejects_nonzero_exit_even_on_expected_output(self):
        result = self.run_fake_zig("0.17.1", status=2)
        self.assertNotEqual(result.returncode, 0)

    def test_rejects_missing_executable(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--zig", "/nonexistent/zevui-zig"],
            capture_output=True, text=True, check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not found", result.stderr)

    def test_just_recipes_gate_native_builds(self):
        just = (REPO / "justfile").read_text(encoding="utf-8")
        for recipe in ("check", "addons-check", "sqlite-addon-check", "sqlite-bundled-check", "sqlite-initializr-check", "minimal", "framework-check", "build"):
            with self.subTest(recipe=recipe):
                self.assertIn(f"@{recipe}:\n    just zig-preflight\n", just)


if __name__ == "__main__":
    unittest.main()
