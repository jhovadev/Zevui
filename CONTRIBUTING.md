# Contributing to Zevui

Zevui is a modular SDK and example suite. CSV Explorer **consumes ZData**,
while the framework itself remains independent of the data engine. Keep changes scoped to the appropriate project.

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

- `framework/src/config.zig`, `framework/build.zig`: standalone Zig SDK config and build API.
- `zevui.zon`, `zevui.windows.zon`, `zevui.macos.zon`: application-specific build settings.
- `examples/minimal`: second consumer with no dependency on ZData.
- `examples/csv-explorer/build.zig`: CSV-only tests and benchmark setup.


- `examples/csv-explorer/src/csv.zig`: CSV-specific parsing, error rules and dialect interpretation.
- `examples/csv-explorer/src/main.zig`: DVUI window/UI state; keep it independent of SDK internals.
- `examples/csv-explorer/src/search.zig`: app-local search/filter/sort (until a general kernel exists).
- ZData: generic algorithms, allocation, stats and scan primitives only.

Keep `build.zig.zon` pinned: review dependency updates deliberately. The main
package must not depend on `../zig-data-engine` or on an unspecified branch.

## Initializr UI (SolidStart)

For the generator website use Node.js 24+ and Bun; no Python is needed in production. Run `just initializr-setup`, then `just initializr`. The authoritative renderer and ZIP executor live in `packages/initializr-core/src/generator.ts` alongside the pure planner. Do not duplicate validation in the browser or in server routes. Update TypeScript golden tests whenever changing generated files and keep the old Python oracle under `tests/legacy_oracle/` for regression comparison only. Before a PR, run `just initializr-check` and `just initializr-build`. Do not commit `apps/initializr/node_modules` or generated build outputs.

### Addons and registry

See `registry/README.md` for the official-only addon review process and `just ecosystem-check` for the registry/planner gates. Do not mark a planned addon as available without a working Zig source, pinned external dependencies when applicable, and an end-to-end generated-project build.

## Architecture migration F1–F6

Read [`docs/architecture/f1-freeze.md`](docs/architecture/f1-freeze.md),
[`docs/architecture/migration-roadmap.md`](docs/architecture/migration-roadmap.md)
and the proposed ADRs in [`docs/adr/`](docs/adr/) before renaming/moving code.
Create the Z0+F0 base commit before changing tracked paths; migrate one
phase per commit/PR with `git mv`. Do not claim builds succeeded unless
commands ran; on failed gates, halt rather than bypass tests.

Run `python3 -m unittest discover -s tests -v` as part of `just check`: it
includes `tests/test_architecture_f1.py`. Update the F1 assertions as part
of the **same PR** that moves or replaces a documented API. Preserve
`zevui.zon` public keys and the Windows GUI subsystem/debug override.

### F2 Initializr generator

The production generator is TypeScript only. Changes to rendering require
`just registry-check` and `just ecosystem-check`, plus the frozen oracle
SHA-256 fixtures (`tests/fixtures/initializr-f2-golden.json`). Do not wire
`tests/legacy_oracle/` into any API or CLI route. F3 extracts the standalone SDK package. Run `just framework-check` before any publication.
Generated-project compatibility sources remain frozen under `templates/compat/` until F5.
