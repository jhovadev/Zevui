# Contributing to Zevui

This is a small application that **consumes ZData** rather than a replacement
for Zig Data Engine itself. Keep changes scoped to the appropriate project.

## Local workflow

1. Install Zig 0.17.1, `just` and Python 3; run `just setup` on a fresh clone.
2. Run `just check` and inspect `git diff --check` before creating a PR.
3. Exercise the GUI with `testdata/sample_1500.csv` using `just run` and compile the independent app with `just minimal`.
4. For cross-target changes, run `just cross-headless <target>` followed by
   `just cross <target>`; a successful cross compile **does not** prove runtime
   support. Describe which target OS, arch and runtime were actually tested.
5. Avoid benchmark claims without the command, input, hardware and comparison
   baseline. Do not commit actual customer CSVs.

## Code boundaries

- `zevui/config.zig`, `zevui/build.zig`: reusable typed build configuration and addon wiring.
- `zevui.zon`, `zevui.windows.zon`, `zevui.macos.zon`: application-specific build settings.
- `examples/minimal`: second consumer with no dependency on ZData.
- `examples/csv/build.zig`: CSV-only tests and benchmark setup.


- `src/csv.zig`: CSV-specific parsing, error rules and dialect interpretation.
- `src/main.zig`: DVUI window/UI state; keep it independent of SDK internals.
- `src/search.zig`: app-local search/filter/sort (until a general kernel exists).
- ZData: generic algorithms, allocation, stats and scan primitives only.

Keep `build.zig.zon` pinned: review dependency updates deliberately. The main
package must not depend on `../zig-data-engine` or on an unspecified branch.

## Initializr UI (SolidStart)

For the project generator use Node.js 24+, Bun, and Python 3. Run `just initializr-setup`, then `just initializr`. The authoritative generator stays in `initializr/generator.py`; do not fork its validation into browser-only logic. Add a Python contract test for generated code/archives whenever changing addon features. Before opening a PR, run `just initializr-check` and (with JS dependencies installed) `just initializr-build`. Do not commit `apps/initializr/node_modules` or generated build outputs.

### Addons and registry

See `registry/README.md` for the official-only addon review process and `just ecosystem-check` for the registry/planner gates. Do not mark a planned addon as available without a working Zig source, pinned external dependencies when applicable, and an end-to-end generated-project build.
