//! Reusable DVUI checkbox with optional secondary description.
const std = @import("std");
const dvui = @import("dvui");
pub fn draw(src: std.builtin.SourceLocation, checked: *bool, title: []const u8, description: ?[]const u8) bool {
    var column = dvui.box(src, .{ .dir = .vertical }, .{});
    defer column.deinit();
    const changed = dvui.checkbox(@src(), checked, title, .{});
    if (description) |detail| dvui.label(@src(), "{s}", .{detail}, .{ .font = .theme(.body) });
    return changed;
}
