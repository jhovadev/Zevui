# Zevui addon: `design_tokens`

Standalone Zig 0.17.1 package. `zig build test` runs the embedded Zig unit tests.

The public module is `zevui_module`. Consumers declare the package as a Zig
dependency by `url` + `hash` (once officially published) and add its module:

```zig
const addon = b.dependency("design_tokens", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("design_tokens", addon.module("zevui_module"));
```

**F4 transitional behavior:** Initializr still copies this package's `src/root.zig`
into generated projects under `src/addons/design_tokens.zig`, preserving F2 golden output.
`package: null` in `addon.json` means this addon is NOT yet published or pinned.
The source-copy bridge is removed only after F5 publishes immutable package pins.
