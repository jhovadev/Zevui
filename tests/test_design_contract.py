"""Static architecture contract checks; Zig itself exercises token internals."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DesignSystemContractTests(unittest.TestCase):
    def test_pure_tokens_have_no_dvui_dependency(self):
        source = (ROOT / "src/ui/tokens.zig").read_text()
        self.assertNotIn('@import("dvui")', source)
        self.assertNotIn('@import("zdata")', source)
        for token in ("graphite", "light", "contrast", "compact", "comfortable"):
            self.assertIn(token, source)

    def test_gui_uses_real_design_tokens(self):
        source = (ROOT / "src/main.zig").read_text()
        self.assertIn('ui/tokens.zig', source)
        self.assertIn('ui/dvui_style.zig', source)
        self.assertIn('hooks.useTheme(&state.appearance)', source)
        self.assertIn('fn pathBar(a: std.mem.Allocator)', source)
        self.assertIn('style.themeFor(state.appearance.mode)', source)

    def test_portable_profile_and_headless_zig_tests(self):
        build = (ROOT / "build.zig").read_text()
        zevui_build = (ROOT / "zevui/build.zig").read_text()
        checks = (ROOT / "examples/csv/build.zig").read_text()
        self.assertIn('b.option(bool, "portable-gui"', build)
        self.assertIn('.@"tiny-file-dialogs" = false', zevui_build)
        self.assertIn('b.path("src/ui/tokens.zig")', checks)
        self.assertIn('b.path("src/ui/hooks.zig")', checks)

    def test_docs_reference_sdk_preflight(self):
        just = (ROOT / "justfile").read_text()
        self.assertIn('sdk_doctor.py --target "$1" --require-build', just)
        self.assertIn('-Dportable-gui=true', just)
        self.assertTrue((ROOT / "docs/platform-sdks.md").is_file())


if __name__ == "__main__":
    unittest.main()
