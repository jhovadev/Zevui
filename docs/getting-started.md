# Getting started — Zevui / DVUI + optional ZData

## 1. Install developer tools

Requirements: **Zig 0.17.1**, `just`, Python 3 and a graphics environment
for the SDL3 window. On Arch Linux, `just` is available as a system package:

```sh
sudo pacman -S just
zig version      # expect 0.17.1
just --version
```

The shell recipes use Bash. A Windows developer may execute them under WSL2,
Git Bash or another POSIX shell, but **building under WSL does not validate a
native Windows GUI**. You can also use `zig build` directly without `just`.

## 2. Pin the ZData SDK

On the first checkout, `build.zig.zon` contains the DVUI dependency but has no
ZData URL/hash yet (the packaging hotfix intentionally left it for Zig to
compute using your own installed compiler):

```sh
just setup
# Equivalent:
# zig fetch --save=zdata git+https://github.com/jhovadev/zigdataengine.git
```

The command fetches ZData and updates `.dependencies.zdata` in
`build.zig.zon`. Inspect and **commit the resulting manifest**; it is part of
the reproducible project. You do **not** need `../zig-data-engine` locally.

For a pinned release, consider using a specific ZData commit or tag, and update
it deliberately rather than following a floating main branch.

## 3. Verify and run

```sh
just doctor      # Zig + just versions, dependency wiring
just check       # static checks + Python checks + Zig ReleaseSafe tests
just run         # graphical app on the current host
```

Press **+ Abrir CSV** and pick `testdata/sample_1500.csv`. Use **Ruta** to
enter a path manually (required in `just run-portable`). Click **Graphite** to
cycle Graphite / Light / Contrast, click the accent name to cycle colors, and
use **Compacta** in the page bar to switch table density. This example uses
DVUI for UI, a CSV-specific adapter for field decoding, and ZData's generic
structural scanner and bitmask utilities for header dialect detection.

For direct Zig equivalents without `just`:

```sh
python3 scripts/check_layout.py
zig build test -Doptimize=ReleaseSafe
zig build sdl3-app -Doptimize=ReleaseFast
```

## 4. Run a benchmark

```sh
just bench
zig build bench -Doptimize=ReleaseFast -- /path/to/your.csv
```

CSV parsing currently reads up to **128 MiB** per file into memory and is not
a streaming parser. Performance depends on disk caching, input shape,
allocations and UI work. Measure on the same machine before making any speed
claim against the original CSV Reader.

## 5. Create cross-target artifacts

```sh
just targets
just cross-headless aarch64-linux-gnu
just windows-x64
just sdk-doctor aarch64-macos
just build-portable
```

The full target matrix, restrictions and test plan are in
[cross-compilation.md](cross-compilation.md). Do not run binaries compiled
for a different OS/architecture without an appropriate runtime/emulator.

## 6. Maintain the template

Changes to the SDK API belong in Zig Data Engine, not in this app. Keep
CSV-specific rules, UI state and file dialogs in the example. Before pushing a
change: `just check`, `git diff --check`, test GUI behavior and ensure the
pinned `build.zig.zon` is committed.

See [architecture and testing](integration.md) and
[common errors](troubleshooting.md).

## M0.5 — Configure Zevui applications

Modify `zevui.zon` for application title, identifier, window size and default
theme. `examples/csv-explorer/src/app/identity.zig` reads these values from generated build options.
This file should not be edited for rebranding. Platform overrides can modify
selected window dimensions via `zevui.windows.zon` and `zevui.macos.zon`.

To confirm that the build helper does not intrinsically depend on ZData:

```sh
just minimal   # Compiles an independent DVUI app, no ZData import
```

More details: [build-core.md](build-core.md).
