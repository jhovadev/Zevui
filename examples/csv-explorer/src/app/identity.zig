//! App identity is generated from zevui.zon by Zevui's build helper.
//! Keep PNG embedding next to this module; runtime never reads configuration ZON.
const std = @import("std");
const config = @import("zevui_config");

pub const title: [:0]const u8 = std.fmt.comptimePrint("{s}", .{config.title});
pub const display_name: [:0]const u8 = std.fmt.comptimePrint("{s}", .{config.display_name});
pub const short_name: []const u8 = config.short_name;
pub const screen_name: []const u8 = config.screen_name;
pub const version: []const u8 = config.version;
pub const organization: [:0]const u8 = std.fmt.comptimePrint("{s}", .{config.organization});
pub const application: [:0]const u8 = std.fmt.comptimePrint("{s}", .{config.application});
pub const binary_name: []const u8 = config.name;
pub const window_size = .{ .w = config.window_width, .h = config.window_height };
pub const minimum_size = .{ .w = config.window_min_width, .h = config.window_min_height };
pub const default_theme: []const u8 = config.theme;
pub const default_accent: []const u8 = config.accent;
pub const default_density: []const u8 = config.density;

pub const icon_png: []const u8 = @embedFile("assets/zevui.png");

pub fn valid() bool {
    return title.len != 0 and application.len != 0 and organization.len != 0 and
        std.mem.indexOfScalar(u8, application, ' ') == null;
}

test "identity comes from generated zevui options" {
    try std.testing.expect(valid());
    try std.testing.expectEqualStrings(config.name, binary_name);
    try std.testing.expectEqual(config.window_width, window_size.w);
    try std.testing.expect(icon_png.len > 16);
    try std.testing.expectEqualSlices(u8, "\x89PNG\r\n\x1a\n", icon_png[0..8]);
}
