//! DVUI-specific adapter. The tokens module stays usable in headless tests.
const dvui = @import("dvui");
const t = @import("tokens.zig");
pub const Appearance = t.Appearance;
pub const Spacing = t.Spacing;
pub const Palette = struct {
    canvas: dvui.ColorOrGradient,
    surface: dvui.ColorOrGradient,
    elevated: dvui.ColorOrGradient,
    header: dvui.ColorOrGradient,
    row_alt: dvui.ColorOrGradient,
    border: dvui.ColorOrGradient,
    text: dvui.ColorOrGradient,
    muted: dvui.ColorOrGradient,
    accent: dvui.ColorOrGradient,
    accent_soft: dvui.ColorOrGradient,
    accent_text: dvui.ColorOrGradient,
    on_accent: dvui.ColorOrGradient,
    positive: dvui.ColorOrGradient,
    negative: dvui.ColorOrGradient,
    warning: dvui.ColorOrGradient,
};
fn toDvui(c: t.Color) dvui.ColorOrGradient {
    return .{ .color = .{ .r = c.r, .g = c.g, .b = c.b } };
}
pub fn palette(a: Appearance) Palette {
    const p = t.palette(a);
    return .{
        .canvas = toDvui(p.canvas), .surface = toDvui(p.surface),
        .elevated = toDvui(p.elevated), .header = toDvui(p.header),
        .row_alt = toDvui(p.row_alt), .border = toDvui(p.border),
        .text = toDvui(p.text), .muted = toDvui(p.muted),
        .accent = toDvui(p.accent), .accent_soft = toDvui(p.accent_soft),
        .accent_text = toDvui(p.accent_text),
        .on_accent = toDvui(p.on_accent), .positive = toDvui(p.positive),
        .negative = toDvui(p.negative), .warning = toDvui(p.warning),
    };
}
pub fn accents(mode: t.Mode) [5]dvui.ColorOrGradient {
    return .{ toDvui(t.accentColor(mode, .lavender)), toDvui(t.accentColor(mode, .coral)),
        toDvui(t.accentColor(mode, .mint)), toDvui(t.accentColor(mode, .sky)),
        toDvui(t.accentColor(mode, .amber)) };
}
pub fn spacing(density: t.Density) Spacing { return t.spacing(density); }
pub fn themeFor(mode: t.Mode) dvui.Theme {
    return switch (mode) {
        .light => dvui.Theme.builtin.adwaita_light,
        .graphite, .contrast => dvui.Theme.builtin.adwaita_dark,
    };
}
