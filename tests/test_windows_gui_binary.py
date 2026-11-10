"""Pure Python fixture tests for PE header inspection."""
import struct
import tempfile
import unittest
from pathlib import Path

from scripts.verify_windows_gui import pe_subsystem


class WindowsGuiTests(unittest.TestCase):
    def check_fixture(self, subsystem):
        data = bytearray(200)
        data[:2] = b'MZ'
        struct.pack_into('<I', data, 0x3C, 64)
        data[64:68] = b'PE\0\0'
        struct.pack_into('<H', data, 64+24, 0x20B)
        struct.pack_into('<H', data, 64+24+68, subsystem)
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/'demo.exe'
            path.write_bytes(data)
            return pe_subsystem(path)

    def test_gui_pe_subsystem(self):
        self.assertEqual(self.check_fixture(2), 2)

    def test_console_pe_subsystem(self):
        self.assertEqual(self.check_fixture(3), 3)

    def test_reject_malformed_pe(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/'bad.exe'
            path.write_bytes(b'not a PE')
            with self.assertRaises(ValueError):
                pe_subsystem(path)
