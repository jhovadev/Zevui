# F5 — Real starter templates and cross-target acceptance

Status: **proposed patch; native Zig gate pending on developer machine**.

## Scope

- `templates/minimal/` is the editable **production** source for `build.zig`, `build.zig.zon`, `zevui.zon`, README, ignore patterns and `src/main.zig`. The TS engine only supplies validated values and joins optional addon imports.
- One `requiredSources(plan)` function enumerates the exact assets for web and CLI. The server enforces `realpath()` within the repo and refuses missing files/symlink escapes.
- `tests/legacy_oracle/` and `templates/compat/` are frozen history, kept because the published Zevui SDK and addons still have no real URL+hash. The source-copy bridge is **still in use** and must not be described as the final package install architecture.
- Zig 0.17.1: `addons/memory-store/src/root.zig` uses `@splat(.{})`; the F2 SHA record stays immutable and F4.1 override describes the intentional correction.

## Acceptance gates

```
just addons-check
just registry-manifests-check
just check
just ecosystem-check
just initializr-build
just minimal
just build
```

`just initializr-build` compiles client/SSR but does **not** prove browser hydration or `/api/generate` responds successfully; verify the UI and download manually. `zig build` and cross builds compile but do not execute foreign binaries. Test generated apps:

```
just new f5-smoke
(cd f5-smoke && zig build test -Doptimize=ReleaseSafe && zig build -Doptimize=ReleaseSafe)
(cd f5-smoke && zig build -Dtarget=x86_64-windows-gnu -Dportable-gui=true)
```

Delete the generated `f5-smoke/` directory after verification, not the repository sources.

## Gates not met yet

- **Public URL+hash** for Zevui SDK and addons. `tools/build_registry.py --require-published` must still fail until actual pins are verified with `zig fetch`. Do not invent them.
- macOS native application package, SDK/link verification and runners on macOS.
- Pairwise add-on coverage for more than the two current official addons.
- `storage-sqlite` with actual bundled C source, translate-c and modes `bundled|system|off` is F6. The mention of `ctransport` has not been verified as an established Zig SQLite binding; confirm its source/API prior to implementation.

## Reversal

Revert the F5 commit. F4.1 source fix is a separate patch and should remain to keep the memory-store compiler green.
