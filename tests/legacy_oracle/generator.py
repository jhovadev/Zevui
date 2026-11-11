"""Zevui Initializr: standalone Zig project scaffolding, stdlib-only.

Important: this generator is *development tooling*. Generated projects use only
Zig build and do not need Python or the generator to compile.
"""
from __future__ import annotations

import io
import json
import re
import secrets
import shutil
import tempfile
import zipfile
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = json.loads((ROOT / 'registry/catalog.json').read_text())
# Frozen F2/F3 oracle: the production TypeScript generator alone supports new addons.
AVAILABLE = frozenset(a['id'] for a in CATALOG['addons'] if a['id'] in {'memory_store', 'design_tokens'} and a['status'] == 'available')
NAME = re.compile(r'^[a-z][a-z0-9_-]{1,31}$')
ORG = re.compile(r'^[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*)+$')
VERSION = re.compile(r'^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')


class InputError(ValueError):
    pass


def validate(data: dict) -> dict:
    if not isinstance(data, dict):
        raise InputError('Expected a JSON object')
    name = data.get('name', 'my-zevui-app')
    title = data.get('title', 'My Zevui App')
    org = data.get('organization', 'dev.example')
    version = data.get('version', '0.1.0')
    addons = data.get('addons', ['design_tokens'])
    for field, pattern, val in [('name', NAME, name), ('organization', ORG, org), ('version', VERSION, version)]:
        if not isinstance(val, str) or not pattern.fullmatch(val):
            raise InputError(f'Invalid {field}: {val!r}')
    if not isinstance(title, str) or not (1 <= len(title) <= 80) or any(ord(c) < 32 for c in title):
        raise InputError('Title must contain 1-80 printable characters')
    if not isinstance(addons, list) or any(not isinstance(a, str) for a in addons):
        raise InputError('addons must be an array of IDs')
    if len(addons) != len(set(addons)):
        raise InputError('Duplicate addons')
    unsupported = set(addons) - AVAILABLE
    if unsupported:
        raise InputError('Addon not yet supported: ' + ', '.join(sorted(unsupported)))
    fp = data.get('fingerprintId')
    if fp is not None and (type(fp) is not int or fp < 1 or fp >= 0xffffffff):
        raise InputError('fingerprintId must be an unsigned u32 excluding 0 and 0xffffffff')
    return {'name': name, 'title': title, 'organization': org,
            'version': version, 'addons': sorted(addons), 'fingerprintId': fp}


def zig_string(s: str) -> str:
    # ZON/Zig string escapes: JSON is compatible for normal printable UTF-8.
    return json.dumps(s, ensure_ascii=False)


def fingerprint(name: str, fingerprint_id: int | None = None) -> str:
    # Zig Package.Fingerprint: low u32 random ID, high u32 CRC32(name).
    # 0 and 0xffffffff are reserved IDs. Generated once per project.
    i = fingerprint_id if fingerprint_id is not None else secrets.randbelow(0xfffffffe) + 1
    return f'0x{((zlib.crc32(name.encode()) << 32) | i):016x}'


def contents(data: dict) -> dict[str, bytes]:
    p = validate(data)
    name, title, org, version = (p[k] for k in ('name', 'title', 'organization', 'version'))
    addons = set(p['addons'])
    files = {}
    for path in ('zevui/build.zig', 'zevui/config.zig'):
        files[path] = (ROOT / 'templates/compat' / path).read_bytes()
    files['src/main.zig'] = (ROOT / 'templates/compat/minimal/main.zig').read_bytes()
    addon_test_entries = ''.join(', "src/addons/%s.zig"' % addon for addon in sorted(addons))
    files['build.zig'] = '''const std = @import("std");
const zevui = @import("zevui/build.zig");

pub fn build(b: *std.Build) void {
    const cfg: zevui.Config = @import("zevui.zon");
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const portable = b.option(bool, "portable-gui", "Disable optional DVUI native dependencies") orelse false;
    const windows_console = b.option(bool, "windows-console", "Enable Windows debug console") orelse false;
    _ = zevui.addApp(b, cfg, .{
        .target = target,
        .optimize = optimize,
        .root_source_file = "src/main.zig",
        .portable_gui = portable,
        .windows_console = windows_console,
    });
    const tests = b.step("test", "Run Zevui configuration and addon tests");
    inline for (.{ "zevui/config.zig"ADDON_TESTS }) |path| {
        const unit = b.addTest(.{ .root_module = b.createModule(.{
            .root_source_file = b.path(path), .target = target, .optimize = optimize,
        }) });
        tests.dependOn(&b.addRunArtifact(unit).step);
    }
}
'''.replace('ADDON_TESTS', addon_test_entries).encode()
    files['zevui.zon'] = f'''.{{
    .identity = .{{
        .name = {zig_string(name)},
        .title = {zig_string(title)},
        .display_name = {zig_string(title)},
        .short_name = "APP",
        .screen_name = "Home",
        .version = {zig_string(version)},
        .organization = {zig_string(org)},
        .application = {zig_string(name)},
    }},
    .window = .{{ .width = 1100, .height = 720, .min_width = 640, .min_height = 480 }},
    .appearance = .{{ .theme = "graphite", .accent = "lavender", .density = "compact" }},
    .modules = .{{ .zdata = false }},
}}
'''.encode()
    # Package pins are owned by the reviewed registry, never inferred from strings.
    dvui = CATALOG['packages']['dvui']
    dvui_block = f'\n            .url = {zig_string(dvui["url"])},\n            .hash = {zig_string(dvui["hash"])},\n'
    files['build.zig.zon'] = f'''.{{
    .name = .{name.replace('-', '_')},
    .version = {zig_string(version)},
    .fingerprint = {fingerprint(name.replace('-', '_'), p['fingerprintId'])},
    .minimum_zig_version = "0.17.1",
    .dependencies = .{{
        .dvui = .{{{dvui_block}        }},
    }},
    .paths = .{{ "" }},
}}
'''.encode()
    instructions = []
    # Use only trusted registry file mappings. Never execute addon scripts.
    for addon in CATALOG['addons']:
        if addon['id'] not in addons:
            continue
        for entry in addon['files']:
            source_path = ROOT / entry['from']
            output_path = entry['to']
            files[output_path] = source_path.read_bytes()
            import_path = output_path.removeprefix('src/')
            if addon['id'] == 'memory_store':
                files['src/main.zig'] += b'\ncomptime { _ = @import("addons/memory_store.zig").MemoryStore(64, 96, 1024); }\n'
                instructions.append('Memory Store: @import("addons/memory_store.zig").MemoryStore(64, 96, 1024)')
            else:
                files['src/main.zig'] += ('\ncomptime { _ = @import(' + zig_string(import_path) + '); }\n').encode()
                instructions.append(f'{addon["name"]}: @import({zig_string(import_path)})')
    files['README.md'] = (f'# {title}\n\nGenerated with **Zevui Initializr** (Zig 0.17.1 / DVUI + SDL3).\n\n'
        'This is a standalone Zig project; no Zevui CLI or Python is needed to build.\n\n'
        '```sh\nzig build\nzig build run\nzig build -Dportable-gui=true\n```\n\n'
        'Addons:\n' + ''.join(f'- {line}\n' for line in instructions) + '\n'
        'The SDL3 GUI may require native graphics libraries/SDKs for your target.\n'
        'Windows uses the GUI subsystem by default; `-Dwindows-console=true` enables a debug console.\n'
        'Generated from the M0.5 local Build Core; the Zevui package is not yet published.\n').encode()
    files['.gitignore'] = b'.zig-cache/\nzig-out/\ndist/\n'
    return files


def archive(data: dict) -> bytes:
    p = validate(data)
    files = contents(p)
    output = io.BytesIO()
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as z:
        for key, value in sorted(files.items()):
            info = zipfile.ZipInfo(p['name'] + '/' + key, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            z.writestr(info, value)
    return output.getvalue()


def create_directory(data: dict, destination: Path) -> Path:
    p = validate(data)
    dest = destination / p['name']
    if dest.exists():
        raise FileExistsError(f'Destination already exists: {dest}')
    # Validate all paths before creating files (fixed, trusted generator paths).
    files = contents(p)
    dest.mkdir(parents=True)
    try:
        for name, value in files.items():
            target = dest / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(value)
    except Exception:
        shutil.rmtree(dest)
        raise
    return dest
