"""Component source ownership and web catalog gates: standard library only."""
from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("zevui_components", ROOT / "tools/components.py")
assert SPEC and SPEC.loader
components = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(components)


class ComponentsRegistryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.project = Path(self.tmp.name)
        (self.project / "src").mkdir()
        self.manifests = components.read_registry()

    def choose(self, name: str):
        return components.selected(self.manifests, name)

    def test_catalog_is_exact_snapshot_of_real_zig_sources(self):
        data = components.catalog_bytes(self.manifests)
        self.assertEqual(data, components.CATALOG.read_bytes())
        catalog = json.loads(data)
        self.assertEqual([c["id"] for c in catalog["components"]], ["action", "calendar", "checkbox", "heatmap", "input", "progress", "separator", "tokens"])
        for component in catalog["components"]:
            for file in component["files"]:
                self.assertEqual(file["sha256"], components.digest(file["source"].encode()))

    def test_install_is_safe_and_records_checksums(self):
        m = self.choose("heatmap")
        self.assertEqual(len(components.install(m, self.project, False, True)), 2)
        self.assertFalse((self.project / ".zevui").exists())
        self.assertEqual(len(components.install(m, self.project, False)), 2)
        self.assertEqual(components.status(m, self.project), "clean")
        self.assertEqual(components.install(m, self.project, False), [])
        lock = json.loads((self.project / ".zevui/components.lock.json").read_text())
        self.assertEqual(set(lock["components"]["heatmap"]["files"]),
                         {"src/components/heatmap.zig", "src/components/heatmap_model.zig"})

    def test_existing_local_change_is_never_overwritten(self):
        m = self.choose("heatmap")
        components.install(m, self.project, False)
        user_file = self.project / "src/components/heatmap.zig"
        user_file.write_text("// user edit\n")
        with self.assertRaisesRegex(components.ComponentError, "Locally modified"):
            components.install(m, self.project, True)
        self.assertEqual(user_file.read_text(), "// user edit\n")
        self.assertEqual(components.status(m, self.project), "modified/missing")

    def test_unmanaged_collision_blocks_entire_install(self):
        m = self.choose("heatmap")
        (self.project / "src/components").mkdir()
        (self.project / "src/components/heatmap_model.zig").write_text("// existing")
        with self.assertRaisesRegex(components.ComponentError, "Unmanaged existing file"):
            components.install(m, self.project, False)
        self.assertFalse((self.project / "src/components/heatmap.zig").exists())
        self.assertFalse((self.project / ".zevui").exists())

    def test_symlinked_destination_is_rejected(self):
        m = self.choose("tokens")
        (self.project / "src/components").symlink_to(self.project, target_is_directory=True)
        with self.assertRaisesRegex(components.ComponentError, "Symlinked destination"):
            components.install(m, self.project, False)

    def test_unmodified_local_copy_can_be_updated(self):
        from unittest.mock import patch
        m = self.choose("progress")
        components.install(m, self.project, False)
        target = self.project / "src/components/progress.zig"
        original = target.read_bytes()
        with tempfile.TemporaryDirectory() as replacement:
            repo = Path(replacement)
            modified_source = repo / m["files"][0]["source"]
            modified_source.parent.mkdir(parents=True)
            modified_source.write_bytes(original + b"\n// upstream change\n")
            with patch.object(components, "REPO", repo):
                self.assertEqual(components.status(m, self.project), "update available")
                with self.assertRaisesRegex(components.ComponentError, "Update needed"):
                    components.install(m, self.project, False)
                components.install(m, self.project, True)
                self.assertEqual(components.status(m, self.project), "clean")
        self.assertTrue(target.read_bytes().endswith(b"// upstream change\n"))

    def test_refuses_symlinked_lock_directory_before_writing(self):
        (self.project / ".zevui").symlink_to(self.project, target_is_directory=True)
        with self.assertRaisesRegex(components.ComponentError, "symlinked"):
            components.install(self.choose("tokens"), self.project, False)
        self.assertFalse((self.project / "src/components/tokens.zig").exists())

    def test_update_cannot_run_before_add(self):
        with self.assertRaisesRegex(components.ComponentError, "not installed"):
            components.install(self.choose("progress"), self.project, True)

    def test_path_traversal_in_manifest_is_rejected(self):
        for path in ("src/components/../../secret.zig", "src/components/.foo/../other.zig", "/src/components/x.zig"):
            with self.subTest(path=path):
                with self.assertRaises(components.ComponentError):
                    components.safe_rel(path, components.TARGET_PREFIX)

    def test_catalog_hydrates_static_shell_before_interactive_widgets(self):
        route = (ROOT / "apps/initializr/src/routes/components/index.tsx").read_text()
        # Do not hydrate a deeply nested dynamic preview tree in the SSR pass.
        self.assertIn('onMount(() => setHydrated(true))', route)
        self.assertIn('<Show when={hydrated()} fallback=', route)
        self.assertIn('Loading interactive component previews', route)
        self.assertLess(route.index('<Show when={hydrated()}'), route.index('<For each={categories}>'))
        self.assertLess(route.index('<Show when={hydrated()}'), route.index('<Preview component={item()}'))
        # All icons that instantiate JSX fragments stay inside the mount gate.
        before_gate = route.split('<Show when={hydrated()}')[0].split('return <div class="page-shell')[1]
        self.assertNotIn('<Icon ', before_gate)

    def test_heatmap_model_matches_zig_017_rules(self):
        model = (ROOT / "framework/src/ui/heatmap_model.zig").read_text()
        self.assertIn('pub fn intensity(value: u32, max_value: u32)', model)
        self.assertNotIn('pub fn intensity(value: u32, maximum: u32)', model)
        self.assertIn('validWeeks(values[0..13])', model)
        self.assertNotIn('validWeeks(&values[0..13])', model)

    def test_catalog_route_is_additive(self):
        route = ROOT / "apps/initializr/src/routes/components/index.tsx"
        self.assertTrue(route.is_file())
        source = route.read_text()
        self.assertIn("components.generated.json", source)
        self.assertIn("Web approximation", source)
        self.assertIn("Copy source", source)
        self.assertIn("type=\"range\"", source)
        initializr = (ROOT / "apps/initializr/src/routes/index.tsx").read_text()
        self.assertIn('href="/components"', initializr)
        self.assertIn('fetch("/api/generate"', initializr)


if __name__ == "__main__":
    unittest.main()
