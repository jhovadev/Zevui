//! Zevui addon: bounded volatile key/value settings without allocation.
//! Stable memory ownership, explicit size limits. Not persistent or thread-safe.
const std = @import("std");

pub fn MemoryStore(comptime capacity: usize, comptime key_max: usize, comptime value_max: usize) type {
    return struct {
        const Self = @This();
        const Entry = struct {
            used: bool = false,
            key_len: usize = 0,
            val_len: usize = 0,
            key: [key_max]u8 = undefined,
            val: [value_max]u8 = undefined,
        };
        entries: [capacity]Entry = [_]Entry{.{}} ** capacity,
        pub const Error = error{ KeyTooLarge, ValueTooLarge, Full };

        fn find(self: *const Self, key: []const u8) ?usize {
            for (&self.entries, 0..) |*entry, i| {
                if (entry.used and std.mem.eql(u8, entry.key[0..entry.key_len], key)) return i;
            }
            return null;
        }
        pub fn get(self: *const Self, key: []const u8) ?[]const u8 {
            const i = self.find(key) orelse return null;
            return self.entries[i].val[0..self.entries[i].val_len];
        }
        pub fn put(self: *Self, key: []const u8, value: []const u8) Error!void {
            if (key.len > key_max) return error.KeyTooLarge;
            if (value.len > value_max) return error.ValueTooLarge;
            const i = self.find(key) orelse blk: {
                for (&self.entries, 0..) |*entry, j| {
                    if (!entry.used) break :blk j;
                }
                return error.Full;
            };
            const entry = &self.entries[i];
            @memcpy(entry.key[0..key.len], key);
            @memcpy(entry.val[0..value.len], value);
            entry.key_len = key.len;
            entry.val_len = value.len;
            entry.used = true;
        }
        pub fn remove(self: *Self, key: []const u8) bool {
            const i = self.find(key) orelse return false;
            self.entries[i].used = false;
            return true;
        }
        pub fn count(self: *const Self) usize {
            var n: usize = 0;
            for (self.entries) |e| {
                if (e.used) n += 1;
            }
            return n;
        }
    };
}

test "memory store owns data and supports replacement and removal" {
    var s: MemoryStore(2, 16, 64) = .{};
    var value = [_]u8{ 'o', 'n' };
    try s.put("theme", &value);
    value[0] = 'X';
    try std.testing.expectEqualStrings("on", s.get("theme").?);
    try s.put("theme", "off");
    try std.testing.expectEqualStrings("off", s.get("theme").?);
    try s.put("other", "123");
    try std.testing.expectError(error.Full, s.put("third", "3"));
    try std.testing.expect(s.remove("theme"));
    try std.testing.expect(s.get("theme") == null);
    try std.testing.expectEqual(@as(usize, 1), s.count());
}
