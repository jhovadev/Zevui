"""F1 migration guardrails for the pre-monorepo Zevui layout.

These tests deliberately validate *current* Z0 public contracts; migration
phases F2/F3 must update the assertions alongside their path moves.
"""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ArchitectureF1Tests(unittest.TestCase):
    def test_adr_set_and_audit_are_present(self):
        for n in range(1, 6):
            self.assertEqual(
                len(list((ROOT / "docs/adr").glob(f"{n:04d}-*.md"))),
                1,
                f"Missing or duplicate ADR-{n:04d}",
            )
        for filename in (
            "current-state.md", "target-architecture.md",
            "migration-roadmap.md", "f1-freeze.md",
        ):
            self.assertTrue((ROOT / "docs/architecture" / filename).is_file())

    def test_current_build_contracts_are_still_present(self):
        root_build = (ROOT / "build.zig").read_text()
        helper = (ROOT / "framework/build.zig").read_text()
        self.assertIn("zevui.addApp(b, config", root_build)
        self.assertIn("zevui.addApp(b, minimal_config", root_build)
        self.assertIn('module.addImport("dvui"', helper)
        self.assertIn('module.addImport("zdata"', helper)
        self.assertIn("if (!options.windows_console) exe.subsystem = .windows;", helper)

    def test_public_zon_keys_are_not_silently_renamed(self):
        zon = (ROOT / "zevui.zon").read_text()
        for key in ("identity", "window", "appearance", "modules"):
            self.assertRegex(zon, rf"\.{key}\s*=")
        self.assertTrue((ROOT / "zevui.windows.zon").is_file())
        self.assertTrue((ROOT / "zevui.macos.zon").is_file())

    def test_f2_has_only_ts_generator_in_production(self):
        self.assertTrue((ROOT / "packages/initializr-core/src/generator.ts").is_file())
        self.assertTrue((ROOT / "tests/legacy_oracle/generator.py").is_file())
        self.assertFalse((ROOT / "initializr/generator.py").exists())
        self.assertFalse((ROOT / "apps/initializr/src/lib/bridge.server.ts").exists())
        api = (ROOT / "apps/initializr/src/lib/generator.server.ts").read_text()
        self.assertNotIn("child_process", api)
        self.assertIn("generateFiles(", api)

    def test_generated_artifacts_are_ignored(self):
        ignore = (ROOT / ".gitignore").read_text().splitlines()
        patterns = {line.strip() for line in ignore if not line.lstrip().startswith("#")}
        for required in (
            "dist/", "zig-out/", "zig-pkg/", ".zig-cache/",
            "apps/initializr/node_modules/", "apps/initializr/.output/",
            "packages/initializr-core/dist/",
        ):
            self.assertIn(required, patterns)

    def test_zdata_sdk_is_not_part_of_zevui_framework_source(self):
        # The root project can consume zdata; the *reusable* build helper
        # must not contain ZData algorithms or CSV parser source.
        build_dir = ROOT / "framework"
        for source in build_dir.rglob("*.zig"):
            code = source.read_text()
            self.assertNotIn("zdata.scan.", code)
            self.assertNotIn("zdata.bits.", code)
            self.assertNotIn('src/csv.zig', code)


if __name__ == "__main__":
    unittest.main()
