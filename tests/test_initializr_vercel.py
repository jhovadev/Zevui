"""F7 deployment contract for monorepo SolidStart + private Nitro server assets."""
from __future__ import annotations
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class InitializrVercelContracts(unittest.TestCase):
    def test_root_vercel_config_uses_build_output_api(self):
        cfg = json.loads((ROOT / "vercel.json").read_text())
        self.assertIsNone(cfg["framework"])
        self.assertIn("apps/initializr", cfg["installCommand"])
        self.assertEqual(cfg["buildCommand"], "node apps/initializr/scripts/vercel-build.mjs")
        script = (ROOT / "apps/initializr/scripts/vercel-build.mjs").read_text()
        self.assertIn("NITRO_PRESET: 'vercel'", script)
        self.assertIn("config.json", script)
        self.assertIn(".vercel/output", script)

    def test_server_assets_are_private_and_allowlisted(self):
        stage = (ROOT / "apps/initializr/scripts/stage-assets.mjs").read_text()
        server = (ROOT / "apps/initializr/src/lib/generator.server.ts").read_text()
        vite = (ROOT / "apps/initializr/vite.config.ts").read_text()
        self.assertIn("requiredSources(plan)", stage)
        self.assertIn("realpath(source)", stage)
        self.assertIn("isFile()", stage)
        self.assertIn("/__gitignore", stage)
        self.assertIn('useKV("assets:zevui")', server)
        self.assertIn('getItemRaw<Uint8Array>', server)
        self.assertIn("serverAssets:", vite)
        self.assertIn(".zevui-server-assets/", (ROOT / ".gitignore").read_text())
        self.assertIn("4_400_000", (ROOT / "apps/initializr/src/routes/api/generate.ts").read_text())

    def test_legacy_generator_and_zip_format_are_preserved(self):
        generator = (ROOT / "packages/initializr-core/src/generator.ts").read_text()
        self.assertIn("zipProject(generated: GeneratedProject)", generator)
        self.assertIn("u16(local, 8, 0)", generator)  # historical STORE
        self.assertNotIn("node:zlib", generator)


if __name__ == "__main__":
    unittest.main()
