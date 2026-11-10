# Z0 — Zevui as a modular native Zig toolkit

**Working components:** a typed Zig `zevui.addApp()` build helper (local to the template), a reviewed addon registry, a framework-independent TypeScript planner, optional Zig addon source modules, SolidStart Initializr UI, and (since F2) a deterministic TypeScript ZIP executor.

**Architecture**

```text
registry/catalog.json (schema v2 + pinned DVUI package)
                 |
packages/initializr-core/src/index.ts   pure planner: validation, transitive
                 |                    requirements, cycles/conflicts, compatibility,
                 |                    deterministic file operations
     +-----------+------------+
 SolidStart browser       POST /api/plan
 file tree preview        GET /api/metadata (ETag)
     |
 POST /api/generate -> TypeScript render + ZIP -> standalone Zig project
     |
 zig build (no Python or SolidStart in generated project)
```

`/api/catalog` remains for compatibility; `/api/metadata` publishes the reviewed v2 registry with a content ETag. The browser computes the preview using the **same pure TS planner** used by `/api/plan` and the TS ZIP executor. The `fingerprintId` seed is generated once on the client, can be shared in the URL, and ensures byte-identical generated ZIPs for identical input. Without it, the Node CLI generates a new Zig package identity per invocation.

```sh
just initializr-setup
just registry-check
just ecosystem-check
just initializr-build
just initializr
```

Try these HTTP calls against `just initializr`:

```sh
curl -i http://127.0.0.1:8765/api/metadata
curl -sS -X POST http://127.0.0.1:8765/api/plan \
  -H 'Content-Type: application/json' \
  -d '{"name":"my-app","title":"My App","organization":"dev.example","version":"0.1.0","addons":["design_tokens"],"fingerprintId":305419896}'
```

**What is not yet solved:** `zevui/build.zig` is copied into generated projects, not distributed as a published Zig SDK package. Addons currently include Zig source, not pinned separate Zig packages. F2 has consolidated production generation in TypeScript; Python is isolated as a test oracle. Packaging and standalone SDK extraction remain future milestones. Cross-target builds are not demonstrated solely by metadata. Native bundling, SQLite, tray and TOML/YAML are **not implemented by this Z0 release**.

The dev-server exit code 130 after Ctrl+C means the process was interrupted by the operator, not that the build failed. Successful `just initializr-build` and real UI checks are the relevant gates.
