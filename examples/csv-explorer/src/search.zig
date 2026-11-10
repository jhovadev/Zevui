//! Bounded, cancellable CSV filtering and incremental stable mergesort.
//! No DVUI dependency: `zig test src/search.zig`.
const std = @import("std");
const csv = @import("csv.zig");
const Allocator = std.mem.Allocator;

pub const page_size: usize = 500;
pub const scan_budget: usize = 8192;
pub const sort_budget: usize = 32768;

pub const Predicate = enum { contains, equals, starts_with, greater, less, empty, not_empty };
pub const SortOrder = enum { asc, desc };

pub const Filter = struct {
    // Empty text/search/predicate/sort: no index allocation, direct row access.
    matches: std.ArrayList(usize) = .empty,
    scratch: std.ArrayList(usize) = .empty,
    // Indexed by original CSV row; avoids repeated float parsing in mergesort.
    numeric_keys: std.ArrayList(?f64) = .empty,
    query: std.ArrayList(u8) = .empty,
    predicate_text: std.ArrayList(u8) = .empty,
    search_column: ?usize = null,
    predicate_column: ?usize = null,
    predicate: Predicate = .contains,
    sort_column: ?usize = null,
    sort_order: SortOrder = .asc,
    scanned: usize = 0,
    complete: bool = true,
    generation: usize = 0,
    // Bottom-up merge sort state (each advance is work-budget limited).
    sort_width: usize = 1,
    sort_run: usize = 0,
    sort_out: usize = 0,
    sort_left: usize = 0,
    sort_right: usize = 0,
    sorting: bool = false,

    pub fn deinit(self: *Filter, a: Allocator) void {
        self.matches.deinit(a);
        self.scratch.deinit(a);
        self.numeric_keys.deinit(a);
        self.query.deinit(a);
        self.predicate_text.deinit(a);
        self.* = .{};
    }

    pub fn clearCriteria(self: *Filter) void {
        self.query.clearRetainingCapacity();
        self.predicate_text.clearRetainingCapacity();
        self.search_column = null;
        self.predicate_column = null;
        self.predicate = .contains;
        self.sort_column = null;
        self.sort_order = .asc;
        self.reset();
    }

    pub fn isDirect(self: *const Filter) bool {
        return self.query.items.len == 0 and self.predicate_column == null and self.sort_column == null;
    }

    pub fn reset(self: *Filter) void {
        self.matches.clearRetainingCapacity();
        self.numeric_keys.clearRetainingCapacity();
        self.scanned = 0;
        self.sorting = false;
        self.sort_width = 1;
        self.sort_run = 0;
        self.sort_out = 0;
        self.sort_left = 0;
        self.sort_right = 0;
        self.complete = self.isDirect();
        self.generation +%= 1;
    }

    pub fn setQuery(self: *Filter, a: Allocator, value: []const u8) !bool {
        if (std.mem.eql(u8, self.query.items, value)) return false;
        var next: std.ArrayList(u8) = .empty;
        errdefer next.deinit(a);
        try next.appendSlice(a, value);
        self.query.deinit(a);
        self.query = next;
        self.reset();
        return true;
    }

    pub fn setScope(self: *Filter, column: ?usize) bool {
        if (self.search_column == column) return false;
        self.search_column = column;
        if (self.query.items.len != 0) self.reset();
        return true;
    }

    /// A single column predicate, combined with the global search via AND.
    /// Empty/not-empty ignore the text; other operators require a nonempty value.
    pub fn setPredicate(self: *Filter, a: Allocator, column: ?usize, op: Predicate, value: []const u8) !bool {
        const active_column: ?usize = if (op == .empty or op == .not_empty or value.len != 0) column else null;
        if (self.predicate_column == active_column and self.predicate == op and
            std.mem.eql(u8, self.predicate_text.items, value)) return false;
        var next: std.ArrayList(u8) = .empty;
        errdefer next.deinit(a);
        try next.appendSlice(a, value);
        self.predicate_text.deinit(a);
        self.predicate_text = next;
        self.predicate_column = active_column;
        self.predicate = op;
        self.reset();
        return true;
    }

    pub fn setSort(self: *Filter, column: ?usize, order: SortOrder) bool {
        if (self.sort_column == column and self.sort_order == order) return false;
        self.sort_column = column;
        self.sort_order = order;
        self.reset();
        return true;
    }

    fn cell(row: csv.Row, col: usize) []const u8 {
        return if (col < row.cells.len) row.cells[col] else "";
    }

    pub fn rowMatches(self: *const Filter, row: csv.Row) bool {
        if (self.query.items.len != 0) {
            if (self.search_column) |column| {
                if (!containsIgnoreCase(cell(row, column), self.query.items)) return false;
            } else if (!csv.rowContains(row, self.query.items)) return false;
        }
        const column = self.predicate_column orelse return true;
        const value = cell(row, column);
        const needle = self.predicate_text.items;
        return switch (self.predicate) {
            .contains => containsIgnoreCase(value, needle),
            .equals => std.ascii.eqlIgnoreCase(value, needle),
            .starts_with => startsIgnoreCase(value, needle),
            .empty => value.len == 0,
            .not_empty => value.len != 0,
            .greater, .less => blk: {
                const lhs = std.fmt.parseFloat(f64, std.mem.trim(u8, value, " \t")) catch break :blk false;
                const rhs = std.fmt.parseFloat(f64, std.mem.trim(u8, needle, " \t")) catch break :blk false;
                break :blk if (self.predicate == .greater) lhs > rhs else lhs < rhs;
            },
        };
    }

    fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
        if (needle.len == 0) return true;
        if (haystack.len < needle.len) return false;
        for (0..haystack.len - needle.len + 1) |index| {
            if (std.ascii.eqlIgnoreCase(haystack[index..][0..needle.len], needle)) return true;
        }
        return false;
    }

    fn startsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
        return haystack.len >= needle.len and std.ascii.eqlIgnoreCase(haystack[0..needle.len], needle);
    }

    fn compareAsciiIgnoreCase(lhs: []const u8, rhs: []const u8) std.math.Order {
        for (0..@min(lhs.len, rhs.len)) |i| {
            const a = std.ascii.toLower(lhs[i]);
            const b = std.ascii.toLower(rhs[i]);
            if (a < b) return .lt;
            if (a > b) return .gt;
        }
        if (lhs.len < rhs.len) return .lt;
        if (lhs.len > rhs.len) return .gt;
        return .eq;
    }

    // Total order: numbers as numbers when both parse, text as case-folded ASCII,
    // empty values always last; original row index resolves ties stably.
    fn compare(self: *const Filter, rows: []const csv.Row, left: usize, right: usize) bool {
        const col = self.sort_column orelse return left < right;
        const lhs = cell(rows[left], col);
        const rhs = cell(rows[right], col);
        if (lhs.len == 0 or rhs.len == 0) {
            if (lhs.len == rhs.len) return left < right;
            return lhs.len != 0;
        }
        // Numeric and textual values form separate, deterministic classes.
        // Mixing numeric and lexicographic comparisons otherwise creates cycles.
        const lnum = self.numeric_keys.items[left];
        const rnum = self.numeric_keys.items[right];
        const lnumeric = lnum != null;
        const rnumeric = rnum != null;
        if (lnumeric != rnumeric) return lnumeric; // numeric before text, even descending
        var order: std.math.Order = .eq;
        if (lnumeric) {
            const l = lnum.?;
            const r = rnum.?;
            order = if (l < r) .lt else if (l > r) .gt else .eq;
        } else {
            order = compareAsciiIgnoreCase(lhs, rhs);
        }
        if (order == .eq) return left < right;
        return if (self.sort_order == .asc) order == .lt else order == .gt;
    }

    fn advanceSort(self: *Filter, a: Allocator, rows: []const csv.Row, budget: usize) !void {
        const n = self.matches.items.len;
        if (n < 2) {
            self.sorting = false;
            self.complete = true;
            return;
        }
        if (self.scratch.items.len != n) try self.scratch.resize(a, n);
        var remaining = budget;
        while (remaining > 0 and !self.complete) {
            if (self.sort_run >= n) {
                std.mem.swap(std.ArrayList(usize), &self.matches, &self.scratch);
                if (self.sort_width >= (n + 1) / 2) {
                    self.sorting = false;
                    self.complete = true;
                    break;
                }
                self.sort_width *= 2;
                self.sort_run = 0;
                self.sort_out = 0;
                self.sort_left = 0;
                self.sort_right = @min(n, self.sort_width);
                continue;
            }
            const mid = self.sort_run + @min(self.sort_width, n - self.sort_run);
            const end = mid + @min(self.sort_width, n - mid);
            if (self.sort_out == end) {
                self.sort_run = end;
                self.sort_out = end;
                self.sort_left = end;
                self.sort_right = end + @min(self.sort_width, n - end);
                continue;
            }
            const take_left = self.sort_left < mid and
                (self.sort_right >= end or !self.compare(rows, self.matches.items[self.sort_right], self.matches.items[self.sort_left]));
            if (take_left) {
                self.scratch.items[self.sort_out] = self.matches.items[self.sort_left];
                self.sort_left += 1;
            } else {
                self.scratch.items[self.sort_out] = self.matches.items[self.sort_right];
                self.sort_right += 1;
            }
            self.sort_out += 1;
            remaining -= 1;
        }
    }

    /// Processes at most `budget` source rows or sort output elements per call.
    pub fn advance(self: *Filter, a: Allocator, rows: []const csv.Row, budget: usize) !void {
        if (self.complete or budget == 0) return;
        if (!self.sorting) {
            const end = self.scanned + @min(budget, rows.len - self.scanned);
            for (self.scanned..end) |index| {
                if (self.sort_column) |column| {
                    const field = std.mem.trim(u8, cell(rows[index], column), " \t");
                    var numeric: ?f64 = std.fmt.parseFloat(f64, field) catch null;
                    if (numeric) |number| {
                        if (std.math.isNan(number)) numeric = null;
                    }
                    try self.numeric_keys.append(a, numeric);
                }
                if (self.rowMatches(rows[index])) try self.matches.append(a, index);
            }
            self.scanned = end;
            if (self.scanned != rows.len) return;
            if (self.sort_column == null) {
                self.complete = true;
                return;
            }
            self.sorting = true;
            self.sort_width = 1;
            self.sort_run = 0;
            self.sort_out = 0;
            self.sort_left = 0;
            self.sort_right = @min(self.matches.items.len, 1);
            return;
        }
        try self.advanceSort(a, rows, budget);
    }

    pub fn count(self: *const Filter, total: usize) usize {
        return if (self.isDirect()) total else self.matches.items.len;
    }

    pub fn rowIndex(self: *const Filter, visible: usize) usize {
        return if (self.isDirect()) visible else self.matches.items[visible];
    }

    pub fn pageCount(self: *const Filter, total: usize) usize {
        const n = self.count(total);
        return @max(1, n / page_size + @intFromBool(n % page_size != 0));
    }
};

test "direct path requires no index for 497156 rows" {
    var f: Filter = .{};
    defer f.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 497156), f.count(497156));
    try std.testing.expectEqual(@as(usize, 995), f.pageCount(497156));
    try std.testing.expectEqual(@as(usize, 400000), f.rowIndex(400000));
    try std.testing.expectEqual(@as(usize, 0), f.matches.items.len);
}

test "bounded incremental scan and cancellation" {
    var ds = try csv.Dataset.fromBytes(std.testing.allocator, "id,name\n1,Ada\n2,Ben\n3,ADAm\n4,Eve\n");
    defer ds.deinit();
    var f: Filter = .{};
    defer f.deinit(std.testing.allocator);
    try std.testing.expect(try f.setQuery(std.testing.allocator, "ada"));
    try f.advance(std.testing.allocator, ds.rows, 2);
    try std.testing.expectEqual(@as(usize, 2), f.scanned);
    try std.testing.expectEqual(@as(usize, 1), f.count(ds.rows.len));
    try std.testing.expect(!f.complete);
    try f.advance(std.testing.allocator, ds.rows, 2);
    try std.testing.expect(f.complete);
    try std.testing.expectEqual(@as(usize, 2), f.count(ds.rows.len));
    try std.testing.expectEqual(@as(usize, 2), f.rowIndex(1));
    try std.testing.expect(try f.setQuery(std.testing.allocator, "eve"));
    try std.testing.expectEqual(@as(usize, 0), f.scanned);
    try f.advance(std.testing.allocator, ds.rows, 8);
    try std.testing.expectEqual(@as(usize, 3), f.rowIndex(0));
    try std.testing.expect(try f.setQuery(std.testing.allocator, ""));
    try std.testing.expect(f.isDirect());
    try std.testing.expect(f.complete);
}

test "search only one column and combine with field predicate" {
    var ds = try csv.Dataset.fromBytes(std.testing.allocator, "id,name,price\n1,Ada,9\n2,Ben,20\n3,Ada,50\n");
    defer ds.deinit();
    var f: Filter = .{};
    defer f.deinit(std.testing.allocator);
    _ = try f.setQuery(std.testing.allocator, "ada");
    _ = f.setScope(1);
    _ = try f.setPredicate(std.testing.allocator, 2, .greater, "10");
    try f.advance(std.testing.allocator, ds.rows, 3);
    try std.testing.expectEqual(@as(usize, 1), f.count(ds.rows.len));
    try std.testing.expectEqual(@as(usize, 2), f.rowIndex(0));
    _ = f.setScope(0);
    try f.advance(std.testing.allocator, ds.rows, 3);
    try std.testing.expectEqual(@as(usize, 0), f.count(ds.rows.len));
}

test "empty and not empty predicates with short rows" {
    var ds = try csv.Dataset.fromBytes(std.testing.allocator, "id,value\n1,\n2,ok\n3\n");
    defer ds.deinit();
    var f: Filter = .{};
    defer f.deinit(std.testing.allocator);
    _ = try f.setPredicate(std.testing.allocator, 1, .empty, "");
    try f.advance(std.testing.allocator, ds.rows, 9);
    try std.testing.expectEqual(@as(usize, 2), f.count(ds.rows.len));
    _ = try f.setPredicate(std.testing.allocator, 1, .not_empty, "");
    try f.advance(std.testing.allocator, ds.rows, 9);
    try std.testing.expectEqual(@as(usize, 1), f.count(ds.rows.len));
}

test "numeric ascending/descending stable merge sort with tiny budgets" {
    var ds = try csv.Dataset.fromBytes(std.testing.allocator, "id,score\na,10\nb,2\nc,2\nd,25\ne,\n");
    defer ds.deinit();
    var f: Filter = .{};
    defer f.deinit(std.testing.allocator);
    _ = f.setSort(1, .asc);
    var iterations: usize = 0;
    while (!f.complete and iterations < 100) : (iterations += 1) try f.advance(std.testing.allocator, ds.rows, 2);
    try std.testing.expect(f.complete);
    const expected_asc = [_]usize{ 1, 2, 0, 3, 4 };
    for (expected_asc, 0..) |row, i| try std.testing.expectEqual(row, f.rowIndex(i));
    _ = f.setSort(1, .desc);
    iterations = 0;
    while (!f.complete and iterations < 100) : (iterations += 1) try f.advance(std.testing.allocator, ds.rows, 1);
    try std.testing.expect(f.complete);
    const expected_desc = [_]usize{ 3, 0, 1, 2, 4 };
    for (expected_desc, 0..) |row, i| try std.testing.expectEqual(row, f.rowIndex(i));
    _ = f.setSort(null, .asc);
    try std.testing.expect(f.isDirect());
}

test "text predicate operators and numeric invalid values" {
    var ds = try csv.Dataset.fromBytes(std.testing.allocator, "name,score\nAlpha,10\nbeta,nope\nALPINE,20\n");
    defer ds.deinit();
    var f: Filter = .{};
    defer f.deinit(std.testing.allocator);
    _ = try f.setPredicate(std.testing.allocator, 0, .starts_with, "alp");
    try f.advance(std.testing.allocator, ds.rows, 10);
    try std.testing.expectEqual(@as(usize, 2), f.count(ds.rows.len));
    _ = try f.setPredicate(std.testing.allocator, 1, .greater, "9");
    try f.advance(std.testing.allocator, ds.rows, 10);
    try std.testing.expectEqual(@as(usize, 2), f.count(ds.rows.len));
    _ = try f.setPredicate(std.testing.allocator, 0, .equals, "BETA");
    try f.advance(std.testing.allocator, ds.rows, 10);
    try std.testing.expectEqual(@as(usize, 1), f.count(ds.rows.len));
}

test "empty dataset, large budget, cancel during sorting" {
    var ds = try csv.Dataset.fromBytes(std.testing.allocator, "id,value\n");
    defer ds.deinit();
    var f: Filter = .{};
    defer f.deinit(std.testing.allocator);
    _ = f.setSort(0, .asc);
    try f.advance(std.testing.allocator, ds.rows, 1);
    try f.advance(std.testing.allocator, ds.rows, 1);
    try std.testing.expect(f.complete);
    _ = try f.setQuery(std.testing.allocator, "x");
    try std.testing.expect(!f.complete);
}

test "mixed numeric and string values form consistent sort classes" {
    var ds = try csv.Dataset.fromBytes(std.testing.allocator, "value\n3\n2x\n100\n2\n\n");
    defer ds.deinit();
    var f: Filter = .{};
    defer f.deinit(std.testing.allocator);
    _ = f.setSort(0, .asc);
    while (!f.complete) try f.advance(std.testing.allocator, ds.rows, 3);
    const order = [_]usize{ 3, 0, 2, 1, 4 };
    for (order, 0..) |index, i| try std.testing.expectEqual(index, f.rowIndex(i));
}

test "clearCriteria clears indices and stale column selections on a new CSV" {
    var f: Filter = .{};
    defer f.deinit(std.testing.allocator);
    _ = try f.setQuery(std.testing.allocator, "x");
    _ = f.setScope(17);
    _ = try f.setPredicate(std.testing.allocator, 42, .equals, "abc");
    _ = f.setSort(51, .desc);
    f.clearCriteria();
    try std.testing.expect(f.isDirect());
    try std.testing.expect(f.complete);
    try std.testing.expect(f.search_column == null);
    try std.testing.expect(f.predicate_column == null);
    try std.testing.expect(f.sort_column == null);
}
