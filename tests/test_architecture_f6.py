"""F6A structural gate: SQLite is a local experimental package, not a fake published addon."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addons/storage-sqlite"


class StorageSqliteF6A(unittest.TestCase):
    def test_independent_package_and_three_link_modes(self):
        for file in ("build.zig", "build.zig.zon", "LICENSE", "README.md", "src/root.zig", "src/off.zig", "tools/vendor_sqlite.py"):
            self.assertTrue((ADDON / file).is_file(), file)
        build = (ADDON / "build.zig").read_text()
        for entry in ('bundled', 'system', 'off', 'b.addModule("zevui_module"', 'module.addCSourceFile', 'module.linkSystemLibrary("sqlite3"'):
            self.assertIn(entry, build)
        self.assertNotIn('zig fetch', build)
        self.assertNotIn('b.addTranslateC', build)

    def test_off_is_pure_stub_without_sqlite_import_or_symbol(self):
        off = (ADDON / "src/off.zig").read_text()
        self.assertNotIn('extern "c"', off)
        self.assertNotIn('sqlite3_', off)
        self.assertIn('error.Unsupported', off)

    def test_native_wrapper_binds_owned_and_borrowed_data(self):
        root = (ADDON / "src/root.zig").read_text()
        self.assertNotIn('@cImport', root)
        self.assertIn('sqlite3_prepare_v2', root)
        self.assertIn('sqlite3_bind_blob', root)
        self.assertIn('transient()', root)
        self.assertIn('allocator.dupe(u8, data)', root)
        self.assertIn('test "sqlite prepared statements', root)
        self.assertIn('test "transaction rollback', root)

    def test_sqlite_remains_unavailable_to_generator(self):
        manifest = json.loads((ROOT / "registry/planned/sqlite.json").read_text())
        self.assertEqual(manifest['status'], 'planned')
        self.assertEqual(manifest['delivery'], 'unavailable')
        self.assertEqual(manifest['files'], [])


if __name__ == '__main__':
    unittest.main()
