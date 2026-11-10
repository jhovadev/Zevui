//! CSV Explorer test and benchmark steps. Not part of Zevui's reusable build API.
const std = @import("std");

pub fn addSteps(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    identity_options: *std.Build.Step.Options,
) void {
    const zdata_dep = b.dependency("zdata", .{ .target = target, .optimize = optimize });
    const zdata_module = zdata_dep.module("zdata");
    const identity_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/app/identity.zig"), .target = target, .optimize = optimize,
    }) });
    identity_tests.root_module.addOptions("zevui_config", identity_options);
    const csv_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/csv.zig"), .target = target, .optimize = optimize,
    }) });
    csv_tests.root_module.addImport("zdata", zdata_module);
    const search_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/search.zig"), .target = target, .optimize = optimize,
    }) });
    search_tests.root_module.addImport("zdata", zdata_module);
    const tokens_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/ui/tokens.zig"), .target = target, .optimize = optimize,
    }) });
    const hooks_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/ui/hooks.zig"), .target = target, .optimize = optimize,
    }) });
    const config_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("zevui/config.zig"), .target = target, .optimize = optimize,
    }) });
    const test_step = b.step("test", "Headless correctness: Zevui core + CSV reader");
    const compile_step = b.step("test-compile", "Compile headless tests without executing foreign binaries");
    for ([_]*std.Build.Step.Compile{
        identity_tests, csv_tests, search_tests, tokens_tests, hooks_tests, config_tests,
    }) |test_artifact| {
        test_step.dependOn(&b.addRunArtifact(test_artifact).step);
        compile_step.dependOn(&test_artifact.step);
    }
    const bench = b.addExecutable(.{ .name = "zdata-csv-bench", .root_module = b.createModule(.{
        .root_source_file = b.path("src/bench.zig"), .target = target, .optimize = optimize,
    }) });
    bench.root_module.addImport("zdata", zdata_module);
    const bench_step = b.step("bench", "CSV benchmark, optionally -- <file.csv>");
    const bench_run = b.addRunArtifact(bench);
    bench_run.addPassthruArgs();
    bench_step.dependOn(&bench_run.step);
}
