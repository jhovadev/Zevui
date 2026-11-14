//! Zevui activity heatmap for DVUI with Zig 0.17.1. Copy this file together with
//! heatmap_model.zig into src/components for a source-owned component.
const std = @import("std");
const dvui = @import("dvui");
const model = @import("heatmap_model.zig");

pub const Options = struct {
    cell_size: f32 = 12,
    gap: f32 = 3,
    /// Accessible contrast alternatives can be supplied by the consumer.
    palette: [5]dvui.ColorOrGradient = .{
        .{ .color = .{ .r = 43, .g = 45, .b = 55 } },
        .{ .color = .{ .r = 16, .g = 82, .b = 63 } },
        .{ .color = .{ .r = 28, .g = 129, .b = 94 } },
        .{ .color = .{ .r = 44, .g = 176, .b = 120 } },
        .{ .color = .{ .r = 94, .g = 224, .b = 164 } },
    },
};

/// Column-major order: each consecutive group of seven values is one week.
/// Start on Monday; fill missing calendar days with zero before calling draw.
/// Widget IDs derive from caller, week and weekday for stable immediate-mode IDs.
pub fn draw(src: std.builtin.SourceLocation, counts: []const u32, opts: Options) void {
    if (!model.validWeeks(counts)) {
        dvui.label(src, "Heatmap requires complete weeks (7 days each)", .{}, .{});
        return;
    }

    const max = model.maximum(counts);
    var row = dvui.box(src, .{ .dir = .horizontal }, .{
        .background = false,
        .padding = .all(0),
    });
    defer row.deinit();

    for (0..counts.len / model.days_per_week) |week| {
        var column = dvui.box(@src(), .{ .dir = .vertical }, .{
            .id_extra = week,
            .background = false,
            .padding = .all(0),
            .margin = .{ .w = opts.gap },
        });
        defer column.deinit();

        for (0..model.days_per_week) |weekday| {
            const index = week * model.days_per_week + weekday;
            const value = counts[index];
            const shade: usize = model.intensity(value, max);
            var cell = dvui.box(@src(), .{}, .{
                .id_extra = weekday,
                .background = true,
                .min_size_content = .{ .w = opts.cell_size, .h = opts.cell_size },
                .margin = .{ .h = opts.gap },
                .padding = .all(0),
                .border = .all(0),
                .corners = .round(2),
                .color_fill = opts.palette[shade],
            });
            const rect = cell.data().borderRectScale().r;
            if (rect.intersect(dvui.clipGet()).contains(dvui.currentWindow().mouse_pt)) {
                dvui.tooltip(@src(), .{ .active_rect = rect, .delay = 150_000 },
                    "Day {d}: {d} activities", .{ index + 1, value }, .{ .id_extra = index });
            }
            cell.deinit();
        }
    }
}
