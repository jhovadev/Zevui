# Zevui Initializr — SolidStart UI (M0.7)

**Goal:** Spring Initializr-like onboarding for a native Zig desktop app. This is not Spring Boot, Tauri, a browser runtime embedded in your app, or a remote hosted service.

## Run locally

The generator website is now **SolidStart 2.x + SolidJS** with a Node-compatible Nitro server. Requires **Node.js 24+** and **Bun**, alongside Python 3 (standard library only) for the actual ZIP generation; Zig 0.17.1 is needed only when building the downloaded desktop project.

```sh
just initializr            # first run installs JS dependencies; http://127.0.0.1:8765
just initializr-setup      # explicit install/update
just initializr-check      # Python generator and bridge tests
just initializr-build      # typecheck + production build
```

For a Python-only, zero-JS-toolchain workflow use `just initializr-legacy`. The CLI remains `python3 -m initializr.cli example-name`. Python's legacy HTTP server now suppresses its `KeyboardInterrupt` traceback; stopping `just` with Ctrl+C is a normal user interruption, and Just may still report signal 2.

### How the new frontend works

```text
apps/initializr/src/routes/index.tsx         SolidStart page: forms, catalog and project preview
apps/initializr/src/routes/api/catalog.ts    GET /api/catalog (reads canonical JSON)
apps/initializr/src/routes/api/generate.ts   POST /api/generate -> ZIP
apps/initializr/src/lib/bridge.server.ts     Node subprocess bridge, Python stdlib
initializr/bridge.py                        Stdin JSON -> stdout ZIP (16 KiB input bound)
initializr/generator.py                     Canonical validation and Zig source generation
initializr/catalog.json                    Catalog status and metadata single source
```

No second Python HTTP server needs to run. The Node API starts a fixed `python3 -m initializr.bridge` child process for each generation request; JSON input is validated by the canonical generator. The browser never receives or executes arbitrary shell commands. Generated ZIPs contain source only. Both API endpoints use same-origin requests and no cross-origin CORS permissions. Vite's development server binds to loopback. **Do not expose the Initializr API directly to the public internet** without adding authentication/rate limiting and deployment hardening. The backend uses a Node runtime with local Python and access to the repository; do not deploy it as a static site or on an edge runtime.

### Build/deployment limitations

This delivery cannot install JS packages in the artifact environment (package registry network unavailable), so SolidStart typechecking, server startup, and browser E2E are **pending validation on Node 24 / Bun**. `package.json` pins SolidStart 2.2.2 and Nitro 3.0.261103-rc (Nitro v3 is still prerelease), but no `bun.lock` has been generated here; after the first `just initializr-setup`, commit the lockfile for reproducibility. To run a built Nitro server, retain the Python `initializr/` package and `zevui/`, Zig example/template sources, and `build.zig.zon`; set `ZEVUI_REPO_ROOT` to their common directory. The working directory default assumes execution from `apps/initializr`.

## Generated project

```text
my-application/
  build.zig            Zevui addApp; nothing requires a globally installed CLI
  build.zig.zon        DVUI URL + content hash; project fingerprint
  zevui.zon            typed identity, window, appearance
  zevui/               local copy of current build core
  src/main.zig         minimal DVUI app
  src/addons/          only the chosen, available addons
  README.md
```

Run `zig build` or `zig build run`. The generated project has an embedded **copy** of M0.5 Build Core, *not* an external Zevui package. Updating Zevui across generated projects is not automatic. Addon files are Zig source copied into the project (compile-time composition), not dynamically loaded plugins.

## Addon lifecycle

The catalog distinguishes `available`, `manual`, `planned`. Only `available` entries can be generated. M0.6 includes **Memory Store** (bounded, volatile key/value, no allocators) and **Design Tokens** (pure-Zig palette, mode and density). Source code and Zig tests are included. The generator does not silently enable storage, tray, SQLite, bundlers or ZData, nor does it download unpinned packages. These can be implemented later with separate contracts and compatibility tests.

The generated `src/main.zig` imports selected addons at comptime and shows how to use them. Addons are not automatically persistent nor coupled to the DVUI lifecycle. This is a bootstrap, not a finished runtime plugin manager.

### Why ZData isn't selectable yet

A general-purpose starter does not require ZData. The existing CSV Explorer demonstrates an explicit `zig fetch --save=zdata ...` workflow, with a URL and package hash pinned by Zig. Generated minimal apps remain independent of ZData. An eventual ZData addon will be supported once generator dependency injection and exact lock/pin behavior have an integration test with Zig 0.17.1.

## Security and portability

No arbitrary remote file fetch, command execution or user-defined paths occur inside the server. This local server is not designed to be exposed publicly; for a hosted Initializr add CSRF protection, rate limiting, resource limits, request logging policies, security headers, and sandboxed generation. A generated ZIP contains *source*, not precompiled installers.

The DVUI SDL3 package dependency is inherited from the M0.5 manifest and cross-compilation remains experimental; Apple SDK and platform graphics APIs still apply. The status of web generation does **not** imply the desktop binaries are tested on Windows/macOS.


## Z0 registry and pure planner

The registry is now `registry/catalog.json` (schema v2). A pure TypeScript planner in `packages/initializr-core` computes the safe, deterministic file plan consumed by the SolidStart preview. The Python ZIP generator continues as the final validated executor while test-driven parity is established. See [Z0 ecosystem architecture](ecosystem-z0.md).
