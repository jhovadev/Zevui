#!/usr/bin/env python3
"""Zevui source-ownership registry, no network or generator dependency.

Usage: python3 tools/components.py list|verify|catalog [--write]
       python3 tools/components.py add|status <id> --project /path [--dry-run]
       python3 tools/components.py update <id> --project /path [--dry-run]

The registry and local lock are explicitly separate from addon registry/plans.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
REGISTRY = REPO / "registry/components"
CATALOG = REPO / "apps/initializr/src/lib/components.generated.json"
SOURCE_PREFIX = "framework/src/ui/"
TARGET_PREFIX = "src/components/"
ID = re.compile(r"^[a-z][a-z0-9-]{0,39}$")
FILE = re.compile(r"^[a-zA-Z0-9_./-]{1,200}$")


class ComponentError(Exception):
    pass


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def safe_rel(path: object, prefix: str) -> str:
    if not isinstance(path, str) or not FILE.fullmatch(path):
        raise ComponentError(f"Invalid path: {path!r}")
    if not path.startswith(prefix) or path.startswith("/") or ".." in path.split("/"):
        raise ComponentError(f"Path outside {prefix}: {path}")
    if not path.endswith(".zig"):
        raise ComponentError(f"Only Zig source files are installable: {path}")
    if any(part in ("", ".") for part in path.split("/")):
        raise ComponentError(f"Noncanonical path: {path}")
    return path


def read_registry(repo: Path = REPO) -> list[dict]:
    directory = repo / "registry/components"
    manifests = []
    seen_targets = set()
    seen_ids = set()
    for manifest_path in sorted(directory.glob("*.json")):
        if manifest_path.is_symlink():
            raise ComponentError(f"Symlinked manifest: {manifest_path}")
        obj = json.loads(manifest_path.read_text(encoding="utf8"))
        component_id = obj.get("id")
        if not isinstance(component_id, str) or not ID.fullmatch(component_id) or manifest_path.stem != component_id:
            raise ComponentError(f"Invalid ID or filename: {manifest_path.name}")
        if component_id in seen_ids or obj.get("schema") != 1:
            raise ComponentError(f"Invalid component schema or duplicate: {component_id}")
        seen_ids.add(component_id)
        if obj.get("zig") != "0.17.1" or obj.get("status") not in ("stable", "experimental"):
            raise ComponentError(f"Invalid compatibility/status for {component_id}")
        if not all(isinstance(obj.get(k), str) and obj[k] for k in ("name", "category", "description", "renderer", "usage")):
            raise ComponentError(f"Missing registry metadata: {component_id}")
        files = obj.get("files")
        if not isinstance(files, list) or not files:
            raise ComponentError(f"No files for {component_id}")
        for entry in files:
            source = safe_rel(entry.get("source"), SOURCE_PREFIX)
            target = safe_rel(entry.get("target"), TARGET_PREFIX)
            if target in seen_targets:
                raise ComponentError(f"Target collision: {target}")
            seen_targets.add(target)
            f = repo / source
            if f.is_symlink() or not f.is_file() or not f.resolve().is_relative_to(repo.resolve()):
                raise ComponentError(f"Missing or unsafe source: {source}")
        manifests.append(obj)
    if not manifests:
        raise ComponentError("No component manifests")
    return manifests


def catalog_bytes(manifests: list[dict], repo: Path = REPO) -> bytes:
    entries = []
    for manifest in manifests:
        copies = []
        for file in manifest["files"]:
            data = (repo / file["source"]).read_bytes()
            copies.append({"target": file["target"], "sha256": digest(data), "source": data.decode("utf8")})
        entries.append({k: manifest[k] for k in ("id", "name", "category", "description", "status", "zig", "renderer", "usage")} | {"files": copies})
    return (json.dumps({"schema": 1, "components": entries}, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode("utf8")


def lock_path(project: Path) -> Path:
    return project / ".zevui/components.lock.json"


def load_lock(project: Path) -> dict:
    lock = lock_path(project)
    if lock.is_symlink() or lock.parent.is_symlink():
        raise ComponentError("Refusing symlinked component lock/directory")
    if not lock.exists():
        return {"schema": 1, "components": {}}
    data = json.loads(lock.read_text(encoding="utf8"))
    if data.get("schema") != 1 or not isinstance(data.get("components"), dict):
        raise ComponentError("Unsupported component lock")
    return data


def checked_target(project: Path, rel: str) -> Path:
    safe_rel(rel, TARGET_PREFIX)
    # Ensure no symlinked ancestor (including src/components) can redirect writes.
    out = project
    for part in rel.split("/"):
        out = out / part
        if out.is_symlink():
            raise ComponentError(f"Symlinked destination: {out}")
    if not out.resolve().is_relative_to(project.resolve()):
        raise ComponentError(f"Destination escapes project: {rel}")
    return out


def selected(manifests: list[dict], component_id: str) -> dict:
    for manifest in manifests:
        if manifest["id"] == component_id:
            return manifest
    raise ComponentError(f"Unknown component: {component_id}")


def install(manifest: dict, project: Path, update: bool, dry_run: bool = False) -> list[str]:
    if not project.is_dir() or project.is_symlink():
        raise ComponentError(f"Project directory does not exist: {project}")
    project = project.resolve()
    lock = load_lock(project)
    previous = lock["components"].get(manifest["id"], {})
    if previous and (not isinstance(previous, dict) or not isinstance(previous.get("files"), dict)):
        raise ComponentError("Malformed component lock entry")
    before = previous.get("files", {})
    planned = []
    new_hashes = {}
    for f in manifest["files"]:
        dest = checked_target(project, f["target"])
        content = (REPO / f["source"]).read_bytes()
        target_hash = digest(content)
        actual_hash = digest(dest.read_bytes()) if dest.exists() and dest.is_file() else None
        recorded = before.get(f["target"])
        if dest.exists() and not dest.is_file():
            raise ComponentError(f"Not a regular file: {dest}")
        if recorded is not None and actual_hash != recorded:
            raise ComponentError(f"Locally modified, refusing to overwrite: {f['target']}")
        if actual_hash is not None and recorded is None and actual_hash != target_hash:
            raise ComponentError(f"Unmanaged existing file: {f['target']}")
        if update is False and recorded is not None and actual_hash != target_hash:
            raise ComponentError(f"Update needed for {f['target']}; use update")
        if actual_hash != target_hash:
            planned.append((dest, content))
        new_hashes[f["target"]] = target_hash
    if update and not previous:
        raise ComponentError(f"Component not installed: {manifest['id']}")
    messages = [str(dest.relative_to(project)) for dest, _ in planned]
    if dry_run:
        return messages
    # Preflight and source integrity finish before writing any output. Writes use
    # same-filesystem temporary files and replace; lock is written last.
    for dest, content in planned:
        dest.parent.mkdir(parents=True, exist_ok=True)
        checked_target(project, str(dest.relative_to(project)))
        fd, tmp = tempfile.mkstemp(prefix=".zevui-", dir=dest.parent)
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(content)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(tmp, dest)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
    lock["components"][manifest["id"]] = {"files": new_hashes, "version": 1}
    lockfile = lock_path(project)
    if lockfile.parent.is_symlink():
        raise ComponentError("Refusing symlinked .zevui directory")
    lockfile.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".zevui-lock-", dir=lockfile.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write((json.dumps(lock, indent=2, sort_keys=True) + "\n").encode())
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(tmp, lockfile)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)
    return messages


def status(manifest: dict, project: Path) -> str:
    lock = load_lock(project)
    record = lock["components"].get(manifest["id"])
    if record is None:
        return "not installed"
    if not isinstance(record, dict) or not isinstance(record.get("files"), dict):
        return "invalid lock"
    outdated = False
    for file in manifest["files"]:
        path = checked_target(project, file["target"])
        recorded = record["files"].get(file["target"])
        if recorded is None or not path.is_file() or digest(path.read_bytes()) != recorded:
            return "modified/missing"
        if digest((REPO / file["source"]).read_bytes()) != recorded:
            outdated = True
    return "update available" if outdated else "clean"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["list", "verify", "catalog", "add", "update", "status"])
    parser.add_argument("component", nargs="?")
    parser.add_argument("--project", type=Path)
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    try:
        manifests = read_registry()
        if args.command == "list":
            for m in manifests:
                print(f"{m['id']:12} {m['status']:13} {m['name']}")
        elif args.command in ("verify", "catalog"):
            data = catalog_bytes(manifests)
            if args.write:
                CATALOG.parent.mkdir(parents=True, exist_ok=True)
                CATALOG.write_bytes(data)
                print(f"Wrote {CATALOG.relative_to(REPO)}")
            elif not CATALOG.is_file() or CATALOG.read_bytes() != data:
                raise ComponentError("Component catalog is out of sync: run python3 tools/components.py catalog --write")
            else:
                print(f"Verified {len(manifests)} source-owned component manifests and catalog")
        else:
            if args.component is None or args.project is None:
                parser.error("add/update/status require <id> --project PATH")
            m = selected(manifests, args.component)
            if args.command == "status":
                print(f"{m['id']}: {status(m, args.project)}")
            else:
                touched = install(m, args.project, args.command == "update", args.dry_run)
                print(f"{args.command} {m['id']}: {'dry-run' if args.dry_run else 'done'}; {len(touched)} file(s) to write")
                for item in touched:
                    print(f"  {item}")
        return 0
    except (ComponentError, OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"zevui components: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
