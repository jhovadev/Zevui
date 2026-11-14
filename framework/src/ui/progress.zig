//! Source-owned native DVUI progress bar. No browser or state framework.
const std = @import("std");
const dvui = @import("dvui");

pub const Options = struct {
    width: f32 = 200,
    height: f32 = 9,
    track: dvui.ColorOrGradient = .{ .color = .{ .r = 60, .g = 61, .b = 70 } },
    fill: dvui.ColorOrGradient = .{ .color = .{ .r = 191, .g = 179, .b = 255 } },
};

/// The caller owns progress state; value is clamped to maximum.
/// Use @src() at each distinct call site.
pub fn draw(src: std.builtin.SourceLocation, value: u64, maximum: u64, opts: Options) void {
    const fraction: f32 = if (maximum == 0) 0 else
        @floatCast(@as(f64, @floatFromInt(@min(value, maximum))) /
            @as(f64, @floatFromInt(maximum)));
    var track = dvui.box(src, .{ .dir = .horizontal }, .{
        .background = true,
        .min_size_content = .{ .w = opts.width, .h = opts.height },
        .color_fill = opts.track,
        .padding = .all(0),
        .corners = .round(4),
    });
    defer track.deinit();
    if (fraction > 0) {
        var fill = dvui.box(@src(), .{}, .{
            .background = true,
            .min_size_content = .{ .w = opts.width * fraction, .h = opts.height },
            .color_fill = opts.fill,
            .padding = .all(0),
            .corners = .round(4),
        });
        fill.deinit();
    }
}
