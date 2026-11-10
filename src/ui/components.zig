//! Small semantic components. Callers pass @src() so immediate-mode IDs are
//! attached to the CALL SITE (do not reuse one ID for all buttons).
const std = @import("std");
const dvui = @import("dvui");
const style = @import("dvui_style.zig");

pub const Variant = enum { primary, secondary, selected };

pub fn action(comptime caller: std.builtin.SourceLocation, label: []const u8, variant: Variant, p: style.Palette) bool {
    const selected = variant == .selected;
    return dvui.button(caller, label, .{}, .{
        .background = true,
        .color_fill = switch (variant) {
            .primary => p.accent,
            .secondary => p.elevated,
            .selected => p.accent_soft,
        },
        .color_text = if (variant == .primary) p.on_accent else p.text,
        .color_border = if (selected) p.accent else p.border,
        .border = if (selected) .all(2) else .all(1),
        .corners = .round(9),
        .padding = .all(8),
        .gravity_y = 0.5,
    });
}

/// Accessible vector icon action (TinyVG converted from editable SVG source).
/// Falls back to a text button if this DVUI build disables vector graphics.
pub fn iconAction(
    comptime caller: std.builtin.SourceLocation,
    label: []const u8,
    tvg_bytes: ?[]const u8,
    variant: Variant,
    p: style.Palette,
) bool {
    if (tvg_bytes) |bytes| {
        return dvui.buttonIcon(caller, label, bytes, .{}, .{
            .fill_color = if (variant == .primary) p.on_accent else p.text,
            .stroke_color = if (variant == .primary) p.on_accent else p.text,
        }, .{
            .background = true,
            .color_fill = if (variant == .primary) p.accent else p.elevated,
            .color_border = p.border,
            .border = .all(1),
            .corners = .round(8),
            .padding = .all(7),
            .label = .{ .text = label },
            .gravity_y = 0.5,
        });
    }
    return action(caller, label, variant, p);
}
