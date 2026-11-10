"""Prevent asset paths that escape Zig module roots (Zig 0.17+)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class EmbeddedAssetContracts(unittest.TestCase):
    def test_brand_icon_is_inside_both_gui_and_identity_test_module(self):
        source = ROOT / "src/app/identity.zig"
        code = source.read_text()
        self.assertIn('@embedFile("assets/zevui.png")', code)
        self.assertTrue((source.parent / "assets/zevui.png").is_file())
        self.assertFalse((ROOT / "assets/branding/zevui.png").exists())

    def test_all_embedded_file_paths_stay_inside_src(self):
        module_root = (ROOT / "src").resolve()
        for source in (ROOT / "src").rglob("*.zig"):
            content = source.read_text()
            for relative in re.findall(r'@embedFile\("([^\"]+)"\)', content):
                with self.subTest(source=source.name, relative=relative):
                    resolved = (source.parent / relative).resolve()
                    self.assertTrue(resolved.is_relative_to(module_root))
                    self.assertTrue(resolved.is_file(), resolved)


if __name__ == '__main__':
    unittest.main()
