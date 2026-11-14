---
name: zevui-components
description: Install, update, audit, and compose editable Zig 0.17.1 + DVUI components from the Zevui source-owned registry while preserving user modifications.
---

# Zevui Components — Agent Skill

Use when a user asks to add, customize, preview, upgrade, or debug Zevui/DVUI widgets, the component gallery, or a generated Zevui application. The source of truth is the **actual Zig source** and the Zevui component registry, not the illustrative HTML gallery.

## Environment and discovery

1. Verify the project uses Zig **0.17.1** (`zig version`), has `build.zig`, and imports `dvui` (normally provided by Zevui's build helper).
2. Inspect `zevui.components.json` and `.zevui/components.lock.json` if they exist. Preserve local changes, aliases, and current branch state.
3. Read the component manifest from `registry/components/*.json` in this monorepo or list the bundled native CLI registry using `zevui list`.
4. Read every selected component's Zig source and `usage` before editing the application's `frame()` function. DVUI is immediate mode: state must persist between frames; use the caller's `@src()` to preserve unique widget IDs.

## Native CLI (not a JavaScript implementation)

Use the compiled Zig executable when available:

```sh
zig build -C packages/zevui-cli
packages/zevui-cli/zig-out/bin/zevui --help
```

From an npm installation (after publishing), `npx @zevui/cli init` or `bunx @zevui/cli add calendar input` uses a small JS **launcher only**, which executes Zig. Zig 0.17.1 must be on `PATH` unless the package contains a compatible native binary. Do not claim npm distribution is published without verifying the actual registry.

```sh
zevui init --project ./my-app
zevui list
zevui add heatmap calendar input checkbox --project ./my-app --dry-run
zevui add heatmap calendar input checkbox --project ./my-app
zevui doctor --project ./my-app
zevui update calendar --project ./my-app --dry-run
```

**Prerequisite:** `zevui init` configures an *existing* Zig project with `build.zig`; it does not scaffold one. Use Zevui Initializr to generate a new project, or `just components-cli-smoke` to validate installs in an isolated minimal Zig project. Do not initialize an empty directory.

Never use `--force` or silently overwrite modified user Zig files. If `doctor` or `add` reports local changes, inspect `git diff` and explain the conflict; make a separate explicitly reviewed patch.

## Component contract

- Components live in `framework/src/ui/` and are installed as `src/components/*.zig` with all relative imports preserved.
- Canonical manifests: `registry/components/*.json` (`schema: 1`, Zig `0.17.1`, explicit `source`/`target`). The frontend's `components.generated.json` and packaged `packages/zevui-cli/registry.json` and `registry-bundle.json` are generated snapshots, never manually edited.
- A manifest must have a stable kebab-case `id`, name, category, description, `status`, Zig compatibility, renderer and `usage`.
- `Calendar` and `Heatmap` separate pure date/activity models from DVUI; add `zig test` coverage to models before changing rendering.
- Prefer semantic design tokens and composable primitives, not hard-coded per-component global themes. Respect contrast, keyboard behavior, disabled controls, narrow windows, and localization.
- No required SQLite, ZData, Node, npm, browser, online registry or platform UI backend in installed component code. Any persisted data adapter is optional.

## When adding a component

1. Create Zig component and (if useful) a pure Zig model with tests in `framework/src/ui/`.
2. Add a validated `registry/components/<id>.json`, and wire the component in `framework/src/root.zig` only when appropriate.
3. Run `python3 tools/components.py catalog --write` and `node packages/zevui-cli/scripts/build-registry.mjs` to synchronize snapshots (these scripts are *maintainer build tools*, not the CLI runtime).
4. Add a preview to `apps/initializr/src/routes/components/index.tsx`, clearly marked as an HTML approximation until DVUI/WASM is verified. Keep SSR/hydration deterministic.
5. Test `just components-check`, `just framework-check`, `just initializr-build`, `zig build -C packages/zevui-cli test`, plus dry-run/add/doctor and the locally installed result.
6. Provide a diff or patch with validations, limitations and an exact compatibility statement. Do not claim a native Zig build passed if the compiler was unavailable.

## Security invariants

- Accept only bundled and SHA-256-verified Zig sources. Reject arbitrary URL registry dependencies and path traversal.
- Preflight **all** selected files before writing. Reject symlinked destination paths and unmanaged file collisions.
- Record checksums in `.zevui/components.lock.json`. Refuse to update a locally edited/missing file even when upstream changed.
- Writes must be atomic where supported; keep backups or a Git restore path before migrations.
- Never run generated code or install untrusted binaries merely to show a preview.

## References

- `docs/components.md` — component API and installer details.
- `https://ui.shadcn.com/docs/registry/registry-item-json` — inspiration for registry metadata. Zevui uses its own Zig-aware installer; the official shadcn CLI does not install these Zig files.
- `https://github.com/david-vanderson/dvui` — DVUI API and source.
