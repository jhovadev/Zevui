//! Second Zevui consumer: DVUI only, with no ZData CSV or tray imports.
const std = @import("std");
const dvui = @import("dvui");
const config = @import("zevui_config");

pub const dvui_app: dvui.App = .{
    .config = .{ .options = .{
        .title = std.fmt.comptimePrint("{s}", .{config.title}),
        .app = std.fmt.comptimePrint("{s}", .{config.application}),
        .org = std.fmt.comptimePrint("{s}", .{config.organization}),
        .size = dvui.Size.cast(.{ .w = config.window_width, .h = config.window_height }),
        .min_size = dvui.Size.cast(.{ .w = config.window_min_width, .h = config.window_min_height }),
    } },
    .frameFn = frame,
};

pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{ .logFn = dvui.App.logFn };

fn frame() !dvui.App.Result {
    dvui.label(@src(), "{s}", .{config.title}, .{ .font = .theme(.title) });
    dvui.label(@src(), "SQLite storage addon selected; data remains local.", .{}, .{});
    return .ok;
}
