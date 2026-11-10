#!/usr/bin/env python3
"""Assert the PE executable uses IMAGE_SUBSYSTEM_WINDOWS_GUI (2), not CUI (3).

Checks the linked binary rather than inferring behavior from build flags.
Does not run the binary and therefore works from Linux cross-build hosts.
"""
import argparse
from pathlib import Path
import struct


def pe_subsystem(path: Path) -> int:
    data = path.read_bytes()
    if len(data) < 128 or data[:2] != b'MZ':
        raise ValueError('not a DOS/PE executable')
    pe_offset = struct.unpack_from('<I', data, 0x3C)[0]
    if pe_offset + 24 + 70 > len(data) or data[pe_offset:pe_offset+4] != b'PE\0\0':
        raise ValueError('invalid PE header')
    opt = pe_offset + 24
    magic = struct.unpack_from('<H', data, opt)[0]
    if magic not in (0x10B, 0x20B):
        raise ValueError('unsupported PE optional header')
    return struct.unpack_from('<H', data, opt + 68)[0]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('exe', nargs='?', type=Path, default=Path('dist/x86_64-windows-gnu/bin/zevui-csv-explorer.exe'))
    parser.add_argument('--console', action='store_true', help='expect Windows console subsystem instead')
    args = parser.parse_args()
    actual = pe_subsystem(args.exe)
    desired = 3 if args.console else 2
    label = {2: 'GUI (no console)', 3: 'console'}.get(actual, f'unknown ({actual})')
    print(f'{args.exe}: PE subsystem {actual} ({label})')
    if actual != desired:
        parser.exit(1, f'Expected PE subsystem {desired}; got {actual}\n')


if __name__ == '__main__':
    main()
