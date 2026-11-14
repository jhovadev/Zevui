"""F9 native CLI, registry schema and SKILL.md packaging contracts."""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class ComponentsF9Tests(unittest.TestCase):
    def test_standard_shadcn_index_separated_from_zig_bundle(self):
        cli = ROOT / 'packages/zevui-cli'
        index = json.loads((cli / 'registry.json').read_text())
        bundle = json.loads((cli / 'registry-bundle.json').read_text())
        self.assertEqual(index['name'], 'zevui')
        self.assertEqual(len(index['items']), 8)
        self.assertEqual([item['name'] for item in index['items']], [i['name'] for i in bundle['items']])
        for item in index['items']:
            self.assertEqual(item['type'], 'registry:ui')
            for f in item['files']:
                self.assertNotIn('content', f)
        for item in bundle['items']:
            for f in item['files']:
                self.assertEqual(hashlib.sha256(f['content'].encode()).hexdigest(), f['sha256'])
                self.assertEqual((ROOT / f['path']).read_bytes(), f['content'].encode())

    def test_native_zig_main_owns_commands(self):
        zig = (ROOT / 'packages/zevui-cli/src/main.zig').read_text()
        shim = (ROOT / 'packages/zevui-cli/bin/zevui.mjs').read_text()
        for term in ['pub fn main(init: std.process.Init)', 'std.crypto.hash.sha2.Sha256', 'createFileAtomic', 'statFile(io, path, .{ .follow_symlinks = false })', 'runInstall', 'runDoctor', 'parseLock', 'registry-bundle.json']:
            self.assertIn(term, zig)
        for term in ['child_process', 'spawnSync', 'src/main.zig']:
            self.assertIn(term, shim)
        self.assertNotIn('readFile(', shim)
        self.assertNotIn('writeFile(', shim)
        self.assertNotIn('createHash', shim)
        self.assertNotIn('function run(', shim)

    def test_skills_are_in_sync_and_comprehensive(self):
        paths = [ROOT / 'skills/zevui-components/SKILL.md', ROOT / '.agents/skills/zevui-components/SKILL.md', ROOT / 'packages/zevui-cli/SKILL.md']
        content = paths[0].read_bytes()
        for path in paths: self.assertEqual(path.read_bytes(), content)
        for term in ['name: zevui-components', 'Zig 0.17.1', 'Agent Skill', 'SHA-256', 'dry-run', 'Calendar', 'Heatmap']:
            self.assertIn(term, content.decode())

    def test_gallery_has_native_cli_and_four_new_previews(self):
        route = (ROOT / 'apps/initializr/src/routes/components/index.tsx').read_text()
        for component in ['calendar', 'input', 'checkbox', 'separator']:
            self.assertIn(f'props.component.id === "{component}"', route)
        self.assertIn('zig run packages/zevui-cli/src/main.zig', route)
        self.assertIn('<Show when={hydrated()}', route)
        self.assertNotIn('4 source-owned components', route)

    def test_native_cli_zon_has_stable_fingerprint(self):
        """Zig 0.17.1 rejects build.zig.zon without a package fingerprint."""
        import re
        zon = (ROOT / 'packages/zevui-cli/build.zig.zon').read_text()
        self.assertRegex(zon, r'\.name\s*=\s*\.zevui_cli\s*,')
        self.assertRegex(zon, r'\.fingerprint\s*=\s*0x[0-9a-fA-F]{16}\s*,')
        self.assertRegex(zon, r'\.minimum_zig_version\s*=\s*"0\.17\.1"')

    def test_cli_embed_stays_inside_zig_module_root_and_snapshots_match(self):
        """Zig 0.17.1 forbids relative @embedFile paths escaping src/."""
        cli = ROOT / 'packages/zevui-cli'
        main = (cli / 'src/main.zig').read_text()
        self.assertIn('@embedFile("registry-bundle.json")', main)
        self.assertNotIn('@embedFile("../registry-bundle.json")', main)
        self.assertEqual((cli / 'src/registry-bundle.json').read_bytes(),
                         (cli / 'registry-bundle.json').read_bytes())
        generator = (cli / 'scripts/build-registry.mjs').read_text()
        self.assertIn('embeddedTarget', generator)
        self.assertIn('await writeFile(embeddedTarget, out)', generator)

    def test_native_cli_build_and_npm_package(self):
        cli = ROOT / 'packages/zevui-cli'
        self.assertTrue((cli / 'build.zig').is_file())
        self.assertTrue((cli / 'build.zig.zon').is_file())
        p = json.loads((cli / 'package.json').read_text())
        self.assertIn('src/', p['files'])
        self.assertIn('registry-bundle.json', p['files'])
        self.assertTrue((cli / p['bin']['zevui']).is_file())

if __name__ == '__main__': unittest.main()
