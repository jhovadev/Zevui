//! Zevui build-time configuration. No DVUI, SDL, ZData or libc dependency.
//! Consumed by build.zig; changing a runtime preference does not rewrite ZON.
const std = @import("std");

pub const Identity = struct {
    name: []const u8,
    title: []const u8,
    display_name: []const u8,
    short_name: []const u8,
    screen_name: []const u8,
    version: []const u8,
    organization: []const u8,
    application: []const u8,
};

pub const Window = struct {
    width: u32 = 1100,
    height: u32 = 720,
    min_width: u32 = 640,
    min_height: u32 = 480,
};

pub const Appearance = struct {
    theme: []const u8 = "graphite",
    accent: []const u8 = "lavender",
    density: []const u8 = "compact",
};

pub const Modules = struct {
    zdata: bool = false,
};

pub const Config = struct {
    identity: Identity,
    window: Window = .{},
    appearance: Appearance = .{},
    modules: Modules = .{},
};

pub const IdentityOverride = struct {
    title: ?[]const u8 = null,
    display_name: ?[]const u8 = null,
};

pub const WindowOverride = struct {
    width: ?u32 = null,
    height: ?u32 = null,
    min_width: ?u32 = null,
    min_height: ?u32 = null,
};

pub const Override = struct {
    identity: ?IdentityOverride = null,
    window: ?WindowOverride = null,
};

/// Typed replacement semantics: only fields present in the override change.
/// No generic JSON merge and no changes to package dependencies.
pub fn resolve(base: Config, override: Override) Config {
    var result = base;
    if (override.identity) |identity| {
        if (identity.title) |title| result.identity.title = title;
        if (identity.display_name) |name| result.identity.display_name = name;
    }
    if (override.window) |window| {
        if (window.width) |n| result.window.width = n;
        if (window.height) |n| result.window.height = n;
        if (window.min_width) |n| result.window.min_width = n;
        if (window.min_height) |n| result.window.min_height = n;
    }
    return result;
}

pub const ConfigError = error{ InvalidIdentity, InvalidWindow, InvalidTheme, InvalidAccent, InvalidDensity };

pub fn validate(cfg: Config) ConfigError!void {
    if (cfg.identity.name.len == 0 or cfg.identity.title.len == 0 or
        cfg.identity.application.len == 0 or cfg.identity.organization.len == 0 or
        cfg.identity.version.len == 0) return error.InvalidIdentity;
    if (std.mem.indexOfScalar(u8, cfg.identity.name, ' ') != null or
        std.mem.indexOfScalar(u8, cfg.identity.application, ' ') != null)
        return error.InvalidIdentity;
    if (cfg.window.width < cfg.window.min_width or cfg.window.height < cfg.window.min_height or
        cfg.window.min_width == 0 or cfg.window.min_height == 0)
        return error.InvalidWindow;
    if (!oneOf(cfg.appearance.theme, &.{ "graphite", "light", "contrast" }))
        return error.InvalidTheme;
    if (!oneOf(cfg.appearance.accent, &.{ "lavender", "coral", "mint", "sky", "amber" }))
        return error.InvalidAccent;
    if (!oneOf(cfg.appearance.density, &.{ "compact", "comfortable" }))
        return error.InvalidDensity;
}

fn oneOf(value: []const u8, choices: []const []const u8) bool {
    for (choices) |choice| {
        if (std.mem.eql(u8, value, choice)) return true;
    }
    return false;
}

test "typed override preserves unspecified values" {
    const base: Config = .{
        .identity = .{
            .name = "example", .title = "Example", .display_name = "Example",
            .short_name = "EX", .screen_name = "Home", .version = "0.1.0",
            .organization = "dev.example", .application = "example",
        },
        .window = .{ .width = 1100, .height = 720, .min_width = 640, .min_height = 480 },
    };
    const out = resolve(base, .{ .window = .{ .width = 1200 } });
    try std.testing.expectEqual(@as(u32, 1200), out.window.width);
    try std.testing.expectEqual(@as(u32, 720), out.window.height);
    try std.testing.expectEqualStrings("example", out.identity.application);
    try validate(base);
}

test "invalid window is rejected" {
    var cfg: Config = .{ .identity = .{
        .name = "test", .title = "Test", .display_name = "Test", .short_name = "T",
        .screen_name = "Test", .version = "0.1.0",
        .organization = "dev.test", .application = "test",
    } };
    cfg.window.width = 200;
    try std.testing.expectError(error.InvalidWindow, validate(cfg));
    cfg.window.width = 1100;
    cfg.appearance.theme = "invalid";
    try std.testing.expectError(error.InvalidTheme, validate(cfg));
}
