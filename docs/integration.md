# Architectural boundary: UI, formats and SDK

```text
DVUI + SDL3 (src/main.zig)
    ├── search.zig           filters / numeric mergesort / UI budgets
    └── csv.zig              CSV rules, errors, decoded fields
          ├── zdata.scan.structural.Scanner  (structural marks outside quotes)
          └── zdata.bits.positions          (absolute structural offsets)

ZData is independent of CSV, DVUI and SDL.
```

The sniffer walks chunks of 64 bytes and stops when it finds an unquoted record ending. It counts comma, semicolon and tab candidates on the first logical row. A quote pair spanning a chunk boundary is handled by the SDK's retained state. CSV field decoding remains in `nextField()`.

## Test plan

- `zig build test` verifies parser/search behavior using the **actual package import**.
- `zig build test -Doptimize=ReleaseSafe` checks arithmetic/bounds in safe mode.
- `zig build bench -Doptimize=ReleaseFast -- /path/file.csv` measures loading, scanning and sorting; compare with the original reader on the same host.
- GUI smoke: open 1,500-row fixture, search, sort numeric, toggle visibility, open a second file, close.
- Pathological CSV: BOM, CRLF, doubled quotes at 64-byte boundaries, header with literal newline, malformed quotes, empty fields and huge headers.

## Not implemented

- SIMD CSV parsing / row index, UTF-8 validation, Arrow, mmap, streaming parsing, multithread processing.
- SDK-owned query/sort planner. Those algorithms remain application-local until shared generically with measured value.

## Developer interface and packaging

The app depends on the **public ZData Zig module**, not a vendored copy:

```zig
const zdata_dep = b.dependency("zdata", .{ .target = target, .optimize = optimize });
const zdata_module = zdata_dep.module("zdata");
```

It is pinned into `build.zig.zon` with `just setup`. Updating the ZData revision
changes the package manifest: review that diff and rerun tests before merging.
The `test-compile` step in `build.zig` compiles `src/csv.zig` and
`src/search.zig` tests without executing foreign-architecture code.

For a runtime GUI demonstration use `just run`; for cross targets see the
[cross-compilation guide](cross-compilation.md). Build recipes are intentionally
separated from verification and release promises.

## UI layer (M0.2)

`src/ui/tokens.zig` is independent from both ZData and DVUI: tokens, WCAG
contrast checks, appearance and density. `src/ui/hooks.zig` provides explicit
state handles with no React-style lifecycle. `src/ui/dvui_style.zig` converts
tokens to DVUI and `src/ui/components.zig` centralizes widget variants while
preserving the call-site `@src()` widget ID. See [design-system.md](design-system.md).

Portable cross builds disable optional native dialogs; the app keeps a path
input fallback so the SDK demonstration still works. GUI portability remains
experimental until native target-machine validation.
