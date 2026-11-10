"""F3 only adds an SDK path pin and must not replace ZData/DVUI hashes."""
from pathlib import Path
import tempfile
import unittest
from tools.f3_wire_manifest import wire_manifest

ROOT = Path(__file__).resolve().parents[1]


class ManifestWiringF3Tests(unittest.TestCase):
    def test_preserves_existing_external_pins_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'framework').mkdir()
            (root / 'framework/build.zig.zon').write_text('.{}\n')
            manifest = root / 'build.zig.zon'
            original = '.{\n    .dependencies = .{\n        .zdata = .{ .url = "u", .hash = "pin" },\n        .dvui = .{ .url = "v", .hash = "pin2" },\n    },\n}\n'
            manifest.write_text(original)
            self.assertTrue(wire_manifest(manifest))
            self.assertFalse(wire_manifest(manifest))
            text = manifest.read_text()
            self.assertIn('.zdata = .{ .url = "u", .hash = "pin" }', text)
            self.assertIn('.dvui = .{ .url = "v", .hash = "pin2" }', text)
            self.assertEqual(text.count('.zevui ='), 1)

    def test_rejects_conflicting_pin(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root/'framework').mkdir()
            (root/'framework/build.zig.zon').write_text('.{}\n')
            manifest = root/'build.zig.zon'
            original = '.{\n    .dependencies = .{\n        .zevui = .{ .url = "other" },\n    },\n}\n'
            manifest.write_text(original)
            with self.assertRaises(ValueError):
                wire_manifest(manifest)
            self.assertEqual(manifest.read_text(), original)


if __name__ == '__main__':
    unittest.main()
