"""F6C contracts: frozen legacy output, reproducible pin, offline native smoke."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class SqlitePortabilityF6C(unittest.TestCase):
    def test_check_recompiles_planner_before_python_contracts(self):
        # A stale dist/ from F6B omits mise.toml even when the F6C TS sources
        # and planner are correct. The top-level gate must rebuild it first.
        justfile = (ROOT / "justfile").read_text()
        check_recipe = justfile.split("@check:\n", 1)[1].split("\n@", 1)[0]
        self.assertIn("just registry-check", check_recipe)
        self.assertLess(check_recipe.index("just registry-check"),
                        check_recipe.index("python3 -m unittest discover"))
        registry_recipe = justfile.split("@registry-check:\n", 1)[1].split("\n@", 1)[0]
        self.assertIn("tsc -p packages/initializr-core/tsconfig.json", registry_recipe)

    def test_pin_is_a_real_template_and_uses_validated_version(self):
        template = (ROOT / "templates/minimal/mise.toml.tmpl").read_text()
        self.assertEqual(template, '[tools]\nzig = {{ZIG_VERSION_JSON}}\n')
        generator = (ROOT / "packages/initializr-core/src/generator.ts").read_text()
        planner = (ROOT / "packages/initializr-core/src/index.ts").read_text()
        self.assertIn('"mise.toml": renderTemplate(', generator)
        self.assertIn('path: "mise.toml"', planner)
        self.assertIn('"templates/minimal/mise.toml.tmpl"', generator)
        self.assertEqual(json.loads((ROOT / "registry/catalog.json").read_text())["zig"], "0.17.1")

    def test_generated_minimal_and_sqlite_have_the_same_pin(self):
        if not (ROOT / 'packages/initializr-core/dist/generator.js').exists():
            self.skipTest('TypeScript generator has not been compiled: tsc -p packages/initializr-core/tsconfig.json')
        with tempfile.TemporaryDirectory() as tmp:
            for name, extras in (("f6c-minimal", []), ("f6c-sqlite", ["--addon", "sqlite"])):
                result = subprocess.run(
                    ["node", "packages/initializr-core/scripts/new.mjs", name, *extras, "--output", tmp],
                    cwd=ROOT, capture_output=True, text=True, check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((Path(tmp) / name / "mise.toml").read_text(), '[tools]\nzig = "0.17.1"\n')
            self.assertNotIn('sqlite3', (Path(tmp) / 'f6c-minimal/build.zig').read_text())
            self.assertIn('sqlite_vendor/sqlite3.c', (Path(tmp) / 'f6c-sqlite/build.zig').read_text())

    def test_native_smoke_uses_only_committed_verified_vendor_sources(self):
        source = (ROOT / 'scripts/sqlite_portability_smoke.py').read_text()
        self.assertIn('"--check"', source)
        self.assertIn('shutil.copyfile(', source)
        self.assertIn('"bundled"', source)
        self.assertIn('"off"', source)
        self.assertNotIn('urlopen(', source)
        self.assertNotIn('urllib', source)
        self.assertNotIn('pip install', source)
        self.assertIn('TemporaryDirectory(', source)

    def test_ci_matrix_is_native_and_other_targets_are_experimental(self):
        workflow = (ROOT / '.github/workflows/sqlite-portability.yml').read_text()
        for host in ('ubuntu-latest', 'windows-latest', 'macos-15', 'macos-15-intel'):
            self.assertIn(host, workflow)
        self.assertIn('continue-on-error: ${{ matrix.experimental }}', workflow)
        self.assertIn('version: \'0.17.1\'', workflow)
        self.assertIn('python scripts/sqlite_portability_smoke.py', workflow)
        self.assertIn('continue-on-error: true', workflow)
        addon = json.loads((ROOT / 'addons/storage-sqlite/addon.json').read_text())
        self.assertEqual(addon['compat']['targets'], ['linux'])


if __name__ == '__main__':
    unittest.main()
