"""Run without Zig, SDL, Xcode or native compiler."""
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from sdk_doctor import requirements  # noqa: E402


class PreflightTests(unittest.TestCase):
    def test_apple_sdk_diagnosed_on_linux(self):
        notes, blockers = requirements("aarch64-macos", "Linux")
        self.assertTrue(any("Apple" in n for n in notes))
        self.assertTrue(any("macOS host" in b for b in blockers))

    def test_windows_gnu_does_not_claim_msvc_sdk(self):
        notes, blockers = requirements("x86_64-windows-gnu", "Linux")
        self.assertTrue(any("GNU ABI" in n for n in notes))
        self.assertFalse(any("MSVC" in b for b in blockers))

    def test_unknown_target_is_rejected(self):
        with self.assertRaises(ValueError):
            requirements("x86_64-windows-msvc;cat /etc/passwd", "Linux")


if __name__ == "__main__":
    unittest.main()
