# Zevui addon registry — F4

The **source of truth** is now `registry/registry.json` plus one `addon.json` per
addon. Standalone official packages live in `addons/<package>/`; inactive
metadata-only entries live in `registry/planned/` and are never selectable.

`python3 tools/build_registry.py --write` generates **two committed, deterministic
artifacts**:

- `registry/catalog.json`: v2 compatibility payload for the existing TS planner,
  SolidStart, and the frozen Python output oracle. Do not edit manually.
- `registry/dist/metadata-0.17.json`: channel metadata containing delivery mode,
  package version and explicit published `url`+`hash` or `null`.

The validation gate `python3 tools/build_registry.py --check` compares byte-for-
byte against the committed artifacts; CI runs it. It rejects duplicate IDs,
unsafe paths, missing sources, conflicting output paths, dependency cycles,
undeclared references, invalid license fields, and incomplete package pins.

## Publishing policy

`status: available` in F4 means **functional and select-able via the current
source-copy compatibility bridge**, not independently published. The two Zig
addons are independent packages and run `zig build test`, but both currently
have `package: null` and `delivery: source-copy`. Users can still download the
same working Zig starter as in F2/F3 without external addon URLs.

**Publishing is fail-closed:** `python3 tools/build_registry.py --require-published`
returns nonzero until every available addon has a verified remote URL and a
real Zig content hash, and consumers use them. Never generate a fake hash.

After publishing a reviewed immutable artifact, run:

```sh
just pin-addon memory_store 'git+https://github.com/ORG/REPO.git#<40-char-commit>'
python3 tools/pin_addon.py memory_store --verify
just registry-build
just registry-manifests-check
just addons-check
```

`tools/pin_addon.py` calls `zig fetch` as an argv array, not via a shell, and
records exactly the resulting content hash. Verification re-fetches content and
fails on mismatch. The explicit transition from `delivery: source-copy` to
`delivery: package`, and replacement of the source-copy renderer in Initializr,
remain **F5 release gates** (not done here). Hashes identify content but are
not a security review; Zig build scripts are executable build-time code.

The package contract is the public module `zevui_module`. The packages avoid
DVUI/SDL/ZData imports. Future SQLite and tray addons must pass their own
native builds and licensing review before changing from `planned`.
