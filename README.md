# Zevui

**A native Zig desktop starter using [DVUI](https://github.com/david-vanderson/dvui), [SDL3](https://www.libsdl.org/), and [Zig Data Engine (ZData)](https://github.com/jhovadev/zigdataengine).**

Zevui is an **unofficial, example-driven template**, not a replacement for DVUI or a component of ZData. Its first application, **CSV Explorer**, is a small but usable data viewer: a compact grid, on-demand search, column tools, and a multi-theme design system.

> **Status:** Z0 registry + independent planner (after M0.7.1) · **Zig 0.17.1** · native desktop UI · MIT. Linux x86-64 has been exercised by the project author; other cross-build targets need target-host validation. Names and APIs are subject to change.

## Zevui Initializr — generate your own Zig app

Zevui now includes a local, Spring Initializr-style project generator with an addon catalog. It produces self-contained Zig sources from selected features, with native DVUI/SDL3 and a typed `zevui.zon` configuration. **The generated app needs no Python or Zevui CLI to compile.**

```sh
# Node.js 24+ and Bun are required only for the SolidStart generator website.
just initializr           # installs JS dependencies on first run, then serves 127.0.0.1:8765
just initializr-check     # Python generator/bridge contract tests
just initializr-build     # typecheck + production build (after setup)

# Python-only alternatives, no Node/Bun:
just initializr-legacy    # previous local UI on port 8765
python3 -m initializr.cli my-application --addon memory_store --addon design_tokens
cd my-application && zig build run
```

Z0 adds a reviewed [addon registry](registry/README.md) and a pure TypeScript
[project planner](packages/initializr-core/src/index.ts). The SolidStart UI now
supports file-tree previews and shared configuration URLs. The project ZIP is
still emitted by the Python generator; the planner and ZIP executor have explicit
parity tests and are not yet a single execution engine.

```sh
just registry-check     # pure planner + official registry verification
just ecosystem-check    # plus legacy ZIP generator contract tests
```

Read [Z0 ecosystem design and APIs](docs/ecosystem-z0.md).

The web UI lives in [`apps/initializr/`](apps/initializr/) and has SolidStart API routes at `/api/catalog`, `/api/metadata`, `/api/plan` and `/api/generate`. Generation remains in [`initializr/generator.py`](initializr/generator.py), called through [`initializr/bridge.py`](initializr/bridge.py) (bounded stdin JSON → binary ZIP). **SolidStart is for developer tooling only; it is not embedded in generated DVUI desktop apps.**

Supported generated addons: `memory_store` (bounded volatile KV) and `design_tokens` (pure Zig multitheme tokens). SQLite, tray, bundle and ZData appear in the catalog with explicit non-ready statuses. See [Initializr architecture](docs/initializr.md).

## Why this template?

- **Native GUI:** DVUI immediate-mode widgets with the SDL3 backend; no browser or web runtime.
- **Real SDK integration:** CSV delimiter detection calls `zdata.scan.structural.Scanner` and `zdata.bits.positions`; ZData itself stays format-neutral.
- **Responsive data workflow:** virtualized grid, row numbers, search, filters, numeric sorts, column presentation and visible-column controls.
- **Themeable by design:** pure Zig tokens, Graphite / Light / Contrast, five accents and compact / comfortable density.
- **Reusable native branding:** typed `zevui.zon` configuration injected via Zig build options, editable SVG icons, bundled PNG and Windows icon. No React-style runtime is involved.
- **Reproducible developer workflow:** `just` recipes, headless correctness tests, an end-to-end benchmark, platform checks and compile-only cross-target steps.

### The first example: CSV Explorer

The interface is deliberately a **lightweight data explorer**, not an Excel clone. It does not have formulas, spreadsheet editing or a ribbon. You can open a CSV/TSV, inspect it in a row-numbered grid, search across columns or one column, filter and sort, and customize the presentation without changing the source file.

The initial no-data view exposes two working actions: **Open file** (native picker where supported) and **Enter path** (works with the `portable-gui` build).

**Screenshot:** add a real capture after running the M0.3 interface; the project does not ship a fabricated mockup. For recommended capture states, see [`docs/ui-guidelines.md`](docs/ui-guidelines.md).

## Quick start

Requirements: Zig **0.17.1**, `just`, and Python 3 for repository checks. On Arch Linux: `sudo pacman -S just`.

```sh
cd zdata-dvui-examples
just setup       # one-time: pin public ZData in build.zig.zon
just doctor      # inspect Zig, just and package wiring
just check       # Python checks + Zig ReleaseSafe tests
just run         # DVUI/SDL3 desktop application
```

The example fixture lives at `testdata/sample_1500.csv`. Import it through **+ Abrir CSV**, or choose **Abrir ruta** and enter its relative path when launching from the repository root.

`just setup` modifies the package manifest. Commit the resulting **`build.zig.zon`** so the SDK URL and content hash stay pinned. The ZIP initially leaves the public ZData dependency unpinned intentionally; DVUI is preconfigured.

Without `just`:

```sh
zig fetch --save=zdata git+https://github.com/jhovadev/zigdataengine.git
zig build test -Doptimize=ReleaseSafe
zig build sdl3-app -Doptimize=ReleaseFast
```

### Compact toolbar & icon assets

The full-width search row is gone. Use **Buscar** to show a compact search input
with column scope, and **Apariencia** for theme, accent and row density. Closing
search keeps the query active; use **Limpiar** to remove it. **Compacta** is the
initial density, not a search button. The columns panel uses unique per-row
DVUI widget IDs for reliable focus and event handling.

The app is branded from `zevui.zon`; `src/app/identity.zig` now reads generated `zevui_config` build options. SVG source assets are in
`src/ui/assets/` and `assets/branding/`. DVUI converts the toolbar SVGs to
TinyVG at startup; it reads the bundled PNG for the window icon. The Windows
resource embeds a multi-size `.ico` into the executable.

See [branding and design-system notes](docs/design-system.md).

### Useful recipes

| Recipe | What it does |
| --- | --- |
| `just check` | Headless Zig ReleaseSafe tests + Python infrastructure tests |
| `just run` / `just run-portable` | Run desktop UI with full / reduced native dependencies |
| `just build` / `just build-portable` | Build without running |
| `just bench` | Benchmark the bundled 1,500-row fixture |
| `just minimal` / `just run-minimal` | Build / launch the independent DVUI-only example |
| `just fmt` | Format Zig code (modifies files) |
| `just targets` | Show six configured desktop targets |
| `just cross-headless x86_64-windows-gnu` | Compile foreign-target tests, don't execute |
| `just windows-x64` | Attempt Windows GNU GUI build from the current host |
| `just windows-gui-check` | Inspect compiled `.exe` for GUI (not console) subsystem |
| `just windows-console-debug` | Explicit console-enabled Windows debug build |
| `just sdk-doctor aarch64-macos` | Explain missing/required Apple platform SDKs |

To test a larger personal CSV, run `zig build bench -Doptimize=ReleaseFast -- /path/to/file.csv`; **do not commit datasets containing private information**.

## How the example uses ZData

```text
Zevui (DVUI + SDL3)
  src/main.zig           window, interactions, table & panels
  src/ui/                design tokens, state handles, DVUI adapter
             |
  src/csv.zig            CSV/TSV-specific parser
  src/search.zig         incremental filtering and sorting
             |
  @import("zdata")      generic byte/bit/scan primitives
```

The CSV adapter uses ZData for structural separator detection outside quoted fields. It still handles quoting, field decoding and row construction itself. **The application is not a streaming CSV parser:** file input is loaded into memory with a current 128 MiB limit. Large-file benchmark timings and SDL renderer behavior depend on the machine.

This separation is intentional: contributors can replace the CSV adapter with logs, TSV, custom binary readers or other data sources without coupling ZData to DVUI.

## Cross-platform support

| Target | Build route | Status |
| --- | --- | --- |
| Linux x86-64 | `just run` / `just linux-x64` | Native GUI exercised; cross artifact experimental |
| Linux ARM64 | `just linux-arm64` | Compile target configured, not runtime verified |
| Windows x86-64 / ARM64 | `just windows-x64` / `just windows-arm64` | Cross-build experimental; verify in Windows |
| macOS Intel / Apple Silicon | `just macos-x64` / `just macos-arm64` | Requires macOS host/runner with Apple SDK |

The portable profile disables **optional** native dialogs, FreeType and Tree-sitter. It does not eliminate SDL3/OS graphics requirements or guarantee self-contained distribution. Building an executable is **not** the same as testing interaction, packaging, accessibility or signing on its target OS. See [cross compilation](docs/cross-compilation.md) and [SDK requirements](docs/platform-sdks.md).

## Theme and UI architecture

The design system consists of pure [`src/ui/tokens.zig`](src/ui/tokens.zig) values, explicit state holders in [`src/ui/hooks.zig`](src/ui/hooks.zig), a DVUI color adapter, and semantic components. Themes and accents are independent of the data pipeline. Appearance is currently stored only for the running session.

For spacing, grid affordances and interaction conventions, see [UI guidelines](docs/ui-guidelines.md) and [design system](docs/design-system.md).

## Project map

```text
zevui.zon         Application identity, dimensions and compile-time options
zevui/*.zig        Reusable Zevui build helper and typed config
examples/minimal/  Second DVUI app with no ZData import
examples/csv/      CSV-only headless test and benchmark steps
src/main.zig       CSV Explorer app and DVUI view
src/csv.zig        Parser and ZData structural scan integration
src/search.zig     Incremental operations
src/ui/            Tokens / theme adapter / small components
src/bench.zig      CSV benchmark
justfile           Development and cross-build recipes
scripts/           Dependency and SDK preflight checks
tests/             Headless infrastructure checks
testdata/          Synthetic non-sensitive CSV fixture
docs/              Architecture, design, cross-platform, troubleshooting
```

## Build core — two independent applications

M0.5 moves identity, window defaults and appearance defaults to the typed
[`zevui.zon`](zevui.zon). `build.zig` invokes the reusable
[`zevui.addApp()`](zevui/build.zig) for CSV Explorer **and**
[`examples/minimal`](examples/minimal), which does not import ZData.
Typed Windows/macOS overrides are in `zevui.windows.zon` / `zevui.macos.zon`.
A theme preference changed while the app runs is runtime state, **not** a build
configuration change. The new helper is intentionally a *local build module*
for M0.5; it is not yet a separately published Zevui package or CLI.

```sh
just check     # headless tests; no display needed
just minimal   # compile second GUI example (does not import ZData)
just run-minimal # launch independent DVUI-only application
just run       # CSV Explorer
```

See [build core and configuration](docs/build-core.md) for the complete
contract, customization procedure and documented restrictions.

## Contribute and verify

```sh
just check
zig build test
zig build test -Doptimize=ReleaseSafe
python3 -m unittest discover -s tests -v
```

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for conventions. Please provide platform, Zig version and reproduction instructions with GUI issues; attach genuine screenshots and distinguish build success from target runtime verification.

## Credits and license

- [DVUI](https://github.com/david-vanderson/dvui) and [dvui-demo](https://github.com/david-vanderson/dvui-demo): David Vanderson, MIT; this template follows the SDL3 App pattern but does **not** vendor the full demo repository.
- [Zig Data Engine](https://github.com/jhovadev/zigdataengine): independent data-processing SDK, MIT.
- Zevui example and design-system layer: provided under [`LICENSE`](LICENSE), MIT.

**Zevui is an independent community example; it is not an official DVUI project.**

## Rebrand Zevui for your own app

Change the title, organization, application identifier, version and dimensions
in `src/app/identity.zig`. Replace `assets/branding/zevui.svg`, regenerate
`src/app/assets/zevui.png` (window icon) and `assets/branding/zevui.ico` (Windows Explorer icon), and edit
`src/ui/assets/*.svg` for toolbar icons. If you rename the executable, update
the `windows-gui-check` recipe too.

Windows GUI builds hide the extra console by selecting the PE **Windows GUI**
subsystem in `build.zig`; debug builds can opt back into the console with
`-Dwindows-console=true`. Normal GUI builds still log errors, but no console
will appear automatically; add file logging before a production release.

The `identity.version` constant is available to your UI; packaging metadata
(such as macOS Info.plist or complete Windows VERSIONINFO) should be added as
a separate release configuration.
