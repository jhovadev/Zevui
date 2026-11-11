# F6B — SQLite3 in Initializr (experimental source-copy)

F6A proved that the independent native addon has working `off`, `system` and
`bundled` modes on the development host. This phase makes the existing `sqlite`
registry ID selectable **without introducing SQLite into the Zevui core**.

- The original `sqlite` metadata entry is replaced, not duplicated.
- `--addon sqlite` selects a native Zig source, an OFF stub and a verified vendor
  bootstrap script and the MIT license notice. The ZIP is deterministic and contains no C binaries or
  unverified downloadable artifacts.
- Only when sqlite is selected does the producer emit the extra build template
  that creates a separate `storage_sqlite` module, wires it to the app, and
  compiles the addon test root with the same SQLite mode.
- `zig build test -Dsqlite=system` is the default. On Linux install the system
  SQLite3 *development* package. `-Dsqlite=off` links no SQLite C symbols;
  `-Dsqlite=bundled` requires an explicit one-time vendor bootstrap with pinned
  SHA3-256 and file checksums.
- Unselected projects continue to use exactly the old F5 templates and golden
  hashes. Python F2 oracle is intentionally frozen and excludes this C addon.

## Independent smoke

```bash
node packages/initializr-core/scripts/new.mjs sqlite-demo \
  --addon sqlite --output /tmp
cd /tmp/sqlite-demo
zig build test -Dsqlite=system -Doptimize=ReleaseSafe
zig build -Dsqlite=system -Doptimize=ReleaseSafe
zig build test -Dsqlite=off -Doptimize=ReleaseSafe
python3 src/addons/sqlite_vendor.py
zig build test -Dsqlite=bundled -Doptimize=ReleaseSafe
```

`-Dsqlite=system` requires sqlite3 development files on the target.
Downloading the vendor source is explicit; build itself never downloads.
The `sqlite` Initializr option is Linux-only until Windows/macOS native integration
smokes pass; cross-compilation and official published Zig package hashes remain
outside F6B.
