# F6A — native SQLite3 storage addon (experimental)

Status: **source patch delivered; Zig 0.17.1 native compilation not yet verified in the assistant environment**. Do not publish as official/available until target-specific gates pass. F5 committed baseline: `e44f68e`.

## Scope and decision

- New standalone `addons/storage-sqlite/` package: `zevui_module`, with `-Dsqlite=bundled|system|off`.
- `bundled` uses SQLite 3.54.1 amalgamation with **SHA3-256 pinned and verified**; download occurs only from explicit Python tool, never during build. Preserve files and provenance in Git before release.
- `system` links target-native sqlite3, `off` compiles stub without importing/using native symbols or libc.
- Stable C ABI `extern "c"` declarations for the small set of SQLite3 entry points, rather than Zig 0.17-deleted `@cImport`. This F6A intentionally does not introduce an unverified `translate-c` package URL/hash; verify that strategy separately before expanding the C surface.
- Prepared statements and `SQLITE_TRANSIENT` binding, transaction begin/commit/rollback, optional WAL, minimal KV adapter. Borrowed column views vs owned KV `get()` are documented.
- No edits to framework build core, compatibility Initializr asset paths, F2 fixtures or frozen generator. Registry still reports sqlite **planned**, because the Initializr does not yet know how to bundle/link C source. This is intentional, not a production launch.

## Gates

```sh
just sqlite-addon-check              # -Dsqlite=off and system
just sqlite-vendor                    # network, verified SQLite 3.54.1 zip, explicit opt-in
just sqlite-bundled-check            # C amalgamation builds + native tests
just check
just ecosystem-check
just initializr-build
just minimal
just build
```

Important: Windows/macOS native tests and cross-target link checks remain pending. The initial explicit C ABI must be audited against the vendored sqlite3.h. Do not rely on `zig build` without tests or rename this to F6 final.

## F6B follow-up (only after F6A native gates)

- Extend registry schema with a reviewed C addon delivery model that can express `bundled/system/off` at generation time without faking pins or mutating F2 goldens.
- Add generated build modules and C assets only for selected SQLite, share planner across CLI and SolidStart, and test offline project builds.
- Validate WAL durability, prepared statement ownership, busy/locking semantics, and Windows/macOS native tests.
- Decide whether to pin official `translate-c` package or retain narrow manually audited ABI; never use `@cImport`.
