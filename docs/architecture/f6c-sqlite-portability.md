# F6C — Reproducible Zig toolchain and native SQLite portability gates

## Toolchain

Generated projects now include `mise.toml` with an **exact** Zig `0.17.1` pin.
The existing `build.zig.zon` `minimum_zig_version` is only a lower bound;
`mise.toml` allows selecting the exact version where mise is installed.
Mise is not a runtime or build dependency: developers can install Zig manually.
For a project in `/tmp`, run `mise install` or `mise exec -- zig build` inside
that project; do not rely on a parent's tool version configuration.

This is the **only intentional addition** to frozen F2/F5 starter outputs. The
historic oracle and its hashes stay untouched. Tests compare all the old files
byte-for-byte, then assert the new `mise.toml` independently. Normal and SQLite
starters use the same canonical planner path and deterministic ZIP renderer.

## F6C.1: prevent stale compiled Initializr in `just check`

F6C adds `mise.toml` in both the TypeScript planner and the TypeScript
renderer. `just check` runs Python tests which call the **compiled**
`packages/initializr-core/dist/*.js` CLI, so an old F6B build can cause false
failures (`mise.toml` missing) even while the F6C sources are correct.

`just check` now invokes `just registry-check` **before** Python discovery.
This deterministically compiles the canonical Initializr and validates the
registry, with no downloads. The TypeScript toolchain must already be installed
(`just initializr-setup` once). `just ecosystem-check` can still be run
independently. No legacy oracle, SQLite C source or generated project behavior
is modified by this gate-order fix.

## Native portability gate (no SQLite vendor download)

After `just registry-check`, execute on a native host:

```sh
python3 scripts/sqlite_portability_smoke.py --system  # Linux with sqlite3 dev libs
python3 scripts/sqlite_portability_smoke.py           # Windows/macOS, bundled+off
python3 scripts/sqlite_portability_smoke.py --gui     # optional full GUI build
```

The gate verifies Zig 0.17.1, validates the *committed* SQLite 3.54.1 amalgamation
and its pinned checksums, compiles and runs isolated addon tests, generates a
fresh starter using the production CLI, copies the verified C sources into the
temporary project, validates them again, and compiles/runs `off` and `bundled`.
`--system` additionally exercises dynamic/system SQLite linkage, where the host
provides the development libraries. It never downloads from the network, edits
third-party caches, or runs foreign-target binaries.

CI (`.github/workflows/sqlite-portability.yml`) executes the **native** gates
on ubuntu-latest, windows-latest, macos-15 (Apple Silicon) and
macos-15-intel. Linux is required; Windows/macOS
are explicitly experimental (`continue-on-error`), and the full GUI compile is
an additional non-gating diagnostic. Zig may fetch pinned DVUI dependencies on
a cold cache and writes Zig caches; only the SQLite vendor source is kept
strictly offline and checksum verified. Passing the addon gate does not prove SDL3
packaging, notarization, codesigning, Windows Installer, or runtime GUI behavior.

## Release criteria still open

- Review real Windows x64 native logs for `bundled` and `off`.
- Review real macOS arm64 **and** Intel native logs for `bundled` and `off`.
- Explicitly test `system` where SDKs and SQLite development headers/libraries exist.
- Verify actual GUI launch, filesystem permissions, binary packaging and SDKs.
- Only then extend `addons/storage-sqlite/addon.json` target compatibility to
  Windows/macOS and regenerate registry metadata (do not edit the catalog by hand).

## Third-party C source integrity

`addons/storage-sqlite/vendor/sqlite3.c` and `sqlite3.h` are pinned third-party
files. A trailing-space warning from `git diff --check` on these files is **not**
a reason to modify the amalgamation, because modifications would invalidate the
SHA-256 provenance checks. Keep vendor files unmodified. To gate our own changes:

```sh
git diff --cached --check -- . ':(exclude)addons/storage-sqlite/vendor/sqlite3.c' ':(exclude)addons/storage-sqlite/vendor/sqlite3.h'
python3 addons/storage-sqlite/tools/vendor_sqlite.py --check
```
