//! Reusable Zevui build helper. This is a build-time Zig module, not a CLI.
//! An external standalone Zevui package will expose this same addApp contract.
const std = @import("std");
pub const Config = @import("config.zig").Config;
pub const Override = @import("config.zig").Override;
pub const resolve = @import("config.zig").resolve;

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
    @import("config.zig").validate(cfg) catch |err|
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
