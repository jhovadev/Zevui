# Zevui M0.5 — typed build configuration (Zig 0.17.1)

**Scope:** a reusable `addApp` Zig build function, a typed `.zon` file, typed
platform overrides, build-time app options, and a second independent GUI app.
The build core is now a **separate Zig package** in `framework/` consumed
through a local `.path` dependency. It has not been published at a stable
remote URL/hash; see [F3](architecture/f3-sdk-extraction.md). There is no Zevui CLI or runtime plugin loader.

## Application files

```text
build.zig                 thin orchestration of two applications
zevui.zon                 CSV Explorer defaults: title, ID, appearance
zevui.windows.zon         typed optional Windows window/title overrides
zevui.macos.zon           typed optional macOS overrides
framework/src/config.zig          schema, validation and merge behavior (pure Zig)
framework/build.zig           addApp, b.addOptions, DVUI wiring, Windows GUI
examples/csv-explorer/src/app/identity.zig      runtime shim over @import("zevui_config")
examples/minimal/         independent DVUI application; no ZData import
examples/csv-explorer/build.zig    headless tests and CSV benchmark only
```

The source of truth for app identity and default window dimensions is
`zevui.zon`. `examples/csv-explorer/src/app/identity.zig` is the view adapter for the CSV example;
**do not edit it when rebranding**. The names and sizes are injected through
`std.Build.Step.Options`, so app code never imports a ZON outside its module
root (the same problem addressed by M0.4.1 for embedded icons).

## Consume the build helper

```zig
const std = @import("std");
const zevui = @import("framework/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const config: zevui.Config = @import("zevui.zon");
    _ = zevui.addApp(b, config, .{
        .target = target,
        .optimize = optimize,
        .root_source_file = "examples/csv-explorer/src/main.zig",
    });
}
```

This sample uses a **local build helper import**. The public runtime UI kit
is obtained via the local Zig package dependency `b.dependency("zevui", ...)`
and `sdk_dep.module("zevui")`; the consumer injects its pinned DVUI module to
avoid duplicate type identities. External package consumption remains a
required F5 compatibility test. No custom
CLI is required for either form: `zig build` is the source of truth.

`addApp` attaches `dvui_sdl3`, adds the `zevui_config` options module, and
optionally imports ZData if `config.modules.zdata` is `true`. Only the CSV
example imports ZData. The smaller app declares `.zdata = false` and can be
compiled with `zig build minimal -Doptimize=ReleaseSafe`. Since both examples
currently share one workspace build graph, the **workspace manifest still
requires ZData for the CSV application**, even when only `minimal` is built.
Remote publication and independent-package consumption are F4/F5 gates;
the F3 `framework/` package is locally importable and independently testable.

The helper also exposes the existing portable GUI profile, keeps Windows GUI
subsystem behavior and supports a debug-console opt-in. Windows resource
paths are supplied by the caller; a blank new project is not forced to use
the CSV example's Zevui icon.

## Typed configuration and overrides

The root file is imported with an expected type:

```zig
const base: zevui.Config = @import("zevui.zon");
const windows: zevui.Override = @import("zevui.windows.zon");
const config = zevui.resolve(base, windows);
```

An override may set `identity.title` / `identity.display_name` or selected
`window` dimensions, but not arbitrary modules or package dependencies. Fields
not supplied remain unchanged. Invalid identifiers, dimensions or appearance
values are rejected during the build. To change Windows width only:

```zig
.{ .window = .{ .width = 1200 } }
```

Runtime preferences such as current theme and recent files will eventually
be stored separately (default proposal: `settings.json`). Do **not** edit the
build ZON to save a runtime preference. SQLite, JSON stores, migrations,
plugin discovery and the CLI are not implemented in M0.5.

## Validation and release gates

```sh
just setup    # only on a fresh project, to pin the ZData SDK
just check    # unit + Python contract tests
just minimal     # compile second GUI, no ZData application imports
just run-minimal # actually launch second DVUI example
just run      # CSV Explorer
just windows-x64       # experimental Windows cross-build
just windows-gui-check # inspect PE subsystem if cross-build succeeded
```

The tests in `tests/test_build_core.py` are static architecture checks, not a
substitute for a Zig compilation. In particular, a successful `just check` does
not prove `zig build minimal` works on Windows or macOS, or that the SDL
backend correctly sets operating-system-specific metadata. That must be tested
on target hosts.

### Roadmap boundary

- **M0.5.1:** independently publish the Zevui build/runtime package, validate
  third-party adoption, and finish bundle/tray work.
- **M0.6:** conformant `KeyValueStore` with in-memory and JSON backends.
- **M0.6.1:** optional SQLite module and transactional migrations.
- **M0.7:** optional thin CLI (`new`, `add`, `doctor`, `bundle`).

No C dependencies, storage engines, format parsers or dynamic plugins are
silently added by M0.5.
