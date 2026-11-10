"""No Zig or just required: validate supported target contract."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("zdata_targets", ROOT / "scripts" / "targets.py")
targets = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(targets)


class TargetContractTests(unittest.TestCase):
    def test_six_explicit_desktop_targets(self):
        self.assertEqual(len(targets.TARGETS), 6)
        for target in targets.TARGETS:
            self.assertEqual(targets.validate(target), targets.TARGETS[target])

    def test_rejects_foreign_input_and_injection(self):
        for invalid in ("", "arm-linux", "x86_64-linux-gnu;rm -rf .", "../escape", "aarch64-ios"):
            with self.subTest(target=invalid):
                with self.assertRaises(ValueError):
                    targets.validate(invalid)

    def test_macos_is_marked_sdk_required(self):
        self.assertEqual(targets.validate("aarch64-macos")[2], "SDK required")

    def test_just_recipes_wired_to_validation(self):
        justfile = (ROOT / "justfile").read_text()
        self.assertIn('python3 scripts/targets.py "$1"', justfile)
        self.assertIn('zig build test-compile -Dtarget="$1"', justfile)
        self.assertIn('zig build -Dtarget="$1"', justfile)


if __name__ == "__main__":
    unittest.main()
