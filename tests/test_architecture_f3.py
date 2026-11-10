"""F3 build / runtime / product boundaries: structural regression checks.

These assertions are supplementary, not a substitute for Zig 0.17.1 compile.
"""
import re
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
FRAMEWORK = ROOT / "framework"
CSV = ROOT / "examples/csv-explorer"


class FrameworkF3Contracts(unittest.TestCase):
    def test_standalone_framework_package(self):
        manifest = (FRAMEWORK / "build.zig.zon").read_text()
        build = (FRAMEWORK / "build.zig").read_text()
        self.assertIn('.name = .zevui,', manifest)
        self.assertIn('b.addModule("zevui"', build)
        self.assertIn('pub fn addApp(', build)
        self.assertIn('pub fn build(b: *std.Build)', build)
        self.assertIn('exe.subsystem = .windows;', build)
        self.assertNotIn('.zdata = .{', manifest)
        self.assertNotIn('@import("zdata")', (FRAMEWORK / 'src/root.zig').read_text())

    def test_consumer_is_a_local_package_dependency(self):
        zon = (ROOT / 'build.zig.zon').read_text()
        build = (ROOT / 'build.zig').read_text()
        self.assertIn('.zevui = .{ .path = "framework" },', zon)
        self.assertIn('b.dependency("zevui"', build)
        self.assertIn('sdk_dep.module("zevui")', build)
        self.assertIn('zevui.addApp(b, config', build)
        self.assertIn('zevui.addApp(b, minimal_config', build)

    def test_build_helper_is_imported_from_the_dependency(self):
        """Zig 0.17.1 must not own framework/build.zig in two modules."""
        build = (ROOT / 'build.zig').read_text()
        manifest = (ROOT / 'build.zig.zon').read_text()
        self.assertIn('const zevui = @import("zevui");', build)
        self.assertNotIn('@import("framework/build.zig")', build)
        self.assertIn('.zevui = .{ .path = "framework" },', manifest)
        self.assertIn('b.dependency("zevui"', build)
        self.assertIn('sdk_dep.module("zevui")', build)

    def test_csv_not_in_sdk_and_uses_public_ui_kit(self):
        main = (CSV / 'src/main.zig').read_text()
        self.assertIn('const kit = @import("zevui");', main)
        self.assertIn('kit.ui.tokens', main)
        self.assertIn('kit.ui.components', main)
        self.assertFalse((ROOT / 'src').exists())
        self.assertFalse((ROOT / 'zevui').exists())
        for source in FRAMEWORK.rglob('*.zig'):
            code = source.read_text()
            self.assertNotIn('examples/csv-explorer', code)
            self.assertNotIn('zdata.scan', code)
            self.assertNotIn('zdata.bits', code)

    def test_legacy_generator_remains_frozen(self):
        self.assertTrue((ROOT / 'templates/compat/minimal/main.zig').is_file())
        for name in ('build.zig', 'config.zig'):
            self.assertTrue((ROOT / 'templates/compat/zevui' / name).is_file())
        planner = (ROOT / 'packages/initializr-core/src/index.ts').read_text()
        self.assertIn('source: "templates/compat/zevui/build.zig"', planner)
        self.assertIn('source: "templates/compat/zevui/config.zig"', planner)
        self.assertTrue((ROOT / 'tests/fixtures/initializr-f2-golden.json').is_file())

    def test_assets_stay_inside_source_module(self):
        for name in ('search.svg', 'columns.svg', 'preferences.svg'):
            self.assertTrue((FRAMEWORK/'src/ui/assets'/name).is_file())
        self.assertTrue((CSV/'src/app/assets/zevui.png').is_file())
        self.assertIn('kit.addImport("dvui"', (ROOT/'build.zig').read_text())
        self.assertNotIn('b.dependency("dvui"', (FRAMEWORK/'build.zig').read_text().split('pub fn build(b: *std.Build)',1)[1])

    def test_minimal_app_uses_no_zdata_or_csv(self):
        minimal = (ROOT/'examples/minimal/main.zig').read_text()
        self.assertNotIn('@import("zdata")', minimal)
        self.assertNotIn('csv.zig', minimal)
        self.assertIn('.zdata = false', (ROOT/'examples/minimal/zevui.zon').read_text())


if __name__ == '__main__':
    unittest.main()
