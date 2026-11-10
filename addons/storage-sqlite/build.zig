//! Compile just this package: zig build test -Dsqlite=system|bundled|off.
//! All C/link flags are module-local; importing this module is opt-in.
const std = @import("std");
const Mode = enum { bundled, system, off };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mode = b.option(Mode, "sqlite", "SQLite provider: bundled, system, off") orelse .bundled;
    const source: []const u8 = if (mode == .off) "src/off.zig" else "src/root.zig";

    const addon = b.addModule("zevui_module", .{
        .root_source_file = b.path(source), .target = target, .optimize = optimize,
    });
    configure(b, addon, mode);

    const suite = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path(source), .target = target, .optimize = optimize,
    }) });
    configure(b, suite.root_module, mode);

    const tests = b.step("test", "Test the selected SQLite provider");
    tests.dependOn(&b.addRunArtifact(suite).step);
}

fn configure(b: *std.Build, module: *std.Build.Module, mode: Mode) void {
    switch (mode) {
        .off => {}, // Hard guarantee: no libc or sqlite3 symbols are linked.
        .system => {
            module.link_libc = true;
            module.linkSystemLibrary("sqlite3", .{ .use_pkg_config = .no });
        },
        .bundled => {
            // Explicit vendor step; never download or silently replace C sources at build time.
            // Run python3 tools/vendor_sqlite.py once, then check in the reviewed source files.
            module.link_libc = true;
            module.addCSourceFile(.{
                .file = b.path("vendor/sqlite3.c"),
                .flags = &.{
                    "-DSQLITE_THREADSAFE=1",
                    "-DSQLITE_OMIT_LOAD_EXTENSION=1",
                    "-DSQLITE_DQS=0",
                },
            });
        },
    }
}
