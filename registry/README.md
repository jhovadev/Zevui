# Zevui addon registry — Z0

The registry is an **official, curated catalog** initially. Its only selectable Zig addons are `memory_store` and `design_tokens`; both contain actual source files in `addons/`. SQLite, tray, bundling and the ZData integration are *not* currently selectable. Do not flip `status` until their corresponding packages build and the generator actually supports them.

`registry/catalog.json` is authoritative for metadata, package pins, file mappings and compatibility. `registry/schema.json` describes the serialized shape. `packages/initializr-core` validates the data and plans project operations before any file is written. The Python executor still owns generating the ZIP for this release; the registry itself does not execute post-install scripts or arbitrary code.

## Addon author workflow

1. Develop and test the addon as a separate Zig module, including at least Zig 0.17.1 native tests.
2. Declare `id`, `requires`, `conflicts`, `targets`, Zig compatibility, license, trust and *safe* relative source/destination paths.
3. Only use `status: available` when the generator is capable of including the addon, with its dependencies pinned by a verified `zig fetch` content hash if it imports external code.
4. Run `just ecosystem-check` and `just check`. On CI, generate an empty starter and a starter with all available addons, then compile on Zig 0.17.1.
5. Require a source review for any C build integration, bindgen/translate-c, or build script. A hash prevents undetected changes; it is not a security audit.

A third-party/community addon submission process, a truly independently published `@import("zevui")` package and separately pinned Zig addon packages are not yet shipped. F2 uses a single TS ZIP executor; legacy Python is retained as a test oracle.
