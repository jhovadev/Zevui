# Zevui SDK (Zig 0.17.1)

Zevui provides a Zig build helper (`addApp`) and a native UI kit backed by
[DVUI](https://github.com/david-vanderson/dvui). This package is intentionally
independent of **CSV Explorer**, **ZData**, **Initializr**, **registry** and
optional addons. It is a community package, not an official DVUI distribution.

## Package contract

- `build.zig` — standalone package build and `addApp(b, config, options)`.
- `src/config.zig` — typed app configuration (`identity`, `window`, `appearance`, `modules`) and platform overrides.
- `src/root.zig` — public `@import("zevui")` runtime entrypoint.
- `src/ui/` — design tokens, explicit state helpers and DVUI adapters/icons.
- `src/storage.zig` — capability/error types only; **no storage implementation**.

Run standalone headless checks (no CSV or ZData dependency):

```sh
cd framework
zig build test -Doptimize=ReleaseSafe
```

The Zig package manager can consume this package using `zig fetch --save=zevui
<verified-release-url>` once a release is published and pinned. **This F3
package has not been published as a URL/hash and has not yet passed a tested
external-consumer flow.** During the monorepo migration the root manifest uses
`.zevui = .{ .path = "framework" }`. Run `just f3-wire` to insert that local
dependency without modifying or overwriting existing package pins. Zig 0.17.1 computes the package fingerprint
from the name's CRC-32 and a stable 32-bit unique identifier.

The package deliberately does **not** own a copy of the DVUI/SDL3 dependency.
The consuming app supplies the same DVUI module to both its `dvui.App` and
Zevui's UI adapters. This avoids divergent DVUI type identities. A consumer
using the `addApp` build helper must declare and pin DVUI itself.

Example (from the monorepo root `build.zig`):

```zig
const zevui = @import("framework/build.zig");
const sdk_dep = b.dependency("zevui", .{ .target = target, .optimize = optimize });
const kit = sdk_dep.module("zevui");
const dvui_dep = b.dependency("dvui", .{
    .target = target, .optimize = optimize, .backend = .sdl3,
});
kit.addImport("dvui", dvui_dep.module("dvui_sdl3"));
app.executable.root_module.addImport("zevui", kit);
```

SDK source imports: `const z = @import("zevui"); const tokens = z.ui.tokens;`
The `addApp` helper still supports optional `modules.zdata`, but requires the
**consumer** to pin ZData when enabled. The Zevui SDK never contains ZData
algorithms or a CSV reader.

## Compatibility and boundaries

`framework/build.zig.zon` includes only this package's own files. Platform
SDKs, GPU drivers, SDL display systems and binaries are the responsibility of
consumer apps. Windows GUI executable subsystem is selected by `addApp` unless
`windows_console=true`. Trays, packaging, migrations, SQLite, JSON settings,
permissions and event-loop helpers are **not implemented** by the F3 SDK.

See [`../docs/architecture/f3-sdk-extraction.md`](../docs/architecture/f3-sdk-extraction.md)
for validation gates and the F5 removal of the compatibility template.
