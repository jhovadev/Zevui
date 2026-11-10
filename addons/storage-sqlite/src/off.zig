//! Explicit OFF provider: always compilable without sqlite3 headers or libc.
const std = @import("std");
// Match the native provider error vocabulary; existing callers can switch modes.
pub const Error = error{
    OpenFailed, Closed, Busy, Locked, ReadOnly, Constraint, Corrupt,
    SqliteFailure, TooLarge, EmptyStatement, Unsupported,
};
pub const Capabilities = struct {
    persistent: bool = false,
    atomic_write: bool = false,
    transactions: bool = false,
    concurrent_readers: bool = false,
    preserves_comments: bool = false,
};
pub const capabilities: Capabilities = .{};
pub const Step = enum { row, done };
pub const Database = struct {
    pub fn open(_: [:0]const u8) Error!Database { return error.Unsupported; }
    pub fn close(_: *Database) Error!void { return error.Unsupported; }
    pub fn exec(_: *Database, _: [:0]const u8) Error!void { return error.Unsupported; }
    pub fn prepare(_: *Database, _: []const u8) Error!Statement { return error.Unsupported; }
    pub fn enableWal(_: *Database) Error!void { return error.Unsupported; }
    pub fn begin(_: *Database) Error!void { return error.Unsupported; }
    pub fn commit(_: *Database) Error!void { return error.Unsupported; }
    pub fn rollback(_: *Database) Error!void { return error.Unsupported; }
};
pub const Statement = struct {
    pub fn deinit(_: *Statement) void {}
    pub fn bindText(_: *Statement, _: c_int, _: []const u8) Error!void { return error.Unsupported; }
    pub fn bindBlob(_: *Statement, _: c_int, _: []const u8) Error!void { return error.Unsupported; }
    pub fn bindInt64(_: *Statement, _: c_int, _: i64) Error!void { return error.Unsupported; }
    pub fn next(_: *Statement) Error!Step { return error.Unsupported; }
    pub fn reset(_: *Statement) Error!void { return error.Unsupported; }
    pub fn columnText(_: *Statement, _: c_int) Error!?[]const u8 { return error.Unsupported; }
    pub fn columnBlob(_: *Statement, _: c_int) Error!?[]const u8 { return error.Unsupported; }
    pub fn columnInt64(_: *Statement, _: c_int) Error!i64 { return error.Unsupported; }
};
pub const KeyValue = struct {
    pub fn init(_: *Database) Error!KeyValue { return error.Unsupported; }
    pub fn put(_: *KeyValue, _: []const u8, _: []const u8) Error!void { return error.Unsupported; }
    pub fn get(_: *KeyValue, _: std.mem.Allocator, _: []const u8) (Error || std.mem.Allocator.Error)!?[]u8 { return error.Unsupported; }
    pub fn remove(_: *KeyValue, _: []const u8) Error!bool { return error.Unsupported; }
};
test "off mode has no native SQLite requirement" {
    try std.testing.expect(!capabilities.persistent);
    try std.testing.expectError(error.Unsupported, Database.open(":memory:"));
}
