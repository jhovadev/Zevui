//! Native editable text and password field; external zero-terminated buffer owns data.
const std = @import("std");
const dvui = @import("dvui");
pub const Options = struct {
    label: []const u8,
    placeholder: []const u8 = "",
    password: bool = false,
    multiline: bool = false,
    width: f32 = 220,
};
/// `buffer` is a writable, NUL-terminated fixed-size byte slice managed by caller.
/// Returns true on edit. For variable-length text, use DVUI's buffer_dynamic API.
pub fn draw(src: std.builtin.SourceLocation, buffer: []u8, opts: Options) bool {
    var column = dvui.box(src, .{ .dir = .vertical }, .{});
    defer column.deinit();
    dvui.label(@src(), "{s}", .{opts.label}, .{});
    var entry = dvui.textEntry(@src(), .{
        .text = .{ .buffer = buffer },
        .placeholder = opts.placeholder,
        .password_char = if (opts.password) "*" else null,
        .multiline = opts.multiline,
    }, .{ .min_size_content = .width(opts.width) });
    const edited = entry.text_changed;
    entry.deinit();
    return edited;
}
