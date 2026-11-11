"""F6D contracts: native portability CI is triggered and produces durable reports."""
from __future__ import annotations

import contextlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts import sqlite_portability_smoke as smoke

ROOT = Path(__file__).resolve().parents[1]


class SqliteCiObservabilityF6D(unittest.TestCase):
    def test_push_and_pr_are_scoped_and_experiments_remain_nonblocking(self):
        workflow = (ROOT / '.github/workflows/sqlite-portability.yml').read_text(encoding='utf-8')
        self.assertIn('  push:\n    branches: [main]', workflow)
        self.assertIn('  pull_request:', workflow)
        self.assertIn("'.github/workflows/sqlite-portability.yml'", workflow)
        self.assertIn('continue-on-error: ${{ matrix.experimental }}', workflow)
        self.assertIn('experimental: false', workflow)
        self.assertIn('experimental: true', workflow)
        self.assertIn('    timeout-minutes: 45', workflow)
        self.assertIn('permissions:\n  contents: read', workflow)
        self.assertIn('actions/upload-artifact@v4', workflow)
        self.assertIn('if: always()', workflow)
        self.assertIn('--report sqlite-native-report.json', workflow)
        self.assertIn('--report sqlite-gui-report.json', workflow)
        addon = json.loads((ROOT / 'addons/storage-sqlite/addon.json').read_text(encoding='utf-8'))
        self.assertEqual(addon['compat']['targets'], ['linux'])

    def test_report_tracks_successful_and_failed_commands(self):
        steps: list[dict] = []
        with patch.object(smoke.subprocess, 'run') as call:
            smoke.run('zig', 'version', cwd=ROOT, steps=steps)
            call.assert_called_once_with(('zig', 'version'), cwd=ROOT, check=True)
        self.assertEqual(len(steps), 1)
        self.assertEqual(steps[0]['status'], 'passed')
        self.assertEqual(steps[0]['argv'], ['zig', 'version'])
        self.assertIsInstance(steps[0]['duration_ms'], int)

        with patch.object(smoke.subprocess, 'run', side_effect=subprocess.CalledProcessError(7, ('zig', 'build'))):
            with self.assertRaises(subprocess.CalledProcessError):
                smoke.run('zig', 'build', cwd=ROOT, steps=steps)
        self.assertEqual(steps[1]['status'], 'failed')
        self.assertIn('error', steps[1])

    def test_report_written_on_gate_failure_and_return_code_is_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'native.json'
            with patch.object(smoke, 'gate', side_effect=RuntimeError('simulated native failure')):
                with patch.object(sys, 'argv', ['sqlite_portability_smoke.py', '--report', str(output)]):
                    with contextlib.redirect_stderr(io.StringIO()):
                        self.assertEqual(smoke.main(), 1)
            report = json.loads(output.read_text(encoding='utf-8'))
            self.assertEqual(report['schema_version'], 1)
            self.assertEqual(report['status'], 'failed')
            self.assertEqual(report['error']['type'], 'RuntimeError')
            self.assertIn('simulated native failure', report['error']['message'])

    def test_report_written_on_gate_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'nested' / 'native.json'
            with patch.object(smoke, 'gate'):
                with patch.object(sys, 'argv', ['sqlite_portability_smoke.py', '--system', '--report', str(output)]):
                    self.assertEqual(smoke.main(), 0)
            report = json.loads(output.read_text(encoding='utf-8'))
            self.assertEqual(report['status'], 'passed')
            self.assertTrue(report['system'])
            self.assertFalse(report['gui'])
            self.assertIsNone(report['error'])


if __name__ == '__main__':
    unittest.main()
