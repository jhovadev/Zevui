//! Small SQLite3 C ABI wrapper. No removed Zig C-header builtin or unsafe SQL formatting.
//! The extern declarations mirror the stable, documented sqlite3.h ABI.
//! Every Database and Statement is single-owner; close/finalize explicitly.
const std = @import("std");

const CDb = opaque {};
const CStmt = opaque {};
const Destructor = ?*const fn (?*anyopaque) callconv(.c) void;
const SQLITE_OK = 0;
const SQLITE_ROW = 100;
const SQLITE_DONE = 101;
const SQLITE_NULL = 5;
const OPEN_READWRITE = 0x00000002;
const OPEN_CREATE = 0x00000004;
const OPEN_FULLMUTEX = 0x00010000;

extern "c" fn sqlite3_open_v2([*:0]const u8, *?*CDb, c_int, ?[*:0]const u8) c_int;
extern "c" fn sqlite3_close(*CDb) c_int;
extern "c" fn sqlite3_exec(*CDb, [*:0]const u8, ?*const fn (?*anyopaque, c_int, [*c][*c]u8, [*c][*c]u8) callconv(.c) c_int, ?*anyopaque, ?*?[*:0]u8) c_int;
extern "c" fn sqlite3_prepare_v2(*CDb, [*]const u8, c_int, *?*CStmt, ?*?[*]const u8) c_int;
extern "c" fn sqlite3_finalize(*CStmt) c_int;
extern "c" fn sqlite3_reset(*CStmt) c_int;
extern "c" fn sqlite3_clear_bindings(*CStmt) c_int;
extern "c" fn sqlite3_step(*CStmt) c_int;
extern "c" fn sqlite3_bind_text(*CStmt, c_int, [*]const u8, c_int, Destructor) c_int;
extern "c" fn sqlite3_bind_blob(*CStmt, c_int, [*]const u8, c_int, Destructor) c_int;
extern "c" fn sqlite3_bind_int64(*CStmt, c_int, i64) c_int;
extern "c" fn sqlite3_column_type(*CStmt, c_int) c_int;
extern "c" fn sqlite3_column_text(*CStmt, c_int) ?[*]const u8;
extern "c" fn sqlite3_column_blob(*CStmt, c_int) ?*const anyopaque;
extern "c" fn sqlite3_column_bytes(*CStmt, c_int) c_int;
extern "c" fn sqlite3_column_int64(*CStmt, c_int) i64;
extern "c" fn sqlite3_changes(*CDb) c_int;

pub const Error = error{
    OpenFailed, Closed, Busy, Locked, ReadOnly, Constraint, Corrupt,
    SqliteFailure, TooLarge, EmptyStatement, Unsupported,
};
pub const Capabilities = struct {
    persistent: bool = true,
    atomic_write: bool = true,
    transactions: bool = true,
    concurrent_readers: bool = true,
    preserves_comments: bool = false,
};
pub const capabilities: Capabilities = .{};

fn checked(rc: c_int) Error!void {
    if (rc == SQLITE_OK) return;
    return switch (rc & 0xff) {
        5 => error.Busy, 6 => error.Locked, 8 => error.ReadOnly,
        11 => error.Corrupt, 19 => error.Constraint,
        else => error.SqliteFailure,
    };
}
fn checkedLen(n: usize) Error!c_int {
    if (n > std.math.maxInt(c_int)) return error.TooLarge;
    return @intCast(n);
}
// SQLite's documented SQLITE_TRANSIENT destructor sentinel means copy on bind.
fn transient() Destructor {
    return @ptrFromInt(std.math.maxInt(usize));
}

pub const Database = struct {
    handle: ?*CDb,

    pub fn open(path: [:0]const u8) Error!Database {
        var ptr: ?*CDb = null;
        const rc = sqlite3_open_v2(path.ptr, &ptr, OPEN_READWRITE | OPEN_CREATE | OPEN_FULLMUTEX, null);
        if (rc != SQLITE_OK) {
            if (ptr) |p| _ = sqlite3_close(p);
            return error.OpenFailed;
        }
        return .{ .handle = ptr orelse return error.OpenFailed };
    }
    fn required(self: *Database) Error!*CDb {
        return self.handle orelse return error.Closed;
    }
    pub fn close(self: *Database) Error!void {
        const ptr = try self.required();
        try checked(sqlite3_close(ptr)); // BUSY if a Statement is still live.
        self.handle = null;
    }
    /// Raw, fixed SQL only. For user input, always use prepare() + bound params.
    pub fn exec(self: *Database, sql: [:0]const u8) Error!void {
        try checked(sqlite3_exec(try self.required(), sql.ptr, null, null, null));
    }
    pub fn prepare(self: *Database, sql: []const u8) Error!Statement {
        var stmt: ?*CStmt = null;
        try checked(sqlite3_prepare_v2(try self.required(), sql.ptr, try checkedLen(sql.len), &stmt, null));
        return .{ .db = self, .handle = stmt orelse return error.EmptyStatement };
    }
    /// WAL is appropriate for on-disk storage, not shared/network filesystems.
    pub fn enableWal(self: *Database) Error!void {
        try self.exec("PRAGMA journal_mode=WAL;");
    }
    pub fn begin(self: *Database) Error!void { try self.exec("BEGIN IMMEDIATE;"); }
    pub fn commit(self: *Database) Error!void { try self.exec("COMMIT;"); }
    pub fn rollback(self: *Database) Error!void { try self.exec("ROLLBACK;"); }
};

pub const Step = enum { row, done };
pub const Statement = struct {
    db: *Database,
    handle: ?*CStmt,
    fn required(self: *Statement) Error!*CStmt {
        return self.handle orelse return error.Closed;
    }
    pub fn deinit(self: *Statement) void {
        if (self.handle) |p| { _ = sqlite3_finalize(p); self.handle = null; }
    }
    pub fn bindText(self: *Statement, index: c_int, text: []const u8) Error!void {
        try checked(sqlite3_bind_text(try self.required(), index, text.ptr, try checkedLen(text.len), transient()));
    }
    pub fn bindBlob(self: *Statement, index: c_int, data: []const u8) Error!void {
        const ptr: [*]const u8 = if (data.len == 0) "".ptr else data.ptr;
        try checked(sqlite3_bind_blob(try self.required(), index, ptr, try checkedLen(data.len), transient()));
    }
    pub fn bindInt64(self: *Statement, index: c_int, value: i64) Error!void {
        try checked(sqlite3_bind_int64(try self.required(), index, value));
    }
    pub fn next(self: *Statement) Error!Step {
        const rc = sqlite3_step(try self.required());
        return switch (rc) {
            SQLITE_ROW => .row, SQLITE_DONE => .done,
            else => { try checked(rc); return error.SqliteFailure; },
        };
    }
    pub fn reset(self: *Statement) Error!void {
        try checked(sqlite3_reset(try self.required()));
        try checked(sqlite3_clear_bindings(try self.required()));
    }
    /// Borrowed until next step/reset/finalize. NULL is distinct from zero length.
    pub fn columnText(self: *Statement, index: c_int) Error!?[]const u8 {
        const p = try self.required();
        if (sqlite3_column_type(p, index) == SQLITE_NULL) return null;
        const bytes = sqlite3_column_text(p, index) orelse return error.SqliteFailure;
        const n: usize = @intCast(sqlite3_column_bytes(p, index));
        return bytes[0..n];
    }
    /// Borrowed until next step/reset/finalize; copy before keeping it.
    pub fn columnBlob(self: *Statement, index: c_int) Error!?[]const u8 {
        const p = try self.required();
        if (sqlite3_column_type(p, index) == SQLITE_NULL) return null;
        const n: usize = @intCast(sqlite3_column_bytes(p, index));
        if (n == 0) return &.{};
        const blob = sqlite3_column_blob(p, index) orelse return error.SqliteFailure;
        const bytes: [*]const u8 = @ptrCast(blob);
        return bytes[0..n];
    }
    pub fn columnInt64(self: *Statement, index: c_int) Error!i64 {
        return sqlite3_column_int64(try self.required(), index);
    }
};

/// Minimal persistent KV adapter; get() returns memory owned by the caller.
pub const KeyValue = struct {
    db: *Database,
    pub fn init(db: *Database) Error!KeyValue {
        try db.exec("CREATE TABLE IF NOT EXISTS zevui_kv (k TEXT PRIMARY KEY NOT NULL, v BLOB NOT NULL) WITHOUT ROWID;");
        return .{ .db = db };
    }
    pub fn put(self: *KeyValue, key: []const u8, value: []const u8) Error!void {
        var stmt = try self.db.prepare("INSERT INTO zevui_kv(k, v) VALUES(?1, ?2) ON CONFLICT(k) DO UPDATE SET v=excluded.v;");
        defer stmt.deinit();
        try stmt.bindText(1, key);
        try stmt.bindBlob(2, value);
        if (try stmt.next() != .done) return error.SqliteFailure;
    }
    pub fn get(self: *KeyValue, allocator: std.mem.Allocator, key: []const u8) (Error || std.mem.Allocator.Error)!?[]u8 {
        var stmt = try self.db.prepare("SELECT v FROM zevui_kv WHERE k = ?1;");
        defer stmt.deinit();
        try stmt.bindText(1, key);
        if (try stmt.next() == .done) return null;
        const data = (try stmt.columnBlob(0)) orelse return error.Corrupt;
        return try allocator.dupe(u8, data);
    }
    pub fn remove(self: *KeyValue, key: []const u8) Error!bool {
        var stmt = try self.db.prepare("DELETE FROM zevui_kv WHERE k = ?1;");
        defer stmt.deinit();
        try stmt.bindText(1, key);
        if (try stmt.next() != .done) return error.SqliteFailure;
        return sqlite3_changes(try self.db.required()) > 0;
    }
};

test "sqlite prepared statements and owned blobs" {
    var db = try Database.open(":memory:");
    defer db.close() catch {};
    var kv = try KeyValue.init(&db);
    const key = "a' OR 1=1 --";
    try kv.put(key, &.{ 0, 1, 2, 0xff });
    const actual = (try kv.get(std.testing.allocator, key)).?;
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 2, 0xff }, actual);
    try std.testing.expect((try kv.get(std.testing.allocator, "missing")) == null);
    try kv.put("empty", "");
    const empty = (try kv.get(std.testing.allocator, "empty")).?;
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
    try std.testing.expect(try kv.remove(key));
    try std.testing.expect(!(try kv.remove(key)));
}

test "transaction rollback and statement lifetime" {
    var db = try Database.open(":memory:");
    defer db.close() catch {};
    var kv = try KeyValue.init(&db);
    try db.begin();
    try kv.put("temp", "value");
    try db.rollback();
    try std.testing.expect((try kv.get(std.testing.allocator, "temp")) == null);
    var stmt = try db.prepare("SELECT ?1;");
    try std.testing.expectError(error.Busy, db.close());
    try stmt.bindInt64(1, 42);
    try std.testing.expectEqual(Step.row, try stmt.next());
    try std.testing.expectEqual(@as(i64, 42), try stmt.columnInt64(0));
    stmt.deinit();
    try db.close();
    try std.testing.expectError(error.Closed, db.exec("SELECT 1;"));
}
