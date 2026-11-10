# Zevui Initializr — SolidStart UI (M0.7)

**Goal:** Spring Initializr-like onboarding for a native Zig desktop app. This is not Spring Boot, Tauri, a browser runtime embedded in your app, or a remote hosted service.

## Run locally

The generator website uses **SolidStart 2.2.2 + SolidJS**, Node.js 24+ and
Bun. **Python is not part of the production generator**. The CLI uses Node.js
and TypeScript output; generated desktop projects require only Zig 0.17.1 and
the native SDK requirements of DVUI/SDL3.

```sh
just initializr-setup
just initializr
just registry-check
just ecosystem-check
just initializr-build
just new my-app
```

### Architecture (F2)

```text
registry/catalog.json                reviewed addon data + pinned DVUI URL/hash
packages/initializr-core/src/index.ts      pure planProject()
packages/initializr-core/src/generator.ts  pure TS render + ZIP (STORE)
                         |                        |
apps/initializr/ SolidStart website   packages/initializr-core/scripts/new.mjs
                         |                        |
          API /api/generate             local disk writer
                         \________________________/
                               zig build
```

- `/api/metadata` and `/api/catalog` return the registry; `/api/plan` returns
  the pure file plan; `/api/generate` returns a ZIP built from that same plan.
- `apps/initializr/src/lib/generator.server.ts` only reads reviewed local
  sources and passes them into the pure TS executor. It **does not** use
  `child_process` or Python. Existing routes retain JSON input size limits,
  same-origin protections and no-store ZIP responses.
- The ZIP encoder uses method 0 (STORE) intentionally: fixed file ordering,
  DOS date 2026-01-01, normalized permissions and LF content. ZIPs may be
  larger than the old Python-deflated archives, but are reproducible without
  a compression dependency.
- The previous Python generator and HTTP/CLI bridge live exclusively under
  `tests/legacy_oracle/` and are **never imported by production code**.
  Frozen SHA-256 goldens allow parity checks without invoking Python at runtime.
- **No remote deployment hardening is claimed.** A public server needs rate
  limits, appropriate security headers and resource monitoring. The server
  adapter uses filesystem access, so deploy to a Node-compatible host with
  the registry and reviewed sources available; not as static-only hosting.

Node.js and SolidStart are developer-tooling dependencies only, never runtime
requirements of the generated native application.

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

The registry is `registry/catalog.json` (schema v2). Its TypeScript planner and deterministic ZIP executor share a validated plan. Python survives only as a frozen test oracle. See [F2 architecture](architecture/f2-generator.md).
