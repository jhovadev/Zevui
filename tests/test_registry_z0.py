"""Registry consistency and Python ZIP executor contract tests."""
import io
import json
import re
import subprocess
import sys
import unittest
import zipfile
from pathlib import Path
from tests.legacy_oracle.generator import ROOT, CATALOG, InputError, archive, contents, validate


class RegistryContracts(unittest.TestCase):
    def test_catalog_is_single_source_of_truth(self):
        self.assertEqual(CATALOG['schemaVersion'], 2)
        self.assertTrue((ROOT / 'registry/schema.json').exists())
        self.assertFalse((ROOT / 'initializr/catalog.json').exists())
        reviewed = CATALOG['packages']['dvui']
        manifest = (ROOT / 'build.zig.zon').read_text()
        self.assertIn(reviewed['url'], manifest)
        self.assertIn(reviewed['hash'], manifest)
        self.assertEqual([a['id'] for a in CATALOG['addons'] if a['status']=='available'],
                         ['memory_store', 'design_tokens', 'sqlite'])

    def test_supported_addon_sources_are_real_and_confined(self):
        for addon in CATALOG['addons']:
            self.assertIn(addon['trust'], ('official', 'verified', 'community'))
            if addon['status'] != 'available':
                self.assertEqual(addon['files'], [])
            for mapping in addon['files']:
                self.assertTrue(mapping['to'].startswith('src/addons/'))
                self.assertNotIn('..', Path(mapping['from']).parts)
                self.assertNotIn('..', Path(mapping['to']).parts)
                self.assertTrue((ROOT / mapping['from']).is_file())

    def test_repeating_seed_yields_identical_zip(self):
        project = {'name': 'my-zevui-app', 'title': 'Zevui Test',
                   'organization': 'dev.example', 'version': '0.1.0',
                   'addons': ['design_tokens', 'memory_store'], 'fingerprintId': 0x12345678}
        z1, z2 = archive(project), archive(project)
        self.assertEqual(z1, z2)
        with zipfile.ZipFile(io.BytesIO(z1)) as z:
            raw = z.read('my-zevui-app/build.zig.zon').decode()
            self.assertIn('12345678', raw)
            self.assertIn(CATALOG['packages']['dvui']['hash'], raw)

    def test_reserved_fingerprint_ids_rejected(self):
        for value in (0, -1, 0xffffffff, True, 2.5, '3'):
            with self.subTest(value=value), self.assertRaises(InputError):
                validate({'fingerprintId':value})

    def test_generated_file_paths_match_pure_ts_plan(self):
        core = ROOT / 'packages/initializr-core/dist/index.js'
        if not core.exists():
            self.skipTest('run just registry-check to compile the TypeScript planner first')
        request = {'name': 'my-zevui-app', 'title': 'My Zevui App',
                   'organization': 'dev.example', 'version':'0.1.0',
                   'addons':['memory_store','design_tokens'], 'fingerprintId':305419896}
        # The TS planner is a pure computation: only its emitted manifest is read.
        js = '''import { readFileSync } from "node:fs";
import { planProject } from "./packages/initializr-core/dist/index.js";
const r = JSON.parse(readFileSync("./registry/catalog.json", "utf8"));
console.log(JSON.stringify(planProject(JSON.parse(process.argv[1]), r)));
'''
        result = subprocess.run(['node', '--input-type=module', '-e', js, json.dumps(request)],
                                capture_output=True, text=True, cwd=ROOT, check=True)
        plan = json.loads(result.stdout)
        self.assertEqual(set(contents(request)), {entry['path'] for entry in plan['operations']})
        self.assertEqual(plan['fingerprint'],
                         re.search(r'\.fingerprint = (0x[0-9a-f]+)', contents(request)['build.zig.zon'].decode()).group(1))
        self.assertEqual(plan['resolvedAddons'], ['design_tokens', 'memory_store'])

    def test_web_uses_shared_planner_not_python_for_preview(self):
        ui = (ROOT/'apps/initializr/src/routes/index.tsx').read_text()
        self.assertIn('planProject(project(), c)', ui)
        self.assertIn('plan-file-list', ui)
        self.assertTrue((ROOT/'apps/initializr/src/routes/api/metadata.ts').exists())
        self.assertTrue((ROOT/'apps/initializr/src/routes/api/plan.ts').exists())
        bridge = (ROOT/'apps/initializr/src/lib/generator.server.ts').read_text()
        self.assertIn('registry/catalog.json', bridge)
        self.assertNotIn('initializr.bridge', bridge)
        self.assertIn('generateFiles(', bridge)
        self.assertIn('zipProject(', bridge)

if __name__ == '__main__':
    unittest.main()
