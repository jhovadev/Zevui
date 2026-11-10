# ZData CSV Reader — DVUI/SDL3 application recipes.
# Requirements: just, Zig 0.17.1, Python 3 (for repository checks).
# Run `just --list` to see supported commands.
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set positional-arguments := true

# Display all recipes.
@default:
    just --list

# Check tooling, manifest state and the SDK integration (no downloads).
@doctor:
    @echo 'Zig:'
    zig version
    @echo 'Just:'
    just --version
    python3 scripts/check_layout.py

# First-time setup: pin the ZData SDK in build.zig.zon; commit the resulting manifest.
@setup:
    zig fetch --save=zdata git+https://github.com/jhovadev/zigdataengine.git
    python3 scripts/check_layout.py

# Run all parser/search unit tests locally in Debug mode.
@test:
    zig build test

# Run unit tests locally with ReleaseSafe checks.
@test-safe:
    zig build test -Doptimize=ReleaseSafe

# Compile the headless tests without running them (safe for foreign targets).
@test-compile:
    zig build test-compile -Doptimize=ReleaseSafe

# Validate integration and run headless tests; no GUI/display required.
@check:
    python3 tools/build_registry.py --check
    python3 scripts/check_layout.py
    python3 -m unittest discover -s tests -v
    zig build test -Doptimize=ReleaseSafe

# Format Zig sources. Changes files, so review git diff afterward.
@fmt:
    zig fmt build.zig framework examples

# Compile the native SDL3 app into zig-out/bin.
@build:
    zig build -Doptimize=ReleaseFast

# Run the native DVUI/SDL3 app (requires a graphical session).
@run:
    zig build sdl3-app -Doptimize=ReleaseFast

# Build a native executable with optional font, dialog, parser dependencies off.
@build-portable:
    zig build -Doptimize=ReleaseFast -Dportable-gui=true

# Run the reduced-dependency GUI; open files with the Route/Ruta control.
@run-portable:
    zig build run -Doptimize=ReleaseFast -Dportable-gui=true

# Benchmark on the bundled non-sensitive CSV fixture (replace with your own file as needed).
@bench:
    zig build bench -Doptimize=ReleaseFast -- testdata/sample_1500.csv

# List explicitly supported cross-compilation triples.
@targets:
    python3 scripts/targets.py --list

# Explain required SDKs, what is available locally and what remains unverified.
@sdk-doctor target:
    python3 scripts/sdk_doctor.py --target "$1"

# Compile headless Zig tests for a foreign target. Does NOT execute them.
@cross-headless target:
    python3 scripts/targets.py "$1"
    zig build test-compile -Dtarget="$1" -Doptimize=ReleaseSafe

# Build the DVUI/SDL3 executable for a foreign target; outputs in dist/<target>/bin.
# GUI backend transitive dependencies / platform SDKs may block some targets.
@cross target:
    python3 scripts/targets.py "$1"
    python3 scripts/sdk_doctor.py --target "$1" --require-build
    zig build -Dtarget="$1" -Doptimize=ReleaseFast -Dportable-gui=true --prefix "dist/$1"

# Platform shortcuts (each compiles, never runs a foreign binary).
@linux-x64:
    just cross x86_64-linux-gnu

@linux-arm64:
    just cross aarch64-linux-gnu

@windows-x64:
    just cross x86_64-windows-gnu

@windows-arm64:
    just cross aarch64-windows-gnu

@macos-x64:
    just cross x86_64-macos

@macos-arm64:
    just cross aarch64-macos

# Validate Windows PE subsystem after `just windows-x64` succeeds.
@windows-gui-check:
    python3 scripts/verify_windows_gui.py dist/x86_64-windows-gnu/bin/zevui-csv-explorer.exe

# Compile a Windows GUI with an attached console for crash/SDL debugging.
@windows-console-debug:
    python3 scripts/sdk_doctor.py --target x86_64-windows-gnu --require-build
    zig build -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseSafe -Dportable-gui=true -Dwindows-console=true --prefix "dist/windows-console-debug"

# Build the second DVUI app (no ZData), using the same Zevui addApp helper.
@minimal:
    zig build minimal -Doptimize=ReleaseSafe

# Run the independent DVUI-only example (requires a graphical desktop).
@run-minimal:
    zig build minimal-run -Doptimize=ReleaseFast

# Wire the local SDK without rewriting any previously pinned ZData/DVUI hashes.
@f3-wire:
    python3 tools/f3_wire_manifest.py

# Test the standalone Zevui SDK package independently of CSV/ZData.
@framework-check:
    cd framework && zig build test -Doptimize=ReleaseSafe

# Install Initializr frontend dependencies (Node 24+, Bun).
@initializr-setup:
    cd apps/initializr && bun install

# SolidStart Initializr on http://127.0.0.1:8765; first run installs dependencies.
@initializr:
    @if [ ! -d apps/initializr/node_modules ]; then \
      echo 'Installing Initializr dependencies (first run)...'; \
      (cd apps/initializr && bun install); \
    fi
    cd apps/initializr && bun run dev

# Diagnostic only: render the Initializr on the client to isolate SSR hydration errors.
@initializr-csr:
    cd apps/initializr && ZEVUI_INITIALIZR_CSR=1 bun run dev

# Build the SolidStart frontend/API for a Node-compatible runtime.
@initializr-build:
    cd apps/initializr && bun run typecheck && bun run build

# Generate a Zig project using the same TypeScript engine as the web route.
# Exported recipe parameter prevents shell interpolation and command injection.
@new $name:
    apps/initializr/node_modules/.bin/tsc -p packages/initializr-core/tsconfig.json
    node packages/initializr-core/scripts/new.mjs "$name"

# Production TS generator tests plus frozen Python output-oracle tests.
@initializr-check:
    apps/initializr/node_modules/.bin/tsc -p packages/initializr-core/tsconfig.json
    node --test packages/initializr-core/tests/generator.test.mjs
    python3 -m unittest discover -s tests -p 'test_initializr*.py' -v

# Verify registry schema, pure planner and its deterministic Zig project plan.
@registry-check:
    python3 tools/build_registry.py --check
    @if [ ! -x apps/initializr/node_modules/.bin/tsc ]; then echo 'Run just initializr-setup first (TypeScript toolchain missing)' >&2; exit 1; fi
    apps/initializr/node_modules/.bin/tsc -p packages/initializr-core/tsconfig.json
    node --test packages/initializr-core/tests/*.test.mjs
    python3 -m unittest discover -s tests -p 'test_registry*.py' -v

# Run registry, deterministic ZIP, CLI and historical oracle tests.
@ecosystem-check:
    just registry-check
    just initializr-check

# F4 registry: validate independent addon manifests, generated metadata and lockstep catalog.
@registry-build:
    python3 tools/build_registry.py --write

@registry-manifests-check:
    python3 tools/build_registry.py --check

# Zig pure addons compile and test as separate packages; no DVUI/SDL/ZData imports.
@addons-check:
    cd addons/memory-store && zig build test -Doptimize=ReleaseSafe
    cd addons/design-tokens && zig build test -Doptimize=ReleaseSafe

# Verify published addon pin on demand (requires network); never fabricate hashes.
@pin-addon id url:
    python3 tools/pin_addon.py "$1" --url "$2" --write

# F6A experimental package: opt-in, independent from framework and F5 initializr.
# `bundled` requires a separate, verified one-time vendor bootstrap.
@sqlite-addon-check:
    cd addons/storage-sqlite && zig build test -Dsqlite=off -Doptimize=ReleaseSafe
    cd addons/storage-sqlite && zig build test -Dsqlite=system -Doptimize=ReleaseSafe

@sqlite-vendor:
    python3 addons/storage-sqlite/tools/vendor_sqlite.py

@sqlite-bundled-check:
    python3 addons/storage-sqlite/tools/vendor_sqlite.py --check
    cd addons/storage-sqlite && zig build test -Dsqlite=bundled -Doptimize=ReleaseSafe
