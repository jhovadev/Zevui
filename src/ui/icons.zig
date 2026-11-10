//! SVG sources are embedded and converted to TinyVG ONCE per window lifetime.
//! DVUI's icon rendering uses TinyVG; no SVG parsing happens every frame.
//! SVG inputs live under src/ui/assets so Zig can embed them within the src module.
const std = @import("std");
const dvui = @import("dvui");

pub const Store = struct {
    search: ?[]const u8 = null,
    appearance: ?[]const u8 = null,
    columns: ?[]const u8 = null,

    pub fn init(self: *Store, a: std.mem.Allocator) void {
        if (comptime dvui.useTvg) {
            self.search = dvui.svgToTvg(a, @embedFile("assets/search.svg")) catch null;
            self.appearance = dvui.svgToTvg(a, @embedFile("assets/preferences.svg")) catch null;
            self.columns = dvui.svgToTvg(a, @embedFile("assets/columns.svg")) catch null;
        }
    }

    pub fn deinit(self: *Store, a: std.mem.Allocator) void {
        if (self.search) |bytes| a.free(bytes);
        if (self.appearance) |bytes| a.free(bytes);
        if (self.columns) |bytes| a.free(bytes);
        self.* = .{};
    }
};
