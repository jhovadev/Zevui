"""Guards for identity, SVG resources, grid IDs and the Windows subsystem."""
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class BrandingContracts(unittest.TestCase):
    def test_icons_are_editable_svg_and_window_assets(self):
        for name in ('search', 'columns', 'preferences'):
            path = ROOT / 'src' / 'ui' / 'assets' / f'{name}.svg'
            self.assertTrue(path.exists(), path)
            root = ET.parse(path).getroot()
            self.assertEqual(root.tag, '{http://www.w3.org/2000/svg}svg')
        ET.parse(ROOT / 'assets/branding/zevui.svg')
        png = (ROOT / 'src/app/assets/zevui.png').read_bytes()
        self.assertEqual(png[:8], bytes.fromhex('89504e470d0a1a0a'))
        self.assertTrue((ROOT / 'assets/branding/zevui.ico').stat().st_size > 1000)

    def test_brand_is_only_owned_by_identity_module(self):
        main = (ROOT / 'src/main.zig').read_text()
        identity = (ROOT / 'src/app/identity.zig').read_text()
        self.assertIn('const brand = @import("app/identity.zig");', main)
        self.assertIn('.title = brand.title', main)
        self.assertIn('.icon = brand.icon_png', main)
        self.assertIn('pub const version:', identity)
        self.assertIn('@import("zevui_config")', identity)
        self.assertIn('pub const organization:', identity)
        self.assertIn('pub const application:', identity)

    def test_window_dimensions_use_dvui_size_at_app_boundary(self):
        main = (ROOT / 'src/main.zig').read_text()
        identity = (ROOT / 'src/app/identity.zig').read_text()
        self.assertIn('.size = dvui.Size.cast(brand.window_size)', main)
        self.assertIn('.min_size = dvui.Size.cast(brand.minimum_size)', main)
        self.assertIn('pub const window_size =', identity)
        self.assertIn('pub const minimum_size =', identity)
        self.assertNotIn('@import("dvui")', identity)

    def test_search_is_disclosed_and_does_not_overlap_density(self):
        main = (ROOT / 'src/main.zig').read_text()
        search = main.split('fn searchPanel(',1)[1].split('fn appearancePanel(',1)[0]
        self.assertIn('if (!state.show_search) return;', search)
        self.assertIn('state.search_draft', search)
        self.assertNotIn('theme.toggleDensity()', search)
        self.assertIn('fn appearancePanel(', main)

    def test_duplicate_widget_ids_are_avoided_in_column_rows(self):
        main = (ROOT / 'src/main.zig').read_text()
        fragment = main.split('for (ds.headers, 0..) |name, col| {',1)[1]
        self.assertIn('.id_extra = col, .padding', fragment.split('defer line.deinit()',1)[0])

    def test_gui_is_consoleless_on_windows_but_debug_override_exists(self):
        build = (ROOT / 'build.zig').read_text()
        helper = (ROOT / 'zevui/build.zig').read_text()
        self.assertIn('exe.subsystem = .windows;', helper)
        self.assertIn('target.result.os.tag == .windows', helper)
        self.assertIn('windows-console', build)
        self.assertIn('addWin32ResourceFile', helper)
        self.assertIn('assets/windows/zevui.rc', build)
        self.assertIn('zevui.ico', (ROOT / 'assets/windows/zevui.rc').read_text())

if __name__ == '__main__':
    unittest.main()
