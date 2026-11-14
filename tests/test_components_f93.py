"""F9.3: regress the native Zig CLI initialization prerequisite and smoke harness."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ComponentsF93Tests(unittest.TestCase):
    def test_init_requires_existing_zig_project_and_explains_it(self):
        cli = (ROOT / 'packages/zevui-cli/src/main.zig').read_text()
        self.assertIn('Missing build.zig in --project directory.', cli)
        self.assertIn('zevui init only configures components', cli)
        self.assertIn('checkKind(io, build)', cli)

    def test_smoke_has_real_install_integrity_and_edit_guards(self):
        script = (ROOT / 'scripts/components_cli_smoke.py').read_text()
        just = (ROOT / 'justfile').read_text()
        self.assertIn('@components-cli-smoke:', just)
        self.assertIn('scripts/components_cli_smoke.py --cli', just)
        for op in ('"init"', '"add"', '"doctor"', '"diff"', '"update"'):
            self.assertIn(op, script)
        self.assertIn('hashlib.sha256', script)
        self.assertIn('TemporaryDirectory', script)
        self.assertIn('edited.read_bytes() == edited_bytes', script)
        self.assertIn('assert lock_path.read_bytes() == lock_bytes', script)

    def test_skills_remain_byte_identical(self):
        skills = [ROOT / x for x in (
            'skills/zevui-components/SKILL.md',
            '.agents/skills/zevui-components/SKILL.md',
            'packages/zevui-cli/SKILL.md',
        )]
        self.assertEqual(len({p.read_bytes() for p in skills}), 1)
        self.assertIn('does not scaffold one', skills[0].read_text())


if __name__ == '__main__':
    unittest.main()
