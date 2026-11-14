# Zevui Components (F9 / source-owned UI)

Native component sources, independent of Initializr's additive project plan and
of the addon registry. The web catalog lives at **`/components`** in the same
SolidStart deployment as Initializr; this avoids a second Nitro server/build.

## Contract

- The **native UI runtime** is Zig 0.17.1 + DVUI. No React, SolidJS, DOM or web
  runtime goes into the desktop app. `framework/src/ui/heatmap.zig` and
  `progress.zig` render native widgets. `heatmap_model.zig` is pure Zig.
- The **web gallery** offers an explicitly labeled **HTML approximation**, not
  a DVUI WebAssembly render. A true WebAssembly preview is a later experiment.
- The **registry** is distinct from Initializr addons. Files in
  `registry/components/*.json` name exact reviewed `framework/src/ui/` Zig
  sources and exact `src/components/` targets. No arbitrary download URLs or
  scripts are executed by the installer.
- An install copies **source**, not a dynamic dependency, and saves its SHA-256
  into `.zevui/components.lock.json`. Existing untracked/modified files are
  never overwritten. `update` only replaces an unmodified, locked copy.
- The catalog snapshot at `apps/initializr/src/lib/components.generated.json`
  is generated from these real sources; `verify` checks exact byte equality.
- The installer preflights all files before the first write. Each individual
  file and the lock are written by atomic replace. Sudden disk/OS failure can
  still leave a partially installed multi-file component; re-running `add`
  recovers it if the files match. **This is not a filesystem transaction**.

## Local development

```sh
just components-check
just initializr            # browse http://127.0.0.1:8765/components
just components             # alias for same host, same route
just component-add heatmap /tmp/my-zevui-app
just component-status heatmap /tmp/my-zevui-app
just component-update heatmap /tmp/my-zevui-app
```

Regenerate after editing manifests or native code:

```sh
python3 tools/components.py catalog --write
python3 tools/components.py verify
```

## Native consumption

With the `zevui` SDK imported through the build system:

```zig
const zevui = @import("zevui");
zevui.ui.heatmap.draw(@src(), activity[0..], .{ .cell_size = 12 });
```

With a source-owned copy (`component-add heatmap`), from `src/main.zig`:

```zig
const heatmap = @import("components/heatmap.zig");
heatmap.draw(@src(), activity[0..], .{ .cell_size = 12 });
```

`activity` is a slice of u32 counts with a **nonzero length divisible by 7**.
Index 0 is Monday of the first week, subsequent columns each contain seven
consecutive weekdays. The date range, missing days and locale/calendar labels
are the **caller**'s responsibility. Start with 16 weeks for narrow windows;
52 weeks usually require a horizontal scroller. Values should be computed
outside the immediate-mode `frame()` and loaded from SQLite in the data layer.

## Why this differs from shadcn and Native SDK

Zevui is deliberately **not a competing renderer, state runtime or native SDK**.
Its distinctive scope is a DVUI-first, source-owned, verified registry with
an opt-in generator, and preserving user-edited Zig source across upgrades.
Design-system density, palette and semantic variants reuse existing Zevui
`tokens` and `components` instead of a parallel styling system.

## Validation status

- Python tests exercise catalog integrity, conflict refusals, symlink defense,
  and generated lock behavior.
- `just components-check` does not compile Zig.
- Run `just framework-check` or `zig build test -Doptimize=ReleaseSafe` with
  the pinned Zig 0.17.1 compiler and installed DVUI packages on the target host.
- Manual Linux/Windows/macOS window and keyboard checks remain necessary;
  the HTML preview is not evidence of DVUI pixels or native accessibility.

### SSR hydration (F8.1)

The gallery keeps the public header and introduction in the server-rendered HTML,
then mounts the interactive catalog after Solid has finished hydrating that shell.
This ensures the dynamic preview grid does not allocate a different set of
hydration IDs between SSR and the browser. The loading message is identical
on the server and during the initial client hydration pass.

Use `just initializr-build` and `just components` and verify the browser has
no hydration mismatch. Native heatmap model compilation is verified by
`just framework-check` on Zig 0.17.1.


## F9 — Zig CLI and shadcn-shaped registry

The component CLI is written in **Zig 0.17.1** in
`packages/zevui-cli/src/main.zig`. Node/Bun/npm do **not** implement installation;
the optional npm `bin/zevui.mjs` shim launches a prebuilt Zig executable if
one is provided, or invokes `zig run` with Zig 0.17.1 present in `PATH`.
**The npm package is prepared locally, not published to npm.**

The public `packages/zevui-cli/registry.json` follows shadcn's *index-shaped*
JSON schema (`name`, `type`, `files`, `target`, `registryDependencies`), but the
existing shadcn CLI is not the installer for Zig files. A second bundled,
version-pinned `registry-bundle.json` includes each reviewed Zig source and its
SHA-256. The native CLI embeds it at compile time, so installing is offline and
no arbitrary registry URL is executed.

```sh
# Run from the Zevui monorepo after F9 has been applied:
zig run packages/zevui-cli/src/main.zig -O ReleaseSafe -- list
zig run packages/zevui-cli/src/main.zig -O ReleaseSafe -- init --project /tmp/my-app
zig run packages/zevui-cli/src/main.zig -O ReleaseSafe -- add calendar input checkbox --project /tmp/my-app --dry-run
zig run packages/zevui-cli/src/main.zig -O ReleaseSafe -- add calendar input checkbox --project /tmp/my-app
zig run packages/zevui-cli/src/main.zig -O ReleaseSafe -- doctor --project /tmp/my-app
zig run packages/zevui-cli/src/main.zig -O ReleaseSafe -- update calendar --project /tmp/my-app --dry-run
```

Alternatively, compile a standalone CLI in `packages/zevui-cli/` with
`zig build -Doptimize=ReleaseSafe`; that CLI has no Node runtime dependency.
`init` creates `zevui.components.json` in an existing Zig project. Installed
sources are placed in `src/components` and tracked in
`.zevui/components.lock.json` (schema 1, compatible with F8).

Initial installation preflights requested files, rejects existing uncontrolled
collisions, non-directories and symlinked targets, then writes each file
atomically. It does not roll back earlier files on later I/O failures, and
filesystem changes by concurrent processes are not part of a race-proof
transaction. Use `--dry-run` and a Git clean checkpoint for migrations.

The F8 Python installer remains available for older workflows, but the new
recommended CLI is Zig. Agents can read `skills/zevui-components/SKILL.md` or
`.agents/skills/zevui-components/SKILL.md` to follow the same contracts.

### F9 components

- `calendar`: Gregorian month view and date selection with persistent caller state.
- `input`: native text/password entry, caller-owned NUL-terminated buffer.
- `checkbox`: native boolean field plus description.
- `separator`: simple native visual separator.

Combined with F8: `action`, `heatmap`, `progress` and `tokens` — eight entries.

### Required validation on a Zig 0.17.1 machine

```sh
just components-check
just framework-check
just components-cli-check
just initializr-build
just components # inspect /components in browser (no SSR hydration errors)
```

The gallery's previews are HTML approximations rather than tested DVUI/WASM
pixels. `npm pack --dry-run` checks local package composition; do not claim the
package is on npm until it has been published and verified independently.
