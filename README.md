# Zevui

**An experimental native Zig SDK and desktop starter using [DVUI](https://github.com/david-vanderson/dvui), [SDL3](https://www.libsdl.org/), and [Zig Data Engine (ZData)](https://github.com/jhovadev/zigdataengine).**

Zevui is an **independent community SDK and example-driven template**, not a replacement for DVUI or a component of ZData. Its first application, **CSV Explorer**, is a small but usable data viewer: a compact grid, on-demand search, column tools, and a multi-theme design system.

> **Status:** F3 SDK extraction (after F2/Z0/F1) · **Zig 0.17.1** · native desktop UI · MIT. Linux x86-64 has been exercised by the project author; other cross-build targets need target-host validation. Names and APIs are subject to change.

## Zevui Initializr — generate your own Zig app

Zevui now includes a local, Spring Initializr-style project generator with an addon catalog. It produces self-contained Zig sources from selected features, with native DVUI/SDL3 and a typed `zevui.zon` configuration. **The generated app needs no Python or Zevui CLI to compile.**

```sh
# Node.js 24+ and Bun are used only by the Initializr website.
just initializr-setup
just initializr          # SolidStart + deterministic TypeScript ZIP executor
just initializr-check    # TS executor tests + frozen Python output oracle
just initializr-build    # SolidStart typecheck and production build

# CLI uses exactly the same TypeScript project renderer as the website.
just new my-application
cd my-application && zig build run
```

F2 introduces a **single production generator** in
[`packages/initializr-core/src/generator.ts`](packages/initializr-core/src/generator.ts).
It is framework-independent: the pure planner, renderer and deterministic ZIP
encoder have no Node, browser or filesystem imports. SolidStart reads reviewed
source files and returns a ZIP; the Node CLI writes the same generated files to
disk. Python moved to [`tests/legacy_oracle/`](tests/legacy_oracle/) for regression
comparisons only; it is not needed to run Initializr or to build generated apps.

```sh
just registry-check      # planner, registry, deterministic generator
just ecosystem-check     # TS + frozen oracle regression gates
```

The browser still provides project metadata, addon filtering, shared URLs and a
file-tree preview based on the very same plan used to generate the ZIP.
Supported addons are `memory_store` and `design_tokens`. SQLite, tray, bundle and
ZData are registered as non-ready. See [F2 migration details](docs/architecture/f2-generator.md)
and [Initializr documentation](docs/initializr.md).

**Monorepo migration:** [F0 audit](docs/architecture/current-state.md),
[F1 freeze](docs/architecture/f1-freeze.md),
[F2 acceptance](docs/architecture/f2-generator.md),
[target architecture](docs/architecture/target-architecture.md), and
[F1–F6 roadmap](docs/architecture/migration-roadmap.md). The five ADRs remain
proposed; F3 physically extracts `framework/` and `examples/csv-explorer/`, but SDK publication and pinned consumption remain pending F4/F5.

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
just f3-wire     # one-time: add local Zevui SDK without touching ZData pin
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

The app is branded from `zevui.zon`; `examples/csv-explorer/src/app/identity.zig` now reads generated `zevui_config` build options. SVG source assets are in
`framework/src/ui/assets/` and `assets/branding/`. DVUI converts the toolbar SVGs to
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
  framework/src/ui/     reusable design tokens, state handles and DVUI adapters
             |
  examples/csv-explorer/src/main.zig   window, interactions, grid and panels
  examples/csv-explorer/src/csv.zig    CSV/TSV-specific parser
  examples/csv-explorer/src/search.zig incremental filtering and sorting
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

The design system consists of pure [`framework/src/ui/tokens.zig`](framework/src/ui/tokens.zig) values, explicit state holders in [`framework/src/ui/hooks.zig`](framework/src/ui/hooks.zig), a DVUI color adapter, and semantic components. Themes and accents are independent of the data pipeline. Appearance is currently stored only for the running session.

For spacing, grid affordances and interaction conventions, see [UI guidelines](docs/ui-guidelines.md) and [design system](docs/design-system.md).

## Project map

```text
framework/                 Publishable Zig SDK package, build helper and UI kit
  build.zig(.zon)          Standalone SDK, no ZData/CSV dependency
  src/root.zig            Public @import("zevui") module
  src/ui/                 Tokens, state handles, DVUI adapters and SVG icons
  src/storage.zig         Storage capabilities (no backend implementation)
examples/csv-explorer/     CSV application, tests and benchmarks
examples/minimal/          Independent DVUI-only app, Zevui SDK consumer
addons/                    Addon prototypes (F4 package extraction pending)
registry/                  Official addon metadata
packages/initializr-core/  TypeScript planner, renderer, ZIP executor
apps/initializr/           SolidStart project generator website
templates/compat/          Frozen F2 project sources until F5
build.zig(.zon)            Workspace build; local framework path dependency
zevui.zon                  App configuration and platform overrides
```

See [F3 migration and acceptance gates](docs/architecture/f3-sdk-extraction.md)
and the [standalone SDK README](framework/README.md).

## Build core — two independent applications

M0.5 moves identity, window defaults and appearance defaults to the typed
[`zevui.zon`](zevui.zon). `build.zig` invokes the reusable
[`zevui.addApp()`](framework/build.zig) for CSV Explorer **and**
[`examples/minimal`](examples/minimal), which does not import ZData.
Typed Windows/macOS overrides are in `zevui.windows.zon` / `zevui.macos.zon`.
A theme preference changed while the app runs is runtime state, **not** a build
configuration change. The helper is now also a standalone Zig package in `framework/`; the workspace
consumes it via a **local `.path` dependency**. It is not yet a published
URL/hash package. Initializr's F2 compatibility template will switch to a
pinned SDK dependency in F5.

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
in `zevui.zon` (the source of truth), not in the generated identity shim. Replace `assets/branding/zevui.svg`, regenerate
`examples/csv-explorer/src/app/assets/zevui.png` (window icon) and `assets/branding/zevui.ico` (Windows Explorer icon), and edit
`framework/src/ui/assets/*.svg` for toolbar icons. If you rename the executable, update
the `windows-gui-check` recipe too.

Windows GUI builds hide the extra console by selecting the PE **Windows GUI**
subsystem in `build.zig`; debug builds can opt back into the console with
`-Dwindows-console=true`. Normal GUI builds still log errors, but no console
will appear automatically; add file logging before a production release.

The `identity.version` constant is available to your UI; packaging metadata
(such as macOS Info.plist or complete Windows VERSIONINFO) should be added as
a separate release configuration.

## Addon packages (F4)

`addons/memory-store/` and `addons/design-tokens/` are standalone Zig packages exposing `zevui_module`. The source of truth for available addons is `addons/*/addon.json`, with planned addons declared under `registry/planned/`. `registry/catalog.json` is generated for F2 compatibility; see [F4 registry](docs/architecture/f4-addon-registry.md).

Run `just registry-manifests-check` and `just addons-check` before publishing. **Standalone remote package hashes are not yet available**; the Initializr preserves its verified source-copy bridge until F5.

For F5 starter template authoring and acceptance, see [F5 templates](docs/architecture/f5-real-templates.md).
