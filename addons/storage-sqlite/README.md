# Zevui SQLite addon — F6A (experimental)

Standalone Zig 0.17.1 SQLite wrapper. F6B enables opt-in Initializr selection on Linux (Windows/macOS await native verification). Does not change `framework/`, F2 goldens or existing user apps. The API uses explicit C ABI declarations (not `@cImport`); a separately pinned `translate-c` dependency can be considered later if the wrapper grows.

## Build modes

```sh
cd addons/storage-sqlite
zig build test -Dsqlite=off -Doptimize=ReleaseSafe
zig build test -Dsqlite=system -Doptimize=ReleaseSafe    # requires system sqlite3 development library
python3 tools/vendor_sqlite.py                         # once; network + integrity verification
zig build test -Dsqlite=bundled -Doptimize=ReleaseSafe   # offline after vendoring
```

`bundled` (default) compiles a **reviewed local** SQLite 3.54.1 amalgamation (C). It does *not* fetch during compilation. `system` explicitly links `sqlite3`. `off` uses `src/off.zig` and never links SQLite/libc. Zig module name: `zevui_module`. The host must run tests for each supported target; cross-compilation is not execution.

The vendor script downloads an archive from `https://www.sqlite.org/2026/sqlite-amalgamation-3540100.zip` and verifies SQLite's published SHA3-256 **before** extracting only `sqlite3.c` and `sqlite3.h`. Review both files and commit them explicitly when using bundled releases; no mutable URLs/hashes are stored in Zig manifests.

## API and safety

- `Database.open(":memory:")`, `close`, `exec` (fixed trusted SQL only), `prepare`, `enableWal`, `begin`, `commit`, `rollback`
- `Statement.bindText/bindBlob/bindInt64`, `next`, `columnText/columnBlob/columnInt64`, `deinit`
- `KeyValue.init`, `put`, `get(allocator, key)` (**owned** bytes), `remove`
- Prepared parameters use SQLite's `SQLITE_TRANSIENT` copy semantics; NULL is distinct from zero-length text/blob.
- Column views are **borrowed**, valid only until the statement advances/resets/finalizes.
- Explicitly finalize statements before closing the database; `Database.close` reports `Busy` for outstanding statements.
- WAL is not appropriate on network filesystems; caller decides when to enable it. Do not put secrets in plaintext SQLite without additional encryption.

**F6B status:** selected via `--addon sqlite` on Linux and copied with its MIT license notice. Generated builds default to system SQLite; bundled requires the explicit pinned vendor script. Windows/macOS generator selections remain gated until native checks pass; Zig package publication remains pending.
