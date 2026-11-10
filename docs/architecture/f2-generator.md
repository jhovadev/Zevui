# F2 — Single TypeScript Generator (acceptance and rollback)

**State:** implementation supplied as an incremental F2 patch on top of F1.
The Zig SDK extraction is **not** included. F1 public `zevui.zon` keys and
Windows GUI subsystem configuration remain unchanged.

## Dependency boundary

```
registry/catalog.json (reviewed data)
          |
initializr-core/index.ts      <- pure planner, input and path checks
          |
initializr-core/generator.ts  <- pure render + ZIP, no Node/browser/fs
          |
          +-- SolidStart server adapter (read-only reviewed source files)
          +-- Node CLI disk adapter (write generated project atomically)
          |
      generated Zig project -> zig build
```

Python is **not a runtime**. `tests/legacy_oracle/` is a frozen reference from
pre-F2. It is deliberately retained until the golden tests are stable. The
legacy HTML/HTTP/CLI are also frozen there, not shipped or invoked by `just`.
The website and CLI reuse `generateProject()`, not parallel renderers.

## Changed paths

| Old | New / purpose |
| --- | --- |
| `apps/initializr/src/lib/bridge.server.ts` | `apps/initializr/src/lib/generator.server.ts` (no subprocess) |
| `initializr/generator.py` | `tests/legacy_oracle/generator.py` (reference only) |
| `initializr/bridge.py`, `cli.py`, `server.py`, web static files | `tests/legacy_oracle/` (archived) |
| none | `packages/initializr-core/src/generator.ts` (render and ZIP) |
| none | `packages/initializr-core/scripts/new.mjs` (disk client) |
| none | `tests/fixtures/initializr-f2-golden.json` (frozen source hashes) |

## Determinism and safety

- The planner validates name/org/version, Zig channel, target, available addons,
  requirements, conflicts and safe unique destination paths.
- A caller must supply a valid `fingerprintId` for deterministic output.
  Server/CLI assign one random ID only when absent; sharing a project includes
  the ID, making regeneration reproducible.
- `generateProject()` renders exactly the planner's operations and consumes
  reviewed source bytes supplied by an adapter, never arbitrary URL or path.
- The ZIP encoder uses STORE (no compression), sorted entries, fixed date
  2026-01-01 00:00:00, unix mode 100644, UTF-8 flag, normalized LF text and
  no extra fields. It checks file count, size and ZIP-safe paths.
- Golden tests compare SHA-256 for every file in three legacy configurations;
  Python's *ZIP bytes* differ due to its DEFLATE method. The TS ZIP is checked
  for byte reproducibility separately.
- The server enforces 16 KiB input size and same-origin requests; its adapter
  resolves and confines source paths to the checked-out repository. These are
  not substitutes for production rate limiting or hosting hardening.

## Acceptance gates

```sh
just check
just registry-check
just ecosystem-check
just initializr-build
just new f2-minimal
node packages/initializr-core/scripts/new.mjs f2-addons \
  --addon memory_store --addon design_tokens
(cd f2-minimal && zig build test -Doptimize=ReleaseSafe && zig build)
(cd f2-addons && zig build test -Doptimize=ReleaseSafe && zig build)
```

The last two projects must compile on the developer's Zig 0.17.1. The F2 patch
can be validated without running a GUI. In this artifact environment the TS
core, Node tests, frozen Python oracle and ZIP parser ran; Zig, Just and the
SolidStart full build were unavailable. Do **not** infer those gates passed.

## Risks, mitigation and rollback

- **ZIP size:** STORE files are larger than Python DEFLATE. Mitigate later by
  a pinned, platform-independent compression library *only after* golden tests.
- **Node server read dependency:** current bundles still need the reviewed
  repository resources; F5 moves them to real templates/public package assets.
- **Old Python tooling:** retained for golden tests only, not user runtime.
- **Rollback:** `git revert <F2-commit>` restores the Python bridge and CLI;
  do not delete F1 or reset the Z0 baseline. If API errors occur, revert F2
  as a unit rather than using both generators in production.

## Deferred to F3–F6

Independent `framework/` Zig package, addon manifests/pins, template extraction,
SQLite translated-C integration, platform native bundles and system tray.
