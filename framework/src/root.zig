//! Public Zevui runtime API (Zig 0.17.1).
//! No CSV parser, ZData, Initializr or application-specific identity here.

pub const config = @import("config.zig");
pub const storage = @import("storage.zig");

/// UI primitives are reusable with or without the CSV Explorer.
/// `tokens` and `hooks` have no DVUI dependency; adapters render via DVUI.
pub const ui = struct {
    pub const tokens = @import("ui/tokens.zig");
    pub const hooks = @import("ui/hooks.zig");
    pub const style = @import("ui/dvui_style.zig");
    pub const components = @import("ui/components.zig");
    pub const icons = @import("ui/icons.zig");
    pub const heatmap = @import("ui/heatmap.zig");
    pub const heatmap_model = @import("ui/heatmap_model.zig");
    pub const progress = @import("ui/progress.zig");
    pub const calendar_model = @import("ui/calendar_model.zig");
    pub const calendar = @import("ui/calendar.zig");
    pub const input = @import("ui/input.zig");
    pub const checkbox_field = @import("ui/checkbox_field.zig");
    pub const separator = @import("ui/separator.zig");
};
