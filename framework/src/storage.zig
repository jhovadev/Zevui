//! Portable storage capability contract, not a storage implementation.
//! Backends (memory, JSON, SQLite) will be separate addons in F4/F6.

pub const Capabilities = struct {
    persistent: bool = false,
    atomic_write: bool = false,
    transactions: bool = false,
    concurrent_readers: bool = false,
    preserves_comments: bool = false,
};

pub const StoreError = error{
    KeyNotFound,
    InvalidKey,
    ReadOnly,
    CorruptData,
    IoFailure,
    UnsupportedOperation,
};

/// Borrowed view; actual ownership semantics are backend-specific until F4.
pub const Entry = struct {
    key: []const u8,
    value: []const u8,
};

test "capabilities default to unsupported" {
    const std = @import("std");
    const caps: Capabilities = .{};
    try std.testing.expect(!caps.persistent and !caps.transactions);
    try std.testing.expect(!caps.atomic_write and !caps.concurrent_readers);
}
