//! Minimal semantic divider using DVUI layout primitives.
const std = @import("std");
const dvui = @import("dvui");
pub const Direction = enum { horizontal, vertical };
pub const Options = struct {
    direction: Direction = .horizontal,
    length: f32 = 200,
    thickness: f32 = 1,
    color: dvui.ColorOrGradient = .{ .color = .{ .r = 90, .g = 87, .b = 101 } },
};
pub fn draw(src: std.builtin.SourceLocation, opts: Options) void {
    var bar = dvui.box(src, .{}, .{
        .background = true,
        .color_fill = opts.color,
        .padding = .all(0),
        .border = .all(0),
        .min_size_content = if (opts.direction == .horizontal)
            .{ .w = opts.length, .h = opts.thickness }
        else
            .{ .w = opts.thickness, .h = opts.length },
    });
    bar.deinit();
}
