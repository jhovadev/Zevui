//! Reusable Zevui build helper. This is a build-time Zig module, not a CLI.
//! addApp operates on the consumer Build so the consumer chooses its SDK pins.
//! The public Zig runtime module is exposed from this package's build() step.
//! Consumers must declare DVUI explicitly when using addApp (opt-in linking).
const std = @import("std");
pub const Config = @import("src/config.zig").Config;
pub const Override = @import("src/config.zig").Override;
pub const resolve = @import("src/config.zig").resolve;

pub const AppOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_source_file: []const u8,
    portable_gui: bool = false,
    windows_console: bool = false,
    windows_resource: ?[]const u8 = null,
    windows_icon_directory: ?[]const u8 = null,
    install: bool = true,
    run_step: ?[]const u8 = "run",
    /// `sdl3-app` is provided for compatibility with dvui-demo/just run.
    dvui_run_alias: bool = false,
};

pub const AppResult = struct {
    executable: *std.Build.Step.Compile,
    config_options: *std.Build.Step.Options,
};

/// Inject config into the application as `@import("zevui_config")`.
/// This avoids importing a .zon outside the src/ module root at runtime.
pub fn configOptions(b: *std.Build, cfg: Config) *std.Build.Step.Options {
    const opts = b.addOptions();
    opts.addOption([]const u8, "name", cfg.identity.name);
    opts.addOption([]const u8, "title", cfg.identity.title);
    opts.addOption([]const u8, "display_name", cfg.identity.display_name);
    opts.addOption([]const u8, "short_name", cfg.identity.short_name);
    opts.addOption([]const u8, "screen_name", cfg.identity.screen_name);
    opts.addOption([]const u8, "version", cfg.identity.version);
    opts.addOption([]const u8, "organization", cfg.identity.organization);
    opts.addOption([]const u8, "application", cfg.identity.application);
    opts.addOption(u32, "window_width", cfg.window.width);
    opts.addOption(u32, "window_height", cfg.window.height);
    opts.addOption(u32, "window_min_width", cfg.window.min_width);
    opts.addOption(u32, "window_min_height", cfg.window.min_height);
    opts.addOption([]const u8, "theme", cfg.appearance.theme);
    opts.addOption([]const u8, "accent", cfg.appearance.accent);
    opts.addOption([]const u8, "density", cfg.appearance.density);
    opts.addOption(bool, "has_zdata", cfg.modules.zdata);
    return opts;
}

pub fn addApp(b: *std.Build, cfg: Config, options: AppOptions) AppResult {
    @import("src/config.zig").validate(cfg) catch |err|
        std.debug.panic("invalid zevui.zon: {s}", .{@errorName(err)});
    const target = options.target;
    const optimize = options.optimize;
    const dvui_dep = if (options.portable_gui)
        b.dependency("dvui", .{
            .target = target, .optimize = optimize, .backend = .sdl3,
            .freetype = false, .@"tiny-file-dialogs" = false, .@"tree-sitter" = false,
        })
    else
        b.dependency("dvui", .{ .target = target, .optimize = optimize, .backend = .sdl3 });

    const module = b.createModule(.{
        .root_source_file = b.path(options.root_source_file),
        .target = target,
        .optimize = optimize,
    });
    module.addImport("dvui", dvui_dep.module("dvui_sdl3"));
    const cfg_options = configOptions(b, cfg);
    module.addOptions("zevui_config", cfg_options);
    // ZData is opt-in; the minimal app has no ZData import or linkage.
    if (cfg.modules.zdata) {
        const dep = b.dependency("zdata", .{ .target = target, .optimize = optimize });
        module.addImport("zdata", dep.module("zdata"));
    }

    const exe = b.addExecutable(.{
        .name = cfg.identity.name,
        .root_module = module,
    });
    if (target.result.os.tag == .windows) {
        if (!options.windows_console) exe.subsystem = .windows;
        if (options.windows_resource) |resource| {
            if (options.windows_icon_directory) |dir| {
                exe.root_module.addWin32ResourceFile(.{
                    .file = b.path(resource),
                    .include_paths = &.{b.path(dir)},
                });
            }
        }
    }

    if (options.install) b.installArtifact(exe);
    if (options.run_step) |name| {
        const run_cmd = b.addRunArtifact(exe);
        if (options.install) run_cmd.step.dependOn(b.getInstallStep());
        run_cmd.addPassthruArgs();
        const run_step = b.step(name, "Run a Zevui DVUI/SDL3 application");
        run_step.dependOn(&run_cmd.step);
        if (options.dvui_run_alias) {
            const alias = b.step("sdl3-app", "Run the DVUI/SDL3 app");
            alias.dependOn(&run_cmd.step);
        }
    }
    return .{ .executable = exe, .config_options = cfg_options };
}

/// Public standalone Zig package entrypoint: cd framework && zig build test.
/// Exposes `@import("zevui")` with design tokens, hooks, and DVUI adapters.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    _ = b.addModule("zevui", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    // DVUI is supplied by consumers of the UI adapters, so the pure SDK
    // itself does not impose a renderer/SDL or duplicate a DVUI module instance.

    const test_step = b.step("test", "Test Zevui's framework (without CSV/ZData)");
    inline for (.{ "src/config.zig", "src/ui/tokens.zig", "src/ui/hooks.zig", "src/ui/heatmap_model.zig", "src/ui/calendar_model.zig", "src/storage.zig" }) |source| {
        const test_artifact = b.addTest(.{ .root_module = b.createModule(.{
            .root_source_file = b.path(source), .target = target, .optimize = optimize,
        }) });
        test_step.dependOn(&b.addRunArtifact(test_artifact).step);
    }
}
