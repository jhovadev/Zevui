//! Pure Gregorian calendar: no DVUI, locale, timezone or allocator dependency.
const std = @import("std");

pub const Date = struct {
    year: u16,
    month: u8,
    day: u8,

    pub fn valid(self: Date) bool {
        return self.year >= 1 and self.year <= 9999 and self.month >= 1 and self.month <= 12 and
            self.day >= 1 and self.day <= daysInMonth(self.year, self.month);
    }
};

pub const Month = struct { year: u16, month: u8 };

pub fn leap(year: u16) bool {
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0);
}

pub fn daysInMonth(year: u16, month: u8) u8 {
    if (year < 1 or year > 9999) return 0;
    return switch (month) {
        1, 3, 5, 7, 8, 10, 12 => 31,
        4, 6, 9, 11 => 30,
        2 => if (leap(year)) 29 else 28,
        else => 0,
    };
}

/// Monday=0..Sunday=6, null for invalid dates. Sakamoto's algorithm.
pub fn weekday(date: Date) ?u3 {
    if (!date.valid()) return null;
    const offsets = [_]u8{ 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 };
    const y: u32 = @as(u32, date.year) - @as(u32, if (date.month < 3) @as(u32, 1) else 0);
    const sunday0 = (y + y / 4 - y / 100 + y / 400 + offsets[date.month - 1] + date.day) % 7;
    return @intCast((sunday0 + 6) % 7);
}

/// Grid position 0 is Monday on the first visible week. null means padding.
pub fn cell(month: Month, index: usize) ?Date {
    if (index >= 42) return null;
    const offset = weekday(.{ .year = month.year, .month = month.month, .day = 1 }) orelse return null;
    if (index < offset) return null;
    const day = index - offset + 1;
    if (day > daysInMonth(month.year, month.month)) return null;
    return .{ .year = month.year, .month = month.month, .day = @intCast(day) };
}

pub fn shift(month: Month, delta: i8) ?Month {
    if (month.year < 1 or month.year > 9999 or month.month < 1 or month.month > 12) return null;
    const ordinal = (@as(i32, month.year) - 1) * 12 + @as(i32, month.month) - 1 + @as(i32, delta);
    if (ordinal < 0 or ordinal >= 9999 * 12) return null;
    return .{ .year = @intCast(@divTrunc(ordinal, 12) + 1), .month = @intCast(@mod(ordinal, 12) + 1) };
}

pub const month_names = [_][]const u8{ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };
pub const day_names = [_][]const u8{ "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" };

test "Gregorian leap rules and invalid boundaries" {
    try std.testing.expect(leap(2000));
    try std.testing.expect(!leap(1900));
    try std.testing.expect(leap(2024));
    try std.testing.expectEqual(@as(u8, 29), daysInMonth(2024, 2));
    try std.testing.expectEqual(@as(u8, 28), daysInMonth(2026, 2));
    try std.testing.expect(!(Date{ .year = 2026, .month = 2, .day = 29 }).valid());
    try std.testing.expect(!(Date{ .year = 0, .month = 1, .day = 1 }).valid());
    try std.testing.expect(!(Date{ .year = 2026, .month = 13, .day = 1 }).valid());
}

test "weekday grid anchored on monday" {
    try std.testing.expectEqual(@as(?u3, 0), weekday(.{ .year = 2024, .month = 1, .day = 1 }));
    try std.testing.expectEqual(@as(?u3, 5), weekday(.{ .year = 2026, .month = 11, .day = 14 }));
    try std.testing.expectEqual(@as(?Date, null), cell(.{ .year = 2026, .month = 11 }, 0));
    try std.testing.expectEqual(@as(u8, 1), cell(.{ .year = 2026, .month = 11 }, 6).?.day);
    try std.testing.expectEqual(@as(u8, 30), cell(.{ .year = 2026, .month = 11 }, 35).?.day);
    try std.testing.expectEqual(@as(?Date, null), cell(.{ .year = 2026, .month = 11 }, 36));
}

test "year transitions and limits" {
    try std.testing.expectEqual(Month{ .year = 2027, .month = 1 }, shift(.{ .year = 2026, .month = 12 }, 1).?);
    try std.testing.expectEqual(Month{ .year = 2025, .month = 12 }, shift(.{ .year = 2026, .month = 1 }, -1).?);
    try std.testing.expectEqual(@as(?Month, null), shift(.{ .year = 1, .month = 1 }, -1));
    try std.testing.expectEqual(@as(?Month, null), shift(.{ .year = 9999, .month = 12 }, 1));
}
