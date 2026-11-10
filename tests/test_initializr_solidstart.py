"""Source-level migration and bridge smoke tests, no JS package install required."""
from __future__ import annotations

import io
import json
import subprocess
import sys
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / 'apps' / 'initializr'


class InitializrSolidStartTests(unittest.TestCase):
    def bridge(self, data: bytes):
        return subprocess.run([sys.executable, '-m', 'tests.legacy_oracle.bridge'], input=data,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=ROOT, check=False)

    def test_frozen_oracle_bridge_generates_valid_zip_without_stdout_noise(self):
        output = self.bridge(json.dumps({'name':'bridge-test', 'addons':['design_tokens']}).encode())
        self.assertEqual(output.returncode, 0, output.stderr.decode())
        with zipfile.ZipFile(io.BytesIO(output.stdout)) as z:
            self.assertIn('bridge-test/build.zig', z.namelist())
            self.assertIn('bridge-test/src/addons/design_tokens.zig', z.namelist())

    def test_frozen_oracle_rejects_unsafe_or_oversized_payloads(self):
        for payload in (b'', b'{', b'{}' + b' ' * 17000, b'{"addons":["tray"]}', b'{"name":"../escape"}'):
            with self.subTest(payload=payload[:40]):
                result = self.bridge(payload)
                self.assertEqual(result.returncode, 2)
                self.assertFalse(result.stdout)
                self.assertTrue(result.stderr)

    def test_web_is_solidstart_and_is_not_in_generated_app(self):
        package = json.loads((WEB/'package.json').read_text())
        self.assertEqual(package['dependencies']['@solidjs/start'], '2.2.2')
        self.assertIn('solid-js', package['dependencies'])
        self.assertIn('nitro', package['dependencies'])
        self.assertTrue((WEB/'src/routes/index.tsx').is_file())
        self.assertTrue((WEB/'src/routes/api/catalog.ts').is_file())
        self.assertTrue((WEB/'src/routes/api/generate.ts').is_file())
        from tests.legacy_oracle.generator import contents
        generated = contents({'name':'solid-separate'})
        self.assertNotIn('package.json', generated)
        self.assertFalse(any(name.endswith('.tsx') for name in generated))

    def test_api_routes_enforce_local_contract_and_typescript_generator(self):
        api = (WEB/'src/routes/api/generate.ts').read_text()
        bridge = (WEB/'src/lib/generator.server.ts').read_text()
        self.assertIn('MAX_BODY = 16 * 1024', api)
        self.assertIn('Cross-origin generation is disabled', api)
        self.assertIn('zipProject(', bridge)
        self.assertIn('generateFiles(', bridge)
        self.assertNotIn('child_process', bridge)
        self.assertIn('ZEVUI_REPO_ROOT', bridge)

    def test_hydration_diagnostic_avoids_eager_icon_jsx(self):
        page = (WEB/'src/routes/index.tsx').read_text()
        icon = page.split('function Icon(', 1)[1].split('const defaults:', 1)[0]
        self.assertIn('switch (props.name)', icon)
        self.assertIn('{shape()}', icon)
        self.assertNotIn('const paths = {', icon)
        vite = (WEB/'vite.config.ts').read_text()
        self.assertIn('ZEVUI_INITIALIZR_CSR', vite)
        just = (ROOT/'justfile').read_text()
        self.assertIn('@initializr-csr:', just)

    def test_just_recipes_are_wired_to_solidstart(self):
        justfile = (ROOT/'justfile').read_text()
        self.assertIn('@initializr:', justfile)
        self.assertIn('cd apps/initializr && bun run dev', justfile)
        self.assertNotIn('@initializr-legacy:', justfile)
        self.assertIn('node packages/initializr-core/scripts/new.mjs', justfile)
        self.assertIn('@initializr-build:', justfile)


if __name__ == '__main__':
    unittest.main()
