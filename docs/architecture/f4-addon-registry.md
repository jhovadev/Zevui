# F4 — independent Zig addon packages and reviewed registry

Status: **implemented as local packages and deterministic registry metadata**.
Publishing remote addon pins / changing Initializr generation is **not** claimed.
The F3.1 change to the `@import("zevui")` build module remains mandatory.

## Physical migration

| Before F4 | After F4 |
| --- | --- |
| `addons/memory_store.zig` | `addons/memory-store/src/root.zig` (`git mv`) |
| `addons/design_tokens.zig` | `addons/design-tokens/src/root.zig` (`git mv`) |
| no per-addon manifest | `addons/*/addon.json`, `build.zig`, `build.zig.zon`, `LICENSE`, `README.md` |
| `registry/catalog.json` hand-edited | `registry/registry.json` + per-addon manifests -> generated compat catalog |
| no versioned channel metadata | `registry/dist/metadata-0.17.json` |
| no release tooling | `tools/build_registry.py`, `tools/pin_addon.py` |

## Public Zig contract

Each standalone package exposes `zevui_module` through `b.addModule`. It can be
built and tested in isolation: `(cd addons/memory-store && zig build test)`.
The pure Zig addon sources remain byte-identical to the F2 golden outputs.
The base SDK `framework/` does not import addon modules and keeps its existing
API, and `zevui.zon` keys are unchanged. The CSV Explorer does not consume
these optional addons; its runtime should not acquire accidental new deps.

## Temporary bridge and intentional limitations

The F2 deterministic ZIP and CLI still vendor **only selected** addon `root.zig`
files into `src/addons/*.zig`. Source mappings in the generated compatibility
catalog point to the new package paths; emitted filenames, bytes and SHA-256
are unchanged. This is not an installable remote addon architecture **yet**:
`package: null` means no reviewed URL/hash has been published. The F5 stage
replaces source-copy with package dependencies only after real `zig fetch`
hashes are committed, and updates golden tests in a dedicated PR.

The framework's own `ui.tokens` duplicates part of the standalone
`design_tokens` addon. Treat the SDK's public tokens as core, and the optional
addon as a compatibility starter; remove duplication only with a deliberate
API compatibility decision.

## Gates and rollback

```sh
python3 tools/build_registry.py --check
python3 -m unittest discover -s tests -v
just addons-check
just framework-check
just registry-check
just ecosystem-check
just initializr-build
just check
just minimal
just run
```

Zig runtime builds and SolidStart builds must run on the user's toolchain / CI;
Python tests and `tsc` alone cannot prove Zig module compatibility. Revert the
F4 commit if package builds fail; the previous `registry/catalog.json` and
`addons/*.zig` source-copy layout is preserved in Git history. No `zig fetch`
was run here because no public addon URL exists.
