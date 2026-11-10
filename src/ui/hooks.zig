//! Explicit state helpers inspired by hooks, but with Zig immediate-mode rules:
//! no invisible lifecycle, no implicit allocation, no global hook registry.
const tokens = @import("tokens.zig");

pub const ThemeHandle = struct {
    state: *tokens.Appearance,
    pub fn current(self: ThemeHandle) tokens.Palette { return tokens.palette(self.state.*); }
    pub fn cycle(self: ThemeHandle) void { self.state.cycleMode(); }
    pub fn nextAccent(self: ThemeHandle) void { self.state.cycleAccent(); }
    pub fn toggleDensity(self: ThemeHandle) void { self.state.toggleDensity(); }
};
pub fn useTheme(appearance: *tokens.Appearance) ThemeHandle { return .{ .state = appearance }; }

pub const Disclosure = struct {
    state: *bool,
    pub fn toggle(self: Disclosure) void { self.state.* = !self.state.*; }
    pub fn close(self: Disclosure) void { self.state.* = false; }
    pub fn isOpen(self: Disclosure) bool { return self.state.*; }
};
pub fn useDisclosure(state: *bool) Disclosure { return .{ .state = state }; }

test "explicit hooks change only provided state" {
    const std = @import("std");
    var appearance: tokens.Appearance = .{};
    const theme = useTheme(&appearance);
    theme.cycle();
    try std.testing.expectEqual(tokens.Mode.light, appearance.mode);
    var show = false;
    const panel = useDisclosure(&show);
    panel.toggle();
    try std.testing.expect(panel.isOpen());
    panel.close();
    try std.testing.expect(!show);
}
