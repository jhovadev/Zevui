//! Source-owned single-date calendar for DVUI. The caller owns the state.
const std = @import("std");
const dvui = @import("dvui");
const model = @import("calendar_model.zig");
pub const Date = model.Date;
pub const State = struct {
    visible: model.Month,
    selected: ?Date = null,
    pub fn init(today: Date) State {
        return .{ .visible = .{ .year = today.year, .month = today.month }, .selected = if (today.valid()) today else null };
    }
};
pub const Options = struct { disabled_before: ?Date = null, disabled_after: ?Date = null };
fn ordinal(d: Date) u32 { return @as(u32, d.year) * 10000 + @as(u32, d.month) * 100 + d.day; }
fn enabled(date: Date, opts: Options) bool {
    return (opts.disabled_before == null or ordinal(date) >= ordinal(opts.disabled_before.?)) and
        (opts.disabled_after == null or ordinal(date) <= ordinal(opts.disabled_after.?));
}
/// Returns true if selected date changed. No implicit clock/timezone conversion.
pub fn draw(src: std.builtin.SourceLocation, state: *State, opts: Options) bool {
    var changed = false;
    var root = dvui.box(src, .{ .dir = .vertical }, .{});
    defer root.deinit();
    {
        var header = dvui.box(@src(), .{ .dir = .horizontal }, .{});
        defer header.deinit();
        if (dvui.button(@src(), "<", .{}, .{})) {
            if (model.shift(state.visible, -1)) |next| state.visible = next;
        }
        if (state.visible.month >= 1 and state.visible.month <= 12) {
            dvui.label(@src(), "{s} {d}", .{ model.month_names[state.visible.month - 1], state.visible.year }, .{ .font = .theme(.heading) });
        }
        if (dvui.button(@src(), ">", .{}, .{})) {
            if (model.shift(state.visible, 1)) |next| state.visible = next;
        }
    }
    {
        var week = dvui.box(@src(), .{ .dir = .horizontal }, .{});
        defer week.deinit();
        for (model.day_names, 0..) |name, i| {
            dvui.label(@src(), "{s}", .{name}, .{ .id_extra = i, .min_size_content = .width(31) });
        }
    }
    for (0..6) |row| {
        var week = dvui.box(@src(), .{ .dir = .horizontal }, .{ .id_extra = row });
        defer week.deinit();
        for (0..7) |col| {
            const date = model.cell(state.visible, row * 7 + col);
            if (date) |d| {
                var buffer: [3]u8 = undefined;
                const day_label = std.fmt.bufPrint(&buffer, "{d}", .{d.day}) catch unreachable;
                if (enabled(d, opts)) {
                    const is_selected = if (state.selected) |s| ordinal(s) == ordinal(d) else false;
                    if (dvui.button(@src(), day_label, .{}, .{ .id_extra = col, .min_size_content = .width(31), .color_fill = if (is_selected) .{ .color = .{ .r = 191, .g = 179, .b = 255 } } else .{ .color = .{ .r = 43, .g = 45, .b = 55 } } })) {
                        state.selected = d;
                        changed = true;
                    }
                } else dvui.label(@src(), "{s}", .{day_label}, .{ .id_extra = col, .min_size_content = .width(31) });
            } else {
                dvui.label(@src(), " ", .{}, .{ .id_extra = col, .min_size_content = .width(31) });
            }
        }
    }
    return changed;
}
