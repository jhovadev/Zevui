//! Standalone memory_store package; no SDL/DVUI, Node, Python, or ZData dependency.
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    _ = b.addModule("zevui_module", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const suite = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    }) });
    const test_step = b.step("test", "Run the standalone memory_store Zig tests");
    test_step.dependOn(&b.addRunArtifact(suite).step);
}
