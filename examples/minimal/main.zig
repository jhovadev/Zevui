//! Second Zevui consumer: DVUI only, with no ZData CSV or tray imports.
const std = @import("std");
const dvui = @import("dvui");
const config = @import("zevui_config");
const zevui = @import("zevui");

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
    // Compile-time proof: this app consumes the same public Zevui SDK module
    // without pulling in CSV, ZData, storage engines or tray addons.
    const appearance: zevui.ui.tokens.Appearance = .{};
    _ = zevui.ui.tokens.palette(appearance);
    dvui.label(@src(), "{s}", .{config.title}, .{ .font = .theme(.title) });
    dvui.label(@src(), "No data engine, SQLite, or tray is linked.", .{}, .{});
    return .ok;
}
