const std = @import("std");
const Allocator = std.mem.Allocator;
const zdata = @import("zdata");

pub const Row = struct {
    cells: []const []const u8,
};

/// A loaded CSV owns its bytes and cell metadata through one arena.
/// Most cells are slices of the original input; quoted fields are decoded
/// in-place (including doubled quotes). Release everything with deinit().
pub const Dataset = struct {
    arena: std.heap.ArenaAllocator,
    headers: []const []const u8,
    rows: []const Row,
    delimiter: u8,

    pub fn load(parent: Allocator, io: std.Io, path: []const u8) !Dataset {
        var arena = std.heap.ArenaAllocator.init(parent);
        errdefer arena.deinit();
        const a = arena.allocator();
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, a, .limited(128 * 1024 * 1024));
        const parsed = try parseOwned(a, bytes);
        return .{
            .arena = arena,
            .headers = parsed.headers,
            .rows = parsed.rows,
            .delimiter = parsed.delimiter,
        };
    }

    /// Useful for independent unit tests; copies the caller's input.
    pub fn fromBytes(parent: Allocator, bytes: []const u8) !Dataset {
        var arena = std.heap.ArenaAllocator.init(parent);
        errdefer arena.deinit();
        const a = arena.allocator();
        const copy = try a.dupe(u8, bytes);
        const parsed = try parseOwned(a, copy);
        return .{
            .arena = arena,
            .headers = parsed.headers,
            .rows = parsed.rows,
            .delimiter = parsed.delimiter,
        };
    }

    pub fn deinit(self: *Dataset) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

const Parsed = struct {
    headers: []const []const u8,
    rows: []const Row,
    delimiter: u8,
};

const Ending = enum { delimiter, record, eof };
const Field = struct { text: []const u8, ending: Ending };

fn delimiterAt(c: u8, sep: u8) bool {
    return c == sep or c == '\r' or c == '\n';
}

fn nextField(src: []u8, cursor: *usize, sep: u8) !Field {
    var pos = cursor.*;
    var text: []const u8 = undefined;

    if (pos < src.len and src[pos] == '"') {
        pos += 1;
        const start = pos;
        var write_pos = pos;
        var closed = false;
        while (pos < src.len) {
            if (src[pos] == '"') {
                if (pos + 1 < src.len and src[pos + 1] == '"') {
                    src[write_pos] = '"';
                    write_pos += 1;
                    pos += 2;
                } else {
                    pos += 1;
                    closed = true;
                    break;
                }
            } else {
                src[write_pos] = src[pos];
                write_pos += 1;
                pos += 1;
            }
        }
        if (!closed) return error.UnterminatedQuotedField;
        text = src[start..write_pos];
        // Spaces after a closing quote are tolerated.
        while (pos < src.len and (src[pos] == ' ' or src[pos] == '\t') and src[pos] != sep) : (pos += 1) {}
        if (pos < src.len and !delimiterAt(src[pos], sep)) return error.UnexpectedCharacterAfterQuote;
    } else {
        const start = pos;
        while (pos < src.len and !delimiterAt(src[pos], sep)) : (pos += 1) {
            if (src[pos] == '"') return error.QuoteInsideUnquotedField;
        }
        text = src[start..pos];
    }

    if (pos == src.len) {
        cursor.* = pos;
        return .{ .text = text, .ending = .eof };
    }
    const ending: Ending = if (src[pos] == sep) .delimiter else .record;
    if (ending == .record and src[pos] == '\r' and pos + 1 < src.len and src[pos + 1] == '\n') {
        pos += 2;
    } else {
        pos += 1;
    }
    cursor.* = pos;
    return .{ .text = text, .ending = ending };
}

/// Finds structural delimiter candidates in the first *logical* record using
/// ZData's format-neutral scanner and bitmask-to-offset primitive.
/// This is the first real SDK integration, not a claim that ZData parses CSV.
/// The field parser below still owns the CSV grammar and error handling.
fn detectDelimiter(data: []const u8) !u8 {
    const HeaderScanner = zdata.scan.structural.Scanner(.{
        .marks = ",;\t\r\n",
        .quote = '"',
        .escape = .doubled_quote,
    });
    const choices = [_]u8{ ',', ';', '\t' };
    var counts = [_]usize{ 0, 0, 0 };
    var scanner = HeaderScanner.init(null);
    var cursor: usize = 0;
    var end_of_header = false;

    while (cursor < data.len and !end_of_header) {
        const end = @min(cursor + 64, data.len);
        const mask = try scanner.feed(data[cursor..end]);
        var scratch: [64]usize = undefined;
        const offsets = try zdata.bits.positions(mask, cursor, &scratch);
        for (offsets) |offset| {
            const ch = data[offset];
            if (ch == '\r' or ch == '\n') {
                end_of_header = true;
                break;
            }
            for (choices, 0..) |choice, i| {
                if (ch == choice) counts[i] += 1;
            }
        }
        cursor = end;
    }

    // The initial field parser may itself report malformed quoting; the
    // delimiter sniffer intentionally does not validate the whole document.
    var best: usize = 0;
    for (1..choices.len) |i| {
        if (counts[i] > counts[best]) best = i;
    }
    return choices[best];
}

fn parseOwned(a: Allocator, source: []u8) !Parsed {
    const bytes = if (std.mem.startsWith(u8, source, "\xef\xbb\xbf")) source[3..] else source;
    const sep = try detectDelimiter(bytes);
    var cursor: usize = 0;
    var cells: std.ArrayList([]const u8) = .empty;
    var rows: std.ArrayList(Row) = .empty;
    var headers: []const []const u8 = &.{};
    var has_headers = false;

    while (cursor < bytes.len) {
        const field = try nextField(bytes, &cursor, sep);
        try cells.append(a, field.text);
        if (cells.items.len > 512) return error.TooManyColumns;
        if (field.ending == .delimiter and cursor < bytes.len) continue;
        if (field.ending == .delimiter and cursor == bytes.len) {
            try cells.append(a, "");
        }

        const record = try a.dupe([]const u8, cells.items);
        if (!has_headers) {
            headers = record;
            has_headers = true;
        } else {
            try rows.append(a, .{ .cells = record });
        }
        cells.clearRetainingCapacity();
        if (field.ending == .eof or cursor == bytes.len) break;
    }
    return .{
        .headers = headers,
        .rows = try rows.toOwnedSlice(a),
        .delimiter = sep,
    };
}

pub fn rowContains(row: Row, needle: []const u8) bool {
    if (needle.len == 0) return true;
    for (row.cells) |value| {
        if (value.len < needle.len) continue;
        for (0..value.len - needle.len + 1) |start| {
            if (std.ascii.eqlIgnoreCase(value[start..][0..needle.len], needle)) return true;
        }
    }
    return false;
}

test "comma records and empty fields" {
    var csv = try Dataset.fromBytes(std.testing.allocator, "id,name,score\n1,Ada,15\n2,,20\n");
    defer csv.deinit();
    try std.testing.expectEqual(@as(usize, 3), csv.headers.len);
    try std.testing.expectEqual(@as(usize, 2), csv.rows.len);
    try std.testing.expectEqualStrings("", csv.rows[1].cells[1]);
}

test "quoted comma, doubled quote and multiline" {
    var csv = try Dataset.fromBytes(std.testing.allocator, "id,note\n1,\"hello, world\"\n2,\"a \"\"quote\"\"\"\n3,\"two\nlines\"\n");
    defer csv.deinit();
    try std.testing.expectEqual(@as(usize, 3), csv.rows.len);
    try std.testing.expectEqualStrings("hello, world", csv.rows[0].cells[1]);
    try std.testing.expectEqualStrings("a \"quote\"", csv.rows[1].cells[1]);
    try std.testing.expectEqualStrings("two\nlines", csv.rows[2].cells[1]);
}

test "semicolon, BOM, CRLF and trailing delimiter" {
    var csv = try Dataset.fromBytes(std.testing.allocator, "\xef\xbb\xbfid;name;note\r\n1;Eva;\r\n2;Leo;end;\r\n");
    defer csv.deinit();
    try std.testing.expectEqual(@as(u8, ';'), csv.delimiter);
    try std.testing.expectEqualStrings("id", csv.headers[0]);
    try std.testing.expectEqualStrings("", csv.rows[0].cells[2]);
    try std.testing.expectEqual(@as(usize, 4), csv.rows[1].cells.len);
}

test "tab delimiter and malformed input" {
    var tab = try Dataset.fromBytes(std.testing.allocator, "id\tname\n1\tSam\n");
    defer tab.deinit();
    try std.testing.expectEqual(@as(u8, '\t'), tab.delimiter);
    try std.testing.expectError(error.UnterminatedQuotedField, Dataset.fromBytes(std.testing.allocator, "a,b\n1,\"broken"));
}

test "case-insensitive row filter" {
    var csv = try Dataset.fromBytes(std.testing.allocator, "name,state\nAda,Active\nBen,Idle\n");
    defer csv.deinit();
    try std.testing.expect(rowContains(csv.rows[0], "ACT"));
    try std.testing.expect(!rowContains(csv.rows[1], "ACT"));
}

test "ZData sniff ignores quoted delimiters across 64-byte boundaries" {
    const pad = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const text = "id;\"one,two" ++ pad ++ "\";value\n1;hello;123\n";
    var ds = try Dataset.fromBytes(std.testing.allocator, text);
    defer ds.deinit();
    try std.testing.expectEqual(@as(u8, ';'), ds.delimiter);
    try std.testing.expectEqual(@as(usize, 3), ds.headers.len);
    try std.testing.expectEqualStrings("one,two" ++ pad, ds.headers[1]);
}

test "ZData sniff respects doubled quotes and multiline headers" {
    var ds = try Dataset.fromBytes(
        std.testing.allocator,
        "id,\"label; with \"\"escaped\"\" quote\nand newline\",value\n1,ok,5\n",
    );
    defer ds.deinit();
    try std.testing.expectEqual(@as(u8, ','), ds.delimiter);
    try std.testing.expectEqual(@as(usize, 3), ds.headers.len);
    try std.testing.expectEqualStrings("label; with \"escaped\" quote\nand newline", ds.headers[1]);
}
