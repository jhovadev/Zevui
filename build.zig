//! Single build entry: Zevui provides the reusable GUI build, CSV adds its tests.
const std = @import("std");
// Build-time API comes from the declared .zevui package, not a file path.
// Importing framework/build.zig by path duplicates its module ownership in Zig 0.17.1.
const zevui = @import("zevui");
const csv = @import("examples/csv-explorer/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const portable = b.option(bool, "portable-gui", "Reduce optional DVUI dependencies") orelse false;
    const windows_console = b.option(bool, "windows-console", "Show a debug console on Windows") orelse false;
    const base: zevui.Config = @import("zevui.zon");
    const windows: zevui.Override = @import("zevui.windows.zon");
    const macos: zevui.Override = @import("zevui.macos.zon");
    const config = switch (target.result.os.tag) {
        .windows => zevui.resolve(base, windows),
        .macos => zevui.resolve(base, macos),
        else => base,
    };
    const app = zevui.addApp(b, config, .{
        .target = target, .optimize = optimize, .root_source_file = "examples/csv-explorer/src/main.zig",
        .portable_gui = portable, .windows_console = windows_console,
        .windows_resource = "assets/windows/zevui.rc",
        .windows_icon_directory = "assets/branding",
        .dvui_run_alias = true,
    });
    // Public Zevui SDK module comes from a local path package in the monorepo.
    // Swap .path for a pinned .url/.hash when the SDK is published (F4/F5).
    const sdk_dep = b.dependency("zevui", .{ .target = target, .optimize = optimize });
    const kit = sdk_dep.module("zevui");
    // UI adapters must share the exact DVUI module used by the application.
    const dvui_dep = b.dependency("dvui", .{
        .target = target, .optimize = optimize, .backend = .sdl3,
    });
    kit.addImport("dvui", dvui_dep.module("dvui_sdl3"));
    app.executable.root_module.addImport("zevui", kit);
    csv.addSteps(b, target, optimize, app.config_options);

    // Independent second app: no ZData import, no CSV code, no separate build DSL.
    const minimal_config: zevui.Config = @import("examples/minimal/zevui.zon");
    const minimal = zevui.addApp(b, minimal_config, .{
        .target = target, .optimize = optimize,
        .root_source_file = "examples/minimal/main.zig",
        .portable_gui = portable, .install = false, .run_step = null,
    });
    minimal.executable.root_module.addImport("zevui", kit);
    const minimal_step = b.step("minimal", "Compile the Zevui app without ZData");
    minimal_step.dependOn(&minimal.executable.step);
    const minimal_run_step = b.step("minimal-run", "Run the independent Zevui DVUI app");
    minimal_run_step.dependOn(&b.addRunArtifact(minimal.executable).step);
}
