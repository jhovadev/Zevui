//! `zig run src/bench.zig -O ReleaseFast -- /path/to/large.csv`
//! When no argument is given, generates 200,000 CSV rows in memory.
//! Reports elapsed wall time; benchmarks are observational, never pass/fail.
const std = @import("std");
const csv = @import("csv.zig");
const search = @import("search.zig");

fn elapsedMs(io: std.Io, start: anytype) i64 {
    return @intCast(@divTrunc(start.untilNow(io, .awake).toNanoseconds(), std.time.ns_per_ms));
}

fn generate(allocator: std.mem.Allocator, size: usize) ![]const u8 {
    var lines: std.ArrayList(u8) = .empty;
    try lines.appendSlice(allocator, "id,name,price,category\n");
    const examples = [_][]const u8{
        "1,Ada,14.99,A\n", "2,Ben,2.10,B\n", "3,Eve,20.05,C\n", "4,Leo,14.99,D\n",
    };
    for (0..size) |i| try lines.appendSlice(allocator, examples[i % examples.len]);
    return try lines.toOwnedSlice(allocator);
}

fn runToCompletion(a: std.mem.Allocator, f: *search.Filter, rows: []const csv.Row) !void {
    while (!f.complete) {
        try f.advance(a, rows, if (f.sorting) search.sort_budget else search.scan_budget);
    }
}

pub fn main(init: std.process.Init) !void {
    const a = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(a);
    const generated: ?[]const u8 = if (args.len < 2) try generate(a, 200_000) else null;
    const file_name: []const u8 = if (args.len < 2) "generated (200000)" else args[1];

    const start_parse = std.Io.Clock.awake.now(io);
    var ds = if (generated) |data| try csv.Dataset.fromBytes(a, data) else try csv.Dataset.load(a, io, args[1]);
    const parse_ms = elapsedMs(io, start_parse);
    defer ds.deinit();

    var f: search.Filter = .{};
    defer f.deinit(a);
    // Choose the fuel price column in the user's dataset, otherwise a synthetic price.
    var price_col: usize = if (ds.headers.len > 2) 2 else 0;
    for (ds.headers, 0..) |name, i| {
        if (std.mem.eql(u8, name, "g_premium") or std.mem.eql(u8, name, "price")) {
            price_col = i;
            break;
        }
    }
    const start_global = std.Io.Clock.awake.now(io);
    _ = try f.setQuery(a, "14.99");
    try runToCompletion(a, &f, ds.rows);
    const global_ms = elapsedMs(io, start_global);
    const global_matches = f.count(ds.rows.len);

    const start_column = std.Io.Clock.awake.now(io);
    _ = f.setScope(price_col);
    try runToCompletion(a, &f, ds.rows);
    const column_ms = elapsedMs(io, start_column);
    const column_matches = f.count(ds.rows.len);

    const start_sort = std.Io.Clock.awake.now(io);
    f.clearCriteria();
    _ = f.setSort(price_col, .asc);
    try runToCompletion(a, &f, ds.rows);
    const sort_ms = elapsedMs(io, start_sort);

    const start_combined = std.Io.Clock.awake.now(io);
    _ = try f.setPredicate(a, price_col, .greater, "14");
    try runToCompletion(a, &f, ds.rows);
    const combined_ms = elapsedMs(io, start_combined);
    const combined_matches = f.count(ds.rows.len);

    std.debug.print(
        "CSV benchmark (Zig 0.17)\nFile: {s}\nRows: {d}; Cols: {d}\n" ++
        "Load + parse: {d} ms\nGlobal search: {d} ms ({d} matches)\n" ++
        "Column search: {d} ms ({d} matches)\n" ++
        "Numeric sort: {d} ms\nFilter + sort: {d} ms ({d} matches)\n",
        .{ file_name, ds.rows.len, ds.headers.len, parse_ms, global_ms, global_matches,
            column_ms, column_matches, sort_ms, combined_ms, combined_matches },
    );
}
