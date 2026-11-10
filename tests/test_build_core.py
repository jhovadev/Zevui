"""Build-core contract checks. These complement (not replace) Zig compiler tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BuildCoreContracts(unittest.TestCase):
    def test_two_consumers_share_same_add_app(self):
        build = (ROOT / "build.zig").read_text()
        helper = (ROOT / "zevui/build.zig").read_text()
        self.assertEqual(build.count("zevui.addApp(b,"), 2)
        self.assertIn('pub fn addApp(b: *std.Build', helper)
        self.assertIn('minimal_step.dependOn(&minimal.executable.step)', build)
        self.assertIn('b.step("minimal-run"', build)
        self.assertIn('.install = false, .run_step = null', build)

    def test_zdata_is_opt_in(self):
        helper = (ROOT / "zevui/build.zig").read_text()
        main = (ROOT / "examples/minimal/main.zig").read_text()
        minimal = (ROOT / "examples/minimal/zevui.zon").read_text()
        csv = (ROOT / "zevui.zon").read_text()
        self.assertIn('if (cfg.modules.zdata)', helper)
        self.assertIn('.zdata = false', minimal)
        self.assertIn('.zdata = true', csv)
        self.assertNotIn('@import("zdata")', main)
        self.assertNotIn('src/csv.zig', main)

    def test_brand_originates_in_typed_zon(self):
        identity = (ROOT / "src/app/identity.zig").read_text()
        helper = (ROOT / "zevui/build.zig").read_text()
        self.assertIn('@import("zevui_config")', identity)
        self.assertIn('module.addOptions("zevui_config", cfg_options)', helper)
        self.assertIn('identity_tests.root_module.addOptions("zevui_config", identity_options)',
                      (ROOT / "examples/csv/build.zig").read_text())
        self.assertIn('pub const window_size', identity)
        self.assertNotIn('1390', identity)

    def test_configuration_is_typed_and_platform_overrides_are_explicit(self):
        build = (ROOT / "build.zig").read_text()
        cfg = (ROOT / "zevui/config.zig").read_text()
        for path in ('zevui.zon', 'zevui.windows.zon', 'zevui.macos.zon'):
            self.assertTrue((ROOT / path).exists())
        self.assertIn('const base: zevui.Config = @import("zevui.zon")', build)
        self.assertIn('const windows: zevui.Override', build)
        self.assertIn('const macos: zevui.Override', build)
        self.assertIn('pub fn validate(cfg: Config)', cfg)
        self.assertIn('pub fn resolve(base: Config, override: Override)', cfg)

    def test_no_build_core_dependency_on_csv_or_zdata(self):
        for path in (ROOT / "zevui").rglob('*.zig'):
            source = path.read_text()
            self.assertNotIn('src/csv.zig', source)
            self.assertNotIn('@import("zdata")', source)
            self.assertNotIn('src/search.zig', source)


if __name__ == '__main__':
    unittest.main()
