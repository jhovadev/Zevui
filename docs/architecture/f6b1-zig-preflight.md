# F6B.1 — Toolchain preflight for F6B native SQLite starter

## Symptom

`zig build test -Dsqlite=bundled -Doptimize=ReleaseSafe` can report errors
in `translate_c`, `aro`, `dvui`, and `zevui/build.zig` before SQLite3 C is
compiled:

- `@backingInt` or `@fromBackingInt`: invalid builtin function
- `addPassthruArgs`: missing from `std.Build.Step.Run`
- `.debug`: not a valid optimization tag
- `addOptionPathUntracked`: missing from `std.Build.Step.Options`

This pattern is consistent with an older Zig executable being used to compile
packages pinned for Zig **0.17.1**. It is not evidence of a broken SQLite
amalgamation or a reason to modify package cache contents.

## Reproduce and fix

```sh
cd ~/Documents/sideProjects/zdata-dvui-examples
command -v zig
type -a zig
zig version
zig env
just zig-preflight
```

Select an official Zig 0.17.1 executable in `PATH` and re-run the preflight.
If `zig version` is already 0.17.1, inspect `zig env` for unexpected
`lib_dir`/`std_dir` or multiple Zig binaries, and attach those details to the
issue; do not guess at transitive package fixes.

```sh
just sqlite-addon-check
just sqlite-bundled-check
just sqlite-initializr-check

# Generated starter (use its actual directory):
cd /tmp/sqlite-demo
zig version
python3 src/addons/sqlite_vendor.py --check
zig build test -Dsqlite=bundled -Doptimize=ReleaseSafe
zig build -Dsqlite=bundled -Doptimize=ReleaseSafe
```

**No build claims:** the preflight validates only the executable version; it
does not assert that the target ABI, SQLite compiler, or third-party
packages successfully compile. The legacy cache is not cleared or modified.

This patch is incremental over F6B and adds no runtime dependency or changes
to its generated files, ZIP fingerprints, registry metadata, or addon API.
