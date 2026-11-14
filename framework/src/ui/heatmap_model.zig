//! Renderer-independent activity heatmap math. This is intentionally pure Zig.
const std = @import("std");

pub const days_per_week: usize = 7;
pub const levels: usize = 5;

/// Zero is always empty; nonzero values are distributed over levels 1..4.
/// The u64 intermediate prevents overflow for large u32 activity counts.
pub fn intensity(value: u32, max_value: u32) u3 {
    if (value == 0 or max_value == 0) return 0;
    const numerator = @as(u64, value) * 4 + @as(u64, max_value) - 1;
    const scaled = numerator / @as(u64, max_value);
    return @intCast(@min(scaled, 4));
}

pub fn maximum(counts: []const u32) u32 {
    var result: u32 = 0;
    for (counts) |count| result = @max(result, count);
    return result;
}

pub fn total(counts: []const u32) u64 {
    var result: u64 = 0;
    for (counts) |count| result += count;
    return result;
}

pub fn validWeeks(counts: []const u32) bool {
    return counts.len > 0 and counts.len % days_per_week == 0;
}

pub fn at(counts: []const u32, week: usize, weekday: usize) ?u32 {
    if (weekday >= days_per_week) return null;
    if (week >= counts.len / days_per_week) return null;
    return counts[week * days_per_week + weekday];
}

test "empty and low activity" {
    try std.testing.expectEqual(@as(u3, 0), intensity(0, 100));
    try std.testing.expectEqual(@as(u3, 0), intensity(8, 0));
    try std.testing.expectEqual(@as(u3, 1), intensity(1, 100));
    try std.testing.expectEqual(@as(u3, 2), intensity(26, 100));
    try std.testing.expectEqual(@as(u3, 4), intensity(100, 100));
}

test "large values never overflow" {
    const max = std.math.maxInt(u32);
    try std.testing.expectEqual(@as(u3, 4), intensity(max, max));
    try std.testing.expectEqual(@as(u3, 1), intensity(1, max));
}

test "week alignment and aggregates" {
    const values = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 };
    try std.testing.expect(validWeeks(&values));
    try std.testing.expect(!validWeeks(values[0..13]));
    try std.testing.expectEqual(@as(u32, 13), maximum(&values));
    try std.testing.expectEqual(@as(u64, 91), total(&values));
    try std.testing.expectEqual(@as(?u32, 7), at(&values, 1, 0));
    try std.testing.expectEqual(@as(?u32, null), at(&values, 2, 0));
    try std.testing.expectEqual(@as(?u32, null), at(&values, 0, 7));
}
