"""F5 native Zig starter template contracts; generator stays pure and deterministic."""
from __future__ import annotations
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / 'templates/minimal'

class TemplatesF5Tests(unittest.TestCase):
    def test_all_generated_baseline_files_have_real_templates(self):
        for name in ('build.zig.tmpl', 'build.zig.zon.tmpl', 'zevui.zon.tmpl',
                     'README.md.tmpl', '.gitignore', 'src/main.zig'):
            with self.subTest(name=name):
                self.assertTrue((TEMPLATE / name).is_file())

    def test_generator_has_no_embedded_build_or_zon_implementation(self):
        code = (ROOT / 'packages/initializr-core/src/generator.ts').read_text()
        for old in ('function renderBuild(', 'function renderManifest(',
                    'function renderZon(', 'function renderReadme('):
            self.assertNotIn(old, code)
        self.assertIn('requiredSources(plan)', (ROOT / 'apps/initializr/src/lib/generator.server.ts').read_text())
        self.assertIn('requiredSources(plan)', (ROOT / 'packages/initializr-core/scripts/new.mjs').read_text())

    def test_existing_compatibility_assets_remain_frozen(self):
        self.assertEqual((TEMPLATE/'src/main.zig').read_bytes(),
                         (ROOT/'templates/compat/minimal/main.zig').read_bytes())
        for name in ('build.zig', 'config.zig'):
            self.assertTrue((ROOT / 'templates/compat/zevui' / name).is_file())

    def test_no_runtime_node_python_or_ts_in_generated_zig_sources(self):
        for name in ('build.zig.tmpl', 'build.zig.zon.tmpl', 'src/main.zig'):
            data = (TEMPLATE/name).read_text()
            self.assertNotIn('node:child_process', data)
            self.assertNotIn('SolidStart', data)

if __name__ == '__main__': unittest.main()
