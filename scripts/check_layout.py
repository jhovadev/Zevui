#!/usr/bin/env python3
"""A light structural check that does not need Zig or network access."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
zon = (root / 'build.zig.zon').read_text()
build = (root / 'build.zig').read_text()
zevui_build = (root / 'framework/build.zig').read_text()
checks = (root / 'examples/csv-explorer/build.zig').read_text()
csv = (root / 'examples/csv-explorer/src/csv.zig').read_text()
if '.zdata = .{' not in zon:
    raise SystemExit('Setup required: zig fetch --save=zdata git+https://github.com/jhovadev/zigdataengine.git')
assert '.fingerprint = 0x525d57945f45ed28' in zon
assert 'dvui-0.6.0-dev-' in zon
assert 'zevui = .{ .path = "framework" }' in zon
assert 'module.addImport("zdata", dep.module("zdata"))' in zevui_build
assert 'csv_tests.root_module.addImport("zdata", zdata_module)' in checks
assert 'module.addImport("dvui", dvui_dep.module("dvui_sdl3"))' in zevui_build
assert 'zevui.addApp(b, config' in build
assert 'zevui.addApp(b, minimal_config' in build
assert (root / "zevui.zon").is_file()
assert 'zdata.scan.structural.Scanner' in csv
assert 'zdata.bits.positions' in csv
assert 'try detectDelimiter(bytes)' in csv
print('Structure OK: Zevui addApp + DVUI SDL3 + optional ZData')
