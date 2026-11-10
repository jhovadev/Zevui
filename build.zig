//! Single build entry: Zevui provides the reusable GUI build, CSV adds its tests.
const std = @import("std");
const zevui = @import("zevui/build.zig");
const csv = @import("examples/csv/build.zig");

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
        .target = target, .optimize = optimize, .root_source_file = "src/main.zig",
        .portable_gui = portable, .windows_console = windows_console,
        .windows_resource = "assets/windows/zevui.rc",
        .windows_icon_directory = "assets/branding",
        .dvui_run_alias = true,
    });
    csv.addSteps(b, target, optimize, app.config_options);

    // Independent second app: no ZData import, no CSV code, no separate build DSL.
    const minimal_config: zevui.Config = @import("examples/minimal/zevui.zon");
    const minimal = zevui.addApp(b, minimal_config, .{
        .target = target, .optimize = optimize,
        .root_source_file = "examples/minimal/main.zig",
        .portable_gui = portable, .install = false, .run_step = null,
    });
    const minimal_step = b.step("minimal", "Compile the Zevui app without ZData");
    minimal_step.dependOn(&minimal.executable.step);
    const minimal_run_step = b.step("minimal-run", "Run the independent Zevui DVUI app");
    minimal_run_step.dependOn(&b.addRunArtifact(minimal.executable).step);
}
