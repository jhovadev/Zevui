"""Small contracts for the Zevui example; not a substitute for GUI screenshots."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ZevuiUiContracts(unittest.TestCase):
    def test_readme_documents_real_sdk(self):
        readme = (ROOT / "README.md").read_text()
        self.assertTrue(readme.startswith("# Zevui"))
        self.assertIn("zigdataengine", readme)
        self.assertIn("dvui-demo", readme)
        self.assertIn("just run", readme)
        self.assertIn("experimental", readme)

    def test_ui_has_real_empty_state_actions_and_source_row_gutter(self):
        main = (ROOT / "src/main.zig").read_text()
        self.assertIn("brand.title", main)
        self.assertIn("brand.icon_png", main)
        self.assertIn('"+ Abrir archivo"', main)
        self.assertIn('"Introducir ruta"', main)
        self.assertIn('grid.colHeader(.{ .col = 0 }', main)
        self.assertIn('grid.cell(.{ .col = 0, .row = visible_row }', main)
        self.assertIn('index + 1', main)
        self.assertIn('fn searchPanel(', main)
        self.assertIn('if (!state.show_search) return;', main)

    def test_design_tokens_still_pure(self):
        tokens = (ROOT / "src/ui/tokens.zig").read_text()
        self.assertNotIn('@import("dvui")', tokens)
        self.assertIn('density: Density = .compact', tokens)
        self.assertTrue((ROOT / "docs/ui-guidelines.md").is_file())


if __name__ == "__main__":
    unittest.main()
