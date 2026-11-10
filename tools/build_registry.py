#!/usr/bin/env python3
"""Build deterministic per-Zig-channel metadata and v2 Initializr compatibility view.

No dependency installation, network access, code execution, or fake content hashes.
All paths are anchored to the checked-in registry roots.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "registry/registry.json"
CATALOG = ROOT / "registry/catalog.json"
METADATA = ROOT / "registry/dist/metadata-0.17.json"
ID = re.compile(r"^[a-z][a-z0-9_-]{1,63}$")
VER = re.compile(r"^\d+\.\d+\.\d+$")
LICENSE = re.compile(r"^(?:[A-Za-z0-9][A-Za-z0-9.+-]*|NOASSERTION)$")
HASH = re.compile(r"^[a-zA-Z0-9._+-]{20,200}$")
KINDS = {"zig", "c-bundled", "c-system", "planned"}
FIELDS = {
    "schemaVersion", "id", "version", "name", "category", "description", "kind",
    "status", "delivery", "default", "provides", "requires", "conflicts",
    "compat", "package", "trust", "license", "files",
}


class RegistryError(ValueError):
    pass


def fail(message: str) -> None:
    raise RegistryError(message)


def safe_path(raw: str) -> Path:
    if not isinstance(raw, str) or not raw or len(raw) > 255 or "\\" in raw or "\x00" in raw:
        fail(f"Invalid registry path {raw!r}")
    if re.fullmatch(r"[A-Za-z0-9_.\-/]+", raw) is None:
        fail(f"Unsafe registry path {raw!r}")
    path = Path(raw)
    if path.is_absolute() or any(part in ("", ".", "..") for part in raw.split("/")):
        fail(f"Path traversal: {raw!r}")
    resolved = (ROOT / path).resolve()
    if not resolved.is_relative_to(ROOT.resolve()):
        fail(f"Registry path escapes root: {raw!r}")
    return resolved


def load_json(relative: str) -> dict:
    path = safe_path(relative)
    if not path.is_file():
        fail(f"Missing manifest: {relative}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (ValueError, UnicodeError) as exc:
        fail(f"Invalid JSON {relative}: {exc}")
    if not isinstance(data, dict):
        fail(f"Object expected in {relative}")
    return data


def validate_addon(path: str, addon: dict, supported: set[str]) -> None:
    if set(addon) != FIELDS or addon.get("schemaVersion") != 1:
        fail(f"Incorrect manifest schema in {path}")
    aid = addon["id"]
    if not isinstance(aid, str) or not ID.fullmatch(aid):
        fail(f"Invalid addon ID in {path}")
    if not isinstance(addon["version"], str) or not VER.fullmatch(addon["version"]):
        fail(f"Invalid addon version: {aid}")
    for field in ("name", "category", "description"):
        if not isinstance(addon[field], str) or not addon[field].strip():
            fail(f"Invalid {field}: {aid}")
    if addon["kind"] not in KINDS or addon["status"] not in {"available", "manual", "planned", "deprecated"}:
        fail(f"Invalid addon kind/status: {aid}")
    if addon["delivery"] not in {"source-copy", "package", "unavailable"}:
        fail(f"Invalid addon delivery: {aid}")
    if type(addon["default"]) is not bool or addon["trust"] not in {"official", "verified", "community"}:
        fail(f"Invalid addon default/trust: {aid}")
    if not isinstance(addon["license"], str) or not LICENSE.fullmatch(addon["license"]):
        fail(f"Invalid SPDX license field: {aid}")
    for key in ("provides", "requires", "conflicts"):
        values = addon[key]
        if not isinstance(values, list) or any(not isinstance(x, str) or not ID.fullmatch(x) for x in values) or len(values) != len(set(values)):
            fail(f"Invalid or repeated {key}: {aid}")
    if aid in addon["requires"] or aid in addon["conflicts"]:
        fail(f"Self-referential dependency/conflict: {aid}")
    compat = addon["compat"]
    if not isinstance(compat, dict) or set(compat) != {"zig", "zevui", "targets"}:
        fail(f"Invalid compat contract: {aid}")
    if not isinstance(compat["zig"], list) or not compat["zig"] or any(x not in supported for x in compat["zig"]):
        fail(f"Unsupported Zig compat: {aid}")
    if not isinstance(compat["zevui"], str) or not VER.fullmatch(compat["zevui"]):
        fail(f"Invalid framework version: {aid}")
    if not isinstance(compat["targets"], list) or not compat["targets"] or len(compat["targets"]) != len(set(compat["targets"])) or any(x not in {"linux", "windows", "macos"} for x in compat["targets"]):
        fail(f"Invalid targets: {aid}")
    pkg = addon["package"]
    if pkg is not None:
        if not isinstance(pkg, dict) or set(pkg) != {"url", "hash"}:
            fail(f"Package must contain url+hash: {aid}")
        if not isinstance(pkg["url"], str) or not pkg["url"].startswith(("git+https://", "https://")) or not isinstance(pkg["hash"], str) or not HASH.fullmatch(pkg["hash"]):
            fail(f"Invalid pinned package: {aid}")
    if addon["delivery"] == "package" and pkg is None:
        fail(f"Publishable addon lacks url+hash: {aid}")
    if addon["status"] == "available" and addon["delivery"] == "unavailable":
        fail(f"Available addon has unavailable delivery: {aid}")
    if addon["status"] != "available" and addon["delivery"] != "unavailable":
        fail(f"Inactive addon cannot be selected: {aid}")
    if addon["status"] != "available" and addon["files"]:
        fail(f"Inactive addon contains files: {aid}")
    if addon["status"] == "available" and addon["license"] == "NOASSERTION":
        fail(f"Available addon needs a declared license: {aid}")
    if not isinstance(addon["files"], list):
        fail(f"Invalid files: {aid}")
    for f in addon["files"]:
        if not isinstance(f, dict) or set(f) != {"from", "to"}:
            fail(f"Invalid file mapping: {aid}")
        src = safe_path(f["from"])
        target = f["to"]
        if not isinstance(target, str) or not target.startswith("src/addons/"):
            fail(f"Unsafe addon destination: {aid}")
        safe_path(target)
        if not src.is_file():
            fail(f"Missing addon source: {f['from']}")
        if addon["delivery"] == "source-copy" and path.startswith("addons/") and not src.is_relative_to((ROOT / Path(path).parent).resolve()):
            fail(f"Addon source outside its package: {aid}")
    if path.startswith("addons/"):
        package_dir = safe_path(str(Path(path).parent))
        if not (package_dir / "build.zig").is_file() or not (package_dir / "build.zig.zon").is_file() or not (package_dir / "src/root.zig").is_file() or not (package_dir / "LICENSE").is_file():
            fail(f"Incomplete independent Zig package: {aid}")


def build_outputs() -> dict[Path, bytes]:
    base = load_json("registry/registry.json")
    required = {"schemaVersion", "registryVersion", "zig", "framework", "supportedZig", "packages", "manifests"}
    if set(base) != required or base["schemaVersion"] != 1 or not VER.fullmatch(base["registryVersion"]):
        fail("Invalid registry root manifest")
    supported = base["supportedZig"]
    if not isinstance(supported, list) or not supported or base["zig"] not in supported or any(not VER.fullmatch(x) for x in supported):
        fail("Invalid supported Zig channel")
    dvui = base["packages"].get("dvui")
    if not isinstance(dvui, dict) or set(dvui) != {"url", "hash"} or not dvui["url"].startswith("git+https://") or not dvui["hash"].startswith("dvui-"):
        fail("Missing reviewed DVUI pin")
    manifest_paths = base["manifests"]
    if not isinstance(manifest_paths, list) or not manifest_paths or len(manifest_paths) != len(set(manifest_paths)):
        fail("Missing/duplicated manifest paths")
    addons = []
    for manifest in manifest_paths:
        if not isinstance(manifest, str) or not (manifest.startswith("addons/") or manifest.startswith("registry/planned/")) or not manifest.endswith(("/addon.json", ".json")):
            fail(f"Unexpected manifest location {manifest!r}")
        item = load_json(manifest)
        validate_addon(manifest, item, set(supported))
        addons.append(item)
    by_id = {item["id"]: item for item in addons}
    if len(by_id) != len(addons):
        fail("Duplicate addon IDs")
    for addon in addons:
        for reference in addon["requires"] + addon["conflicts"]:
            if reference not in by_id:
                fail(f"Unknown reference {reference} in {addon['id']}")
    # Visit *all* addons including planned ones: even unpublished metadata must be consistent.
    visited, visiting = set(), set()
    def visit(aid: str) -> None:
        if aid in visiting:
            fail(f"Dependency cycle involving {aid}")
        if aid in visited:
            return
        visiting.add(aid)
        for req in by_id[aid]["requires"]:
            visit(req)
        visiting.remove(aid)
        visited.add(aid)
    for aid in by_id:
        visit(aid)
    for addon in addons:
        for req in addon["requires"]:
            if by_id[req]["status"] != "available" and addon["status"] == "available":
                fail(f"Active addon depends on unavailable {req}")
        for con in addon["conflicts"]:
            if addon["id"] in by_id[con]["requires"]:
                fail(f"Contradictory dependency and conflict {addon['id']} / {con}")
    files_seen = {}
    for addon in addons:
        for m in addon["files"]:
            if m["to"] in files_seen:
                fail(f"Output collision between {files_seen[m['to']]} and {addon['id']}: {m['to']}")
            files_seen[m["to"]] = addon["id"]
    # Keep the F2 serialized contract unchanged for existing TypeScript and Python oracles.
    legacy_addons = []
    for a in addons:
        legacy_addons.append({
            "id": a["id"], "name": a["name"], "category": a["category"],
            "description": a["description"], "status": a["status"],
            "default": a["default"], "kind": a["kind"], "requires": a["requires"],
            "conflicts": a["conflicts"], "targets": a["compat"]["targets"],
            "zig": a["compat"]["zig"], "zevui": a["compat"]["zevui"],
            "trust": a["trust"], "license": a["license"], "files": a["files"],
        })
    legacy = {"schemaVersion": 2, "zig": base["zig"], "framework": base["framework"],
              "addons": legacy_addons, "registryVersion": base["registryVersion"],
              "supportedZig": supported, "packages": base["packages"]}
    metadata = {"schemaVersion": 1, "registryVersion": base["registryVersion"],
                "channel": "0.17", "supportedZig": supported,
                "packages": base["packages"], "addons": addons}
    return {
        CATALOG: (json.dumps(legacy, indent=2, ensure_ascii=False) + "\n").encode(),
        METADATA: (json.dumps(metadata, indent=2, ensure_ascii=False) + "\n").encode(),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--check", action="store_true", help="fail if committed derived files differ")
    action.add_argument("--write", action="store_true", help="regenerate compatible catalog and channel metadata")
    action.add_argument("--require-published", action="store_true", help="F5 release gate: reject source-copy addons and missing pins")
    args = parser.parse_args(argv)
    try:
        outputs = build_outputs()
        if args.require_published:
            data = json.loads(outputs[METADATA])
            for addon in data["addons"]:
                if addon["status"] == "available" and (addon["delivery"] != "package" or addon["package"] is None):
                    fail(f"Unpublished addon {addon['id']}; F5 gate remains CLOSED")
        for path, expected in outputs.items():
            if args.check:
                if not path.is_file() or path.read_bytes() != expected:
                    fail(f"Outdated generated file: {path.relative_to(ROOT)}; run python3 tools/build_registry.py --write")
            if args.write:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(expected)
        print(f"Registry OK: {len(json.loads(outputs[METADATA])['addons'])} manifests; channel 0.17; "+
              ("published pins required" if args.require_published else "source-copy bridge active for F4"))
        return 0
    except (RegistryError, OSError, TypeError, KeyError) as exc:
        print(f"registry: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
