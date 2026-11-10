import io
import json
import re
import tempfile
import unittest
import zipfile
import zlib
from pathlib import Path
from tests.legacy_oracle.generator import CATALOG, InputError, archive, contents, create_directory, validate


class InitializrTests(unittest.TestCase):
    def test_catalog_schema_and_enabled_addons(self):
        self.assertEqual(CATALOG['schemaVersion'], 2)
        self.assertEqual([a['id'] for a in CATALOG['addons'] if a['status'] == 'available'],
                         ['memory_store','design_tokens'])

    def test_unsupported_addons_fail_closed(self):
        for addon in ('tray', 'sqlite', 'bundle', 'zdata', '../etc/passwd'):
            with self.subTest(addon=addon), self.assertRaises(InputError):
                validate({'addons': [addon]})

    def test_validate_identifiers_and_titles(self):
        for name in ('../escape', 'AName', 'a;rm -rf', 'a', 'q'*40):
            with self.subTest(name=name), self.assertRaises(InputError):
                validate({'name': name})
        with self.assertRaises(InputError):
            validate({'title':'ok\n.bad'})
        with self.assertRaises(InputError):
            validate({'addons':['design_tokens','design_tokens']})

    def test_archive_contains_standalone_project_and_correct_fingerprint(self):
        z = zipfile.ZipFile(io.BytesIO(archive({'name':'sample-app','title':'Sample App',
            'organization':'dev.jhovadev','addons':['memory_store','design_tokens']})))
        paths = set(z.namelist())
        self.assertIn('sample-app/build.zig.zon', paths)
        self.assertIn('sample-app/zevui/build.zig', paths)
        self.assertIn('sample-app/src/addons/memory_store.zig', paths)
        self.assertIn('sample-app/src/addons/design_tokens.zig', paths)
        manifest = z.read('sample-app/build.zig.zon').decode()
        self.assertIn('.name = .sample_app,', manifest)
        self.assertIn('dvui-0.6.0-dev-', manifest)
        val = int(re.search(r'\.fingerprint = (0x[0-9a-f]+)', manifest).group(1),16)
        self.assertEqual(val >> 32, zlib.crc32(b'sample_app'))
        self.assertNotIn(val & 0xffffffff, (0,0xffffffff))
        self.assertNotIn('zdata', z.read('sample-app/build.zig').decode())

    def test_optional_addons_not_copied(self):
        files = contents({'name':'small-app','addons':[]})
        self.assertFalse(any('addons/' in name for name in files))
        self.assertNotIn(b'addons/', files['src/main.zig'])
        self.assertIn(b'.zdata = false', files['zevui.zon'])

    def test_no_overwrite_and_no_partial_changes(self):
        with tempfile.TemporaryDirectory() as dir:
            dest = create_directory({'name':'test-app'},Path(dir))
            self.assertTrue((dest/'build.zig').is_file())
            with self.assertRaises(FileExistsError):
                create_directory({'name':'test-app'},Path(dir))
            self.assertTrue((dest/'build.zig').is_file())

    def test_archive_is_zip_slip_safe(self):
        with zipfile.ZipFile(io.BytesIO(archive({'name':'test-app'}))) as z:
            self.assertTrue(all(name.startswith('test-app/') and '..' not in Path(name).parts for name in z.namelist()))


if __name__ == '__main__':
    unittest.main()
