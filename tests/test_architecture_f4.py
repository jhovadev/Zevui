"""F4: actual manifest sources, derived registry and Zig package boundaries."""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch, Mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_registry  # noqa: E402
import pin_addon  # noqa: E402


class ArchitectureF4Tests(unittest.TestCase):
    def test_catalog_and_channel_metadata_are_regenerated_deterministically(self):
        outputs = build_registry.build_outputs()
        for path, expected in outputs.items():
            self.assertEqual(path.read_bytes(), expected, str(path))
        metadata = json.loads(outputs[build_registry.METADATA])
        self.assertEqual(metadata['channel'], '0.17')
        self.assertEqual(metadata['registryVersion'], '0.2.0')
        self.assertEqual(metadata['addons'][0]['package'], None)
        self.assertEqual([a['id'] for a in metadata['addons'] if a['status'] == 'available'],
                         ['memory_store', 'design_tokens'])

    def test_independent_packages_have_zig_manifests_and_public_modules(self):
        for ident, dirname in [('memory_store', 'memory-store'), ('design_tokens', 'design-tokens')]:
            root = ROOT / 'addons' / dirname
            manifest = json.loads((root / 'addon.json').read_text())
            self.assertEqual(manifest['id'], ident)
            self.assertEqual(manifest['kind'], 'zig')
            self.assertEqual(manifest['delivery'], 'source-copy')
            self.assertIsNone(manifest['package'])
            build = (root / 'build.zig').read_text()
            self.assertIn('b.addModule("zevui_module"', build)
            self.assertIn('b.addTest(', build)
            zon = (root / 'build.zig.zon').read_text()
            self.assertIn('.minimum_zig_version = "0.17.1"', zon)
            self.assertIn('.dependencies = .{}', zon)
            self.assertIn('.fingerprint =', zon)
            self.assertTrue((root / 'LICENSE').is_file())
            code = (root / 'src/root.zig').read_text()
            self.assertNotIn('@import("zdata")', code)
            self.assertNotIn('@import("dvui")', code)

    def test_golden_addon_content_unchanged(self):
        fixture = json.loads((ROOT / 'tests/fixtures/initializr-f2-golden.json').read_text())
        golden = fixture['addons']['files']
        for ident, dirname in [('memory_store', 'memory-store'), ('design_tokens', 'design-tokens')]:
            actual = hashlib.sha256((ROOT / 'addons' / dirname / 'src/root.zig').read_bytes()).hexdigest()
            self.assertEqual(actual, golden[f'src/addons/{ident}.zig'])

    def test_manifest_validator_rejects_invalid_paths_and_unpinned_package(self):
        base = json.loads((ROOT / 'addons/memory-store/addon.json').read_text())
        bad = json.loads(json.dumps(base))
        bad['files'][0]['from'] = 'addons/memory-store/src/../../../../etc/passwd'
        with self.assertRaises(build_registry.RegistryError):
            build_registry.validate_addon('addons/memory-store/addon.json', bad, {'0.17.1'})
        bad = json.loads(json.dumps(base))
        bad['delivery'] = 'package'
        with self.assertRaises(build_registry.RegistryError):
            build_registry.validate_addon('addons/memory-store/addon.json', bad, {'0.17.1'})
        bad = json.loads(json.dumps(base))
        bad['license'] = ''
        with self.assertRaises(build_registry.RegistryError):
            build_registry.validate_addon('addons/memory-store/addon.json', bad, {'0.17.1'})

    def test_registry_cannot_publish_unpinned_addons(self):
        result = subprocess.run([sys.executable, 'tools/build_registry.py', '--require-published'],
                                cwd=ROOT, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Unpublished addon', result.stderr)

    def test_pin_tool_never_runs_a_shell_or_accepts_mutable_git_revision(self):
        with self.assertRaises(ValueError):
            pin_addon.fetch_hash('git+https://example.com/a.git?ref=main', 'zig')
        with self.assertRaises(ValueError):
            pin_addon.fetch_hash('https://example.com/a.tar.gz; echo unsafe', 'zig')
        commit_url = 'git+https://example.com/a.git#' + ('a' * 40)
        mock_result = Mock(stdout='example-0.1.0-valid-content-hash\n')
        with patch.object(pin_addon.subprocess, 'run', return_value=mock_result) as run:
            self.assertEqual(pin_addon.fetch_hash(commit_url, 'zig'),
                             'example-0.1.0-valid-content-hash')
            run.assert_called_once_with(['zig', 'fetch', commit_url], capture_output=True,
                                        text=True, check=True, timeout=180)

    def test_registry_cli_check_succeeds(self):
        result = subprocess.run([sys.executable, 'tools/build_registry.py', '--check'],
                                cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
