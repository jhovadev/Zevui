//! UI design tokens are pure Zig: no DVUI, SDL, OS or ZData dependency.
//! All colors are opaque sRGB. Consumers translate them to backend colors.
const std = @import("std");

pub const Color = struct { r: u8, g: u8, b: u8 };
pub const Mode = enum { graphite, light, contrast };
pub const Density = enum { comfortable, compact };
pub const Accent = enum { lavender, coral, mint, sky, amber };

pub const Appearance = struct {
    mode: Mode = .graphite,
    density: Density = .compact,
    accent: Accent = .lavender,

    pub fn cycleMode(self: *Appearance) void {
        self.mode = switch (self.mode) { .graphite => .light, .light => .contrast, .contrast => .graphite };
    }
    pub fn cycleAccent(self: *Appearance) void {
        self.accent = switch (self.accent) {
            .lavender => .coral, .coral => .mint, .mint => .sky, .sky => .amber, .amber => .lavender,
        };
    }
    pub fn toggleDensity(self: *Appearance) void {
        self.density = switch (self.density) { .comfortable => .compact, .compact => .comfortable };
    }
};

pub fn modeName(mode: Mode) []const u8 {
    return switch (mode) { .graphite => "Graphite", .light => "Light", .contrast => "Contrast" };
}
pub fn accentName(accent: Accent) []const u8 {
    return switch (accent) { .lavender => "Lavanda", .coral => "Coral", .mint => "Menta", .sky => "Azul", .amber => "Ambar" };
}

pub const Palette = struct {
    canvas: Color,
    surface: Color,
    elevated: Color,
    header: Color,
    row_alt: Color,
    border: Color,
    text: Color,
    muted: Color,
    accent: Color,
    accent_soft: Color,
    accent_text: Color,
    on_accent: Color,
    /// Semantic colors are intentionally distinct from the selected brand accent.
    positive: Color,
    negative: Color,
    warning: Color,
};

pub fn accentColor(mode: Mode, accent: Accent) Color {
    if (mode == .contrast) return switch (accent) {
        .lavender => .{ .r = 220, .g = 205, .b = 255 },
        .coral => .{ .r = 255, .g = 195, .b = 195 },
        .mint => .{ .r = 158, .g = 255, .b = 224 },
        .sky => .{ .r = 158, .g = 220, .b = 255 },
        .amber => .{ .r = 255, .g = 226, .b = 152 },
    };
    return switch (accent) {
        .lavender => .{ .r = 191, .g = 179, .b = 255 },
        .coral => .{ .r = 255, .g = 163, .b = 171 },
        .mint => .{ .r = 131, .g = 222, .b = 199 },
        .sky => .{ .r = 143, .g = 203, .b = 241 },
        .amber => .{ .r = 243, .g = 194, .b = 142 },
    };
}

/// Darker emphasis colors for text on the light surface (not pastel fills).
pub fn accentInk(accent: Accent) Color {
    return switch (accent) {
        .lavender => .{ .r = 89, .g = 53, .b = 154 },
        .coral => .{ .r = 146, .g = 41, .b = 62 },
        .mint => .{ .r = 9, .g = 102, .b = 76 },
        .sky => .{ .r = 23, .g = 84, .b = 143 },
        .amber => .{ .r = 124, .g = 77, .b = 18 },
    };
}

/// Alpha-blend a selected accent into a base surface (fixed-point, 0..256).
fn mix(base: Color, tint: Color, comptime tint_weight: u16) Color {
    const base_weight: u16 = 256 - tint_weight;
    return .{
        .r = @intCast((@as(u16, base.r) * base_weight + @as(u16, tint.r) * tint_weight) / 256),
        .g = @intCast((@as(u16, base.g) * base_weight + @as(u16, tint.g) * tint_weight) / 256),
        .b = @intCast((@as(u16, base.b) * base_weight + @as(u16, tint.b) * tint_weight) / 256),
    };
}

pub fn palette(appearance: Appearance) Palette {
    const selected = accentColor(appearance.mode, appearance.accent);
    return switch (appearance.mode) {
        .graphite => .{
            .canvas = .{ .r = 17, .g = 17, .b = 19 },
            .surface = .{ .r = 25, .g = 25, .b = 28 },
            .elevated = .{ .r = 32, .g = 32, .b = 36 },
            .header = .{ .r = 37, .g = 37, .b = 42 },
            .row_alt = .{ .r = 29, .g = 29, .b = 33 },
            .border = .{ .r = 67, .g = 67, .b = 76 },
            .text = .{ .r = 239, .g = 239, .b = 244 },
            .muted = .{ .r = 174, .g = 174, .b = 186 },
            .accent = selected,
            .accent_soft = mix(.{ .r = 32, .g = 32, .b = 36 }, selected, 48),
            .accent_text = selected,
            .on_accent = .{ .r = 17, .g = 17, .b = 19 },
            .positive = accentColor(.graphite, .mint),
            .negative = accentColor(.graphite, .coral),
            .warning = accentColor(.graphite, .amber),
        },
        .light => .{
            .canvas = .{ .r = 247, .g = 248, .b = 251 },
            .surface = .{ .r = 255, .g = 255, .b = 255 },
            .elevated = .{ .r = 239, .g = 240, .b = 245 },
            .header = .{ .r = 231, .g = 233, .b = 240 },
            .row_alt = .{ .r = 249, .g = 250, .b = 253 },
            .border = .{ .r = 201, .g = 205, .b = 216 },
            .text = .{ .r = 32, .g = 34, .b = 43 },
            .muted = .{ .r = 90, .g = 95, .b = 111 },
            .accent = selected,
            .accent_soft = mix(.{ .r = 255, .g = 255, .b = 255 }, selected, 76),
            .accent_text = accentInk(appearance.accent),
            .on_accent = .{ .r = 17, .g = 17, .b = 19 },
            .positive = .{ .r = 16, .g = 111, .b = 81 },
            .negative = .{ .r = 176, .g = 45, .b = 63 },
            .warning = .{ .r = 142, .g = 86, .b = 23 },
        },
        .contrast => .{
            .canvas = .{ .r = 0, .g = 0, .b = 0 },
            .surface = .{ .r = 6, .g = 6, .b = 6 },
            .elevated = .{ .r = 25, .g = 25, .b = 25 },
            .header = .{ .r = 34, .g = 34, .b = 34 },
            .row_alt = .{ .r = 15, .g = 15, .b = 15 },
            .border = .{ .r = 211, .g = 211, .b = 211 },
            .text = .{ .r = 255, .g = 255, .b = 255 },
            .muted = .{ .r = 230, .g = 230, .b = 230 },
            .accent = selected,
            .accent_soft = mix(.{ .r = 25, .g = 25, .b = 25 }, selected, 64),
            .accent_text = selected,
            .on_accent = .{ .r = 0, .g = 0, .b = 0 },
            .positive = accentColor(.contrast, .mint),
            .negative = accentColor(.contrast, .coral),
            .warning = accentColor(.contrast, .amber),
        },
    };
}

pub const Spacing = struct { xs: f32, sm: f32, md: f32, lg: f32, xl: f32, cell_x: f32, cell_y: f32 };
pub fn spacing(density: Density) Spacing {
    return switch (density) {
        .comfortable => .{ .xs = 4, .sm = 8, .md = 12, .lg = 16, .xl = 24, .cell_x = 11, .cell_y = 7 },
        .compact => .{ .xs = 3, .sm = 6, .md = 9, .lg = 12, .xl = 18, .cell_x = 8, .cell_y = 4 },
    };
}

fn srgb(v: u8) f64 {
    const n: f64 = @as(f64, @floatFromInt(v)) / 255.0;
    return if (n <= 0.04045) n / 12.92 else std.math.pow(f64, (n + 0.055) / 1.055, 2.4);
}
fn luminance(c: Color) f64 { return 0.2126 * srgb(c.r) + 0.7152 * srgb(c.g) + 0.0722 * srgb(c.b); }
pub fn contrastRatio(a: Color, b: Color) f64 {
    const la = luminance(a);
    const lb = luminance(b);
    return (@max(la, lb) + 0.05) / (@min(la, lb) + 0.05);
}

test "multitheme tokens are internally contrasting" {
    for ([_]Mode{ .graphite, .light, .contrast }) |mode| {
        for ([_]Accent{ .lavender, .coral, .mint, .sky, .amber }) |accent| {
            const p = palette(.{ .mode = mode, .accent = accent });
            try std.testing.expect(contrastRatio(p.canvas, p.text) >= 7.0);
            try std.testing.expect(contrastRatio(p.surface, p.muted) >= 4.5);
            try std.testing.expect(contrastRatio(p.accent, p.on_accent) >= 4.5);
            try std.testing.expect(contrastRatio(p.surface, p.accent_text) >= 4.5);
        }
    }
}
test "state transitions and densities" {
    var a: Appearance = .{};
    a.cycleMode();
    try std.testing.expectEqual(Mode.light, a.mode);
    a.cycleMode();
    a.cycleMode();
    try std.testing.expectEqual(Mode.graphite, a.mode);
    a.cycleAccent();
    try std.testing.expectEqual(Accent.coral, a.accent);
    a.toggleDensity();
    try std.testing.expectEqual(Density.comfortable, a.density);
    a.toggleDensity();
    try std.testing.expectEqual(Density.compact, a.density);
    try std.testing.expect(spacing(.compact).cell_y < spacing(.comfortable).cell_y);
}
