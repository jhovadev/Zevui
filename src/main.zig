const std = @import("std");
const dvui = @import("dvui");
const csv = @import("csv.zig");
const search = @import("search.zig");
const tokens = @import("ui/tokens.zig");
const hooks = @import("ui/hooks.zig");
const style = @import("ui/dvui_style.zig");
const ui = @import("ui/components.zig");
const brand = @import("app/identity.zig");
const vector_icons = @import("ui/icons.zig");

pub const dvui_app: dvui.App = .{
    .config = .{ .options = .{
        .title = brand.title,
        // Keep identity.zig independent of DVUI; convert at the UI boundary.
        .size = dvui.Size.cast(brand.window_size),
        .min_size = dvui.Size.cast(brand.minimum_size),
        .app = brand.application,
        .org = brand.organization,
        .icon = brand.icon_png,
    } },
    .frameFn = appFrame,
    .initFn = appInit,
    .deinitFn = appDeinit,
};
pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{ .logFn = dvui.App.logFn };

// Presentation is derived from explicit design tokens, not hardcoded by widget.
// `accent_names` labels belong to the column badge selection, independent of
// the application's global accent preference.
const accent_names = [_][]const u8{ "Lavanda", "Coral", "Menta", "Azul", "Ambar" };

const ColumnSettings = struct {
    title: ?[]u8 = null,
    badge: bool = false,
    visible: bool = true,
    accent_index: usize = 0,
};

const State = struct {
    appearance: tokens.Appearance = .{
        .mode = @field(tokens.Mode, brand.default_theme),
        .accent = @field(tokens.Accent, brand.default_accent),
        .density = @field(tokens.Density, brand.default_density),
    },
    show_path: bool = false,
    show_search: bool = false,
    show_appearance: bool = false,
    search_draft: std.ArrayList(u8) = .empty,
    path_draft: std.ArrayList(u8) = .empty,
    dataset: ?csv.Dataset = null,
    filter: search.Filter = .{},
    page: usize = 0,
    file_name: ?[]u8 = null,
    columns: []ColumnSettings = &.{},
    selected_column: ?usize = null,
    show_columns: bool = false,
    show_scopes: bool = false,
    column_generation: usize = 0,
    panel_tab: enum { style, data } = .style,
    filter_draft: std.ArrayList(u8) = .empty,
    filter_op_draft: search.Predicate = .contains,
    draft_name: std.ArrayList(u8) = .empty,
    draft_badge: bool = false,
    draft_accent: usize = 0,
    status: []const u8 = "Abre un archivo para comenzar.",

    fn clearColumns(self: *State, a: std.mem.Allocator) void {
        for (self.columns) |col| {
            if (col.title) |title| a.free(title);
        }
        if (self.columns.len != 0) a.free(self.columns);
        self.columns = &.{};
        self.selected_column = null;
        self.draft_name.clearRetainingCapacity();
        self.filter_draft.clearRetainingCapacity();
        self.show_columns = false;
        self.show_scopes = false;
    }

    fn deinit(self: *State, a: std.mem.Allocator) void {
        if (self.dataset) |*ds| ds.deinit();
        self.filter.deinit(a);
        self.clearColumns(a);
        self.draft_name.deinit(a);
        self.path_draft.deinit(a);
        self.search_draft.deinit(a);
        self.filter_draft.deinit(a);
        if (self.file_name) |name| a.free(name);
    }

    fn load(self: *State, a: std.mem.Allocator, io: std.Io, filename: []const u8) !void {
        // Allocate replacements before destroying the currently loaded CSV.
        var next = try csv.Dataset.load(a, io, filename);
        errdefer next.deinit();
        const cols = try a.alloc(ColumnSettings, next.headers.len);
        errdefer a.free(cols);
        @memset(cols, .{});
        const name = try a.dupe(u8, std.fs.path.basename(filename));
        errdefer a.free(name);

        if (self.dataset) |*old| old.deinit();
        self.clearColumns(a);
        if (self.file_name) |old| a.free(old);
        self.dataset = next;
        self.columns = cols;
        self.file_name = name;
        self.page = 0;
        self.filter.clearCriteria();
        self.search_draft.clearRetainingCapacity();
        self.column_generation +%= 1;
        self.status = "Archivo cargado correctamente";
    }

    fn openColumn(self: *State, a: std.mem.Allocator, index: usize) !void {
        const ds = if (self.dataset) |*value| value else return;
        if (index >= ds.headers.len) return;
        self.draft_name.clearRetainingCapacity();
        try self.draft_name.appendSlice(a, self.columns[index].title orelse ds.headers[index]);
        self.draft_badge = self.columns[index].badge;
        self.draft_accent = self.columns[index].accent_index;
        self.filter_draft.clearRetainingCapacity();
        if (self.filter.predicate_column == index) {
            try self.filter_draft.appendSlice(a, self.filter.predicate_text.items);
            self.filter_op_draft = self.filter.predicate;
        } else {
            self.filter_op_draft = .contains;
        }
        self.show_columns = false;
        self.show_scopes = false;
        self.panel_tab = .style;
        self.selected_column = index;
    }

    fn saveColumn(self: *State, a: std.mem.Allocator) !void {
        const index = self.selected_column orelse return;
        const proposed = std.mem.trim(u8, self.draft_name.items, " \t\r\n");
        if (proposed.len == 0) return;
        const next_title = try a.dupe(u8, proposed);
        if (self.columns[index].title) |old| a.free(old);
        self.columns[index].title = next_title;
        self.columns[index].badge = self.draft_badge;
        self.columns[index].accent_index = self.draft_accent;
        self.selected_column = null;
        self.status = "Configuracion de columna guardada (solo vista).";
    }

    fn visibleCount(self: *const State) usize {
        var n: usize = 0;
        for (self.columns) |c| {
            if (c.visible) n += 1;
        }
        return n;
    }

    fn toggleVisible(self: *State, index: usize) void {
        if (index >= self.columns.len) return;
        if (self.columns[index].visible and self.visibleCount() == 1) return;
        self.columns[index].visible = !self.columns[index].visible;
        self.column_generation +%= 1;
    }

    fn total(self: *const State) usize {
        if (self.dataset) |ds| return self.filter.count(ds.rows.len);
        return 0;
    }

    fn pages(self: *const State) usize {
        if (self.dataset) |ds| return self.filter.pageCount(ds.rows.len);
        return 1;
    }

    fn updateSearch(self: *State, a: std.mem.Allocator, query: []const u8) !void {
        if (try self.filter.setQuery(a, query)) self.page = 0;
    }
};

var state: State = .{};
var icons: vector_icons.Store = .{};

pub fn appInit(win: *dvui.Window) !void {
    win.themeSet(style.themeFor(state.appearance.mode));
    icons.init(win.gpa);
}

pub fn appDeinit(win: *dvui.Window) void {
    icons.deinit(win.gpa);
    state.deinit(win.gpa);
}

fn openCsv(a: std.mem.Allocator) !void {
    if (!dvui.useTinyFileDialogs) {
        state.show_path = true;
        state.status = "Usa la ruta de archivo para cargar un CSV.";
        return;
    }
    const picked = try dvui.dialogNativeFileOpen(a, .{
        .title = "Seleccionar CSV / TSV",
        .filters = &.{ "*.csv", "*.tsv", "*.txt" },
        .filter_description = "Datos tabulares",
    });
    if (picked) |path| {
        defer a.free(path);
        state.load(a, dvui.io, path) catch |err| {
            std.log.err("No se pudo abrir {s}: {}", .{ path, err });
            state.status = "No se pudo abrir el CSV. Comprueba ruta y formato.";
        };
    }
}

fn topBar(a: std.mem.Allocator) !void {
    const P = style.palette(state.appearance);
    const D = style.spacing(state.appearance.density);
    var strip = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .background = true,
        .color_fill = P.surface,
        .border = .{ .x = 0, .y = 0, .w = 0, .h = 1 },
        .color_border = P.border,
        .padding = .{ .x = D.md, .y = D.sm, .w = D.md, .h = D.sm },
    });
    defer strip.deinit();

    dvui.label(@src(), "{s}", .{brand.short_name}, .{
        .font = .theme(.title), .color_text = P.accent_text, .gravity_y = 0.5,
    });
    dvui.label(@src(), " / {s}", .{brand.screen_name}, .{
        .font = .theme(.heading), .color_text = P.text, .gravity_y = 0.5,
    });
    if (ui.action(@src(), "+ Abrir CSV", .primary, P)) try openCsv(a);
    if (state.dataset != null) {
        if (ui.iconAction(@src(), "Columnas", icons.columns, if (state.show_columns) .selected else .secondary, P)) {
            state.show_columns = !state.show_columns;
            state.show_scopes = false;
            state.selected_column = null;
        }
    }
    // Search and appearance are popover-like disclosure rows, not permanent
    // full-width toolbars that steal vertical space from the data grid.
    if (ui.iconAction(@src(), "Buscar", icons.search, if (state.show_search) .selected else .secondary, P)) {
        state.show_search = !state.show_search;
        state.show_appearance = false;
    }
    if (ui.action(@src(), if (state.show_path) "Cerrar ruta" else "Abrir ruta", .secondary, P)) {
        hooks.useDisclosure(&state.show_path).toggle();
    }
    if (ui.iconAction(@src(), "Apariencia", icons.appearance, if (state.show_appearance) .selected else .secondary, P)) {
        state.show_appearance = !state.show_appearance;
        state.show_search = false;
    }
}

// Search remains available on demand and retains its query after closing.
fn searchPanel(a: std.mem.Allocator) !void {
    if (!state.show_search) return;
    const P = style.palette(state.appearance);
    const D = style.spacing(state.appearance.density);
    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal, .background = true, .color_fill = P.canvas,
        .padding = .{ .x = D.md, .y = 5, .w = D.md, .h = 5 },
    });
    defer row.deinit();
    var entry = dvui.textEntry(@src(), .{
        .placeholder = "Buscar en los datos...",
        .text = .{ .array_list = .{ .backing = &state.search_draft, .allocator = a, .limit = 512 } },
    }, .{
        .min_size_content = .{ .w = 210, .h = 20 },
        .max_size_content = .{ .w = 330, .h = 22 },
        .margin = .all(0), .padding = .all(6),
        .background = true, .color_fill = P.elevated, .color_text = P.text,
        .color_border = P.border, .border = .all(1), .corners = .round(8),
    });
    defer entry.deinit();
    try state.updateSearch(a, entry.textGet());
    if (state.dataset) |ds| {
        const scope = if (state.filter.search_column) |idx|
            (state.columns[idx].title orelse ds.headers[idx])
        else
            "Todas";
        if (ui.action(@src(), scope, if (state.show_scopes) .selected else .secondary, P)) {
            state.show_scopes = !state.show_scopes;
            state.show_columns = false;
            state.selected_column = null;
        }
    }
    if (state.search_draft.items.len != 0) {
        if (ui.action(@src(), "Limpiar", .secondary, P)) {
            state.search_draft.clearRetainingCapacity();
            try state.updateSearch(a, "");
        }
    }
}

fn appearancePanel() void {
    if (!state.show_appearance) return;
    const P = style.palette(state.appearance);
    const D = style.spacing(state.appearance.density);
    const theme = hooks.useTheme(&state.appearance);
    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal, .background = true, .color_fill = P.canvas,
        .padding = .{ .x = D.md, .y = 5, .w = D.md, .h = 5 },
    });
    defer row.deinit();
    dvui.label(@src(), "Apariencia", .{}, .{ .color_text = P.muted, .gravity_y = 0.5 });
    dvui.label(@src(), "v{s}", .{brand.version}, .{ .color_text = P.muted, .gravity_y = 0.5 });
    if (ui.action(@src(), tokens.modeName(state.appearance.mode), .secondary, P)) {
        theme.cycle();
        dvui.refresh(null, @src(), null);
    }
    if (ui.action(@src(), tokens.accentName(state.appearance.accent), .secondary, P)) {
        theme.nextAccent();
        dvui.refresh(null, @src(), null);
    }
    // This control describes the ACTION, not the current selection. The current
    // state is shown in the description so Compacta is not confused with Search.
    if (ui.action(@src(), if (state.appearance.density == .compact) "Usar comoda" else "Usar compacta", .secondary, P)) {
        theme.toggleDensity();
        dvui.refresh(null, @src(), null);
    }
}

/// Path-based opening keeps file import available in portable builds where
/// native file dialogs are intentionally not linked.
fn pathBar(a: std.mem.Allocator) !void {
    if (!state.show_path) return;
    const P = style.palette(state.appearance);
    var panel = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal, .background = true,
        .color_fill = P.surface, .padding = .all(10),
    });
    defer panel.deinit();
    dvui.label(@src(), "Ruta del archivo", .{}, .{ .color_text = P.muted, .gravity_y = 0.5 });
    var entry = dvui.textEntry(@src(), .{
        .placeholder = "/ruta/al/archivo.csv",
        .text = .{ .array_list = .{ .backing = &state.path_draft, .allocator = a, .limit = 4096 } },
    }, .{ .expand = .horizontal, .background = true, .color_fill = P.elevated,
        .color_text = P.text, .color_border = P.border, .border = .all(1),
        .corners = .round(9), .padding = .all(7),
    });
    defer entry.deinit();
    if (dvui.button(@src(), "Cargar", .{}, .{
        .color_fill = P.accent, .color_text = P.on_accent,
        .corners = .round(9), .padding = .all(8),
    })) {
        const filename = std.mem.trim(u8, state.path_draft.items, " \r\n\t");
        if (filename.len == 0) {
            state.status = "Introduce una ruta de archivo.";
        } else {
            state.load(a, dvui.io, filename) catch |err| {
                std.log.err("No se pudo cargar {s}: {}", .{ filename, err });
                state.status = "No se pudo cargar la ruta indicada.";
                return;
            };
            state.show_path = false;
        }
    }
}

fn summaryBar() void {
    const P = style.palette(state.appearance);
    const D = style.spacing(state.appearance.density);
    var strip = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .background = true,
        .color_fill = P.canvas,
        .padding = .{ .x = D.md, .y = 6, .w = D.md, .h = 6 },
    });
    defer strip.deinit();

    if (state.dataset) |ds| {
        dvui.label(@src(), "{s}", .{state.file_name orelse "CSV"}, .{
            .font = .theme(.heading), .color_text = P.text, .gravity_y = 0.5,
        });
        dvui.label(@src(), "  ·  {d} filas", .{ds.rows.len}, .{
            .color_text = P.muted, .gravity_y = 0.5,
        });
        dvui.label(@src(), "  ·  {d}/{d} columnas", .{state.visibleCount(), ds.headers.len}, .{
            .color_text = P.muted, .gravity_y = 0.5,
        });
        dvui.label(@src(), "  ·  {d} resultados{s}", .{ state.total(), if (state.filter.complete) "" else " (procesando)" }, .{
            .color_text = P.accent_text, .gravity_y = 0.5,
        });
    } else {
        dvui.label(@src(), "ESPACIO DE TRABAJO", .{}, .{
            .font = .theme(.heading), .color_text = P.text, .gravity_y = 0.5,
        });
        dvui.label(@src(), "  ·  {s}", .{state.status}, .{
            .color_text = P.muted, .gravity_y = 0.5,
        });
    }
}

fn pageBar() void {
    if (state.dataset == null) return;
    const P = style.palette(state.appearance);
    var bar = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .background = true,
        .color_fill = P.surface,
        .padding = .all(7),
        .corners = .round(8),
        .margin = .{ .x = 9, .y = 3, .w = 9, .h = 3 },
    });
    defer bar.deinit();

    if (state.dataset) |ds| {
        const total = state.total();
        const pages = state.pages();
        if (state.page >= pages) state.page = pages - 1;
        const first = state.page * search.page_size;
        const last = @min(total, first + search.page_size);
        dvui.label(@src(), "Filas {d}-{d} de {d}", .{ if (total == 0) @as(usize, 0) else first + 1, last, total }, .{
            .color_text = P.muted, .gravity_y = 0.5,
        });
        if (!state.filter.complete) {
            const progress = if (ds.rows.len == 0) @as(usize, 100) else state.filter.scanned * 100 / ds.rows.len;
            if (state.filter.sorting) {
                dvui.label(@src(), "   Ordenando... bloque {d}", .{state.filter.sort_width}, .{
                    .color_text = P.accent_text, .gravity_y = 0.5,
                });
            } else {
                dvui.label(@src(), "   Filtrando... {d}%", .{progress}, .{
                    .color_text = P.accent_text, .gravity_y = 0.5,
                });
            }
        }
        const old_page = state.page;
        if (dvui.button(@src(), "|<", .{}, .{ .color_fill = P.elevated, .corners = .round(6) })) state.page = 0;
        if (dvui.button(@src(), "<", .{}, .{ .color_fill = P.elevated, .corners = .round(6) })) {
            state.page = state.page -| 1;
        }
        dvui.label(@src(), "  {d} / {d}  ", .{ state.page + 1, pages }, .{
            .color_text = P.text, .gravity_y = 0.5,
        });
        if (dvui.button(@src(), ">", .{}, .{ .color_fill = P.elevated, .corners = .round(6) })) {
            if (state.page + 1 < pages) state.page += 1;
        }
        if (dvui.button(@src(), ">|", .{}, .{ .color_fill = P.elevated, .corners = .round(6) })) state.page = pages - 1;
        if (state.page != old_page) dvui.refresh(null, @src(), null);
        dvui.label(@src(), "   {d} filas por pagina", .{search.page_size}, .{ .color_text = P.muted, .gravity_y = 0.5 });
    }
}

fn dataTable(a: std.mem.Allocator) !void {
    const P = style.palette(state.appearance);
    const D = style.spacing(state.appearance.density);
    if (state.dataset) |*ds| {
        if (ds.headers.len == 0) {
            dvui.label(@src(), "Este archivo no contiene cabeceras.", .{}, .{});
            return;
        }
        const total = state.total();
        const first = state.page * search.page_size;
        const count = if (first >= total) @as(usize, 0) else @min(search.page_size, total - first);

        // Changing page creates a fresh grid widget ID, resetting its scroll.
        // GridWidget.rowsVisible() walks from row zero, so NEVER pass 497k rows.
        var grid = dvui.grid(@src(), .{
            .rows = count,
            .scroll_opts = .{ .horizontal = .auto },
        }, .{
            .expand = .both,
            .id_extra = state.page +% (state.filter.generation *% 1000003) +% (state.column_generation *% 7919),
            .margin = .{ .x = 9, .y = 3, .w = 9, .h = 3 },
            .background = true,
            .color_fill = P.surface,
            .border = .all(1),
            .color_border = P.border,
            .corners = .round(8),
        });
        defer grid.deinit();

        // A stable row-number gutter keeps the virtualized table familiar to
        // spreadsheet users without materializing the entire document.
        {
            const gutter = grid.colHeader(.{ .col = 0 }, .{
                .background = true, .color_fill = P.header,
                .border = .{ .x = 0, .y = 0, .w = 1, .h = 1 },
                .color_border = P.border, .padding = .all(6),
            });
            defer gutter.deinit();
            dvui.label(@src(), "#", .{}, .{ .color_text = P.muted });
        }
        var visible_col: usize = 1;
        for (ds.headers, 0..) |original, col| {
            if (!state.columns[col].visible) continue;
            const header = grid.colHeader(.{ .col = visible_col }, .{
                .background = true,
                .color_fill = P.header,
                .border = .{ .x = 0, .y = 0, .w = 1, .h = 1 },
                .color_border = P.border,
                .padding = .{ .x = 8, .y = 6, .w = 8, .h = 6 },
            });
            defer header.deinit();
            const title = state.columns[col].title orelse original;
            if (dvui.button(@src(), title, .{}, .{
                .id_extra = col,
                .background = false,
                .border = .all(0),
                .color_text = P.accent_text,
                .padding = .all(0),
            })) try state.openColumn(a, col);
            visible_col += 1;
        }
        const visible_first, const visible_last = grid.rowsVisible();
        for (visible_first..@min(visible_last, count)) |visible_row| {
            const index = state.filter.rowIndex(first + visible_row);
            const row = ds.rows[index];
            {
                var gutter = grid.cell(.{ .col = 0, .row = visible_row }, .{
                    .background = true, .color_fill = P.header,
                    .border = .{ .x = 0, .y = 0, .w = 1, .h = 1 },
                    .color_border = P.border,
                    .padding = .{ .x = 8, .y = D.cell_y, .w = 8, .h = D.cell_y },
                    .min_size_content = .{ .w = 34, .h = 16 },
                });
                defer gutter.deinit();
                dvui.label(@src(), "{d}", .{index + 1}, .{ .color_text = P.muted });
            }
            var screen_col: usize = 1;
            for (ds.headers, 0..) |_, col| {
                if (!state.columns[col].visible) continue;
                var cell = grid.cell(.{ .col = screen_col, .row = visible_row }, .{
                    .border = .{ .x = 0, .y = 0, .w = 0, .h = 1 },
                    .color_border = P.border,
                    .background = true,
                    .color_fill = if (visible_row % 2 == 0) P.surface else P.row_alt,
                    .padding = .{ .x = D.cell_x, .y = D.cell_y, .w = D.cell_x, .h = D.cell_y },
                    .min_size_content = .{ .w = 76, .h = 16 },
                });
                defer cell.deinit();
                const val: []const u8 = if (col < row.cells.len) row.cells[col] else "";
                if (state.columns[col].badge and val.len != 0) {
                    var chip = dvui.box(@src(), .{}, .{
                        .background = true,
                        .color_fill = style.accents(state.appearance.mode)[state.columns[col].accent_index],
                        .corners = .round(8),
                        .padding = .all(5),
                    });
                    defer chip.deinit();
                    dvui.label(@src(), "{s}", .{val}, .{ .color_text = P.on_accent });
                } else {
                    dvui.label(@src(), "{s}", .{val}, .{
                        .color_text = if (col == 0) P.accent else P.text,
                    });
                }
                screen_col += 1;
            }
        }
    } else {
        var empty = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .both,
            .margin = .all(10),
            .background = true,
            .color_fill = P.surface,
            .border = .all(1),
            .color_border = P.border,
            .corners = .round(12),
            .padding = .all(24),
        });
        defer empty.deinit();
        dvui.label(@src(), "01  /  IMPORTAR DATOS", .{}, .{ .color_text = P.accent_text });
        dvui.label(@src(), "Tu CSV, listo para explorar.", .{}, .{
            .font = .theme(.title), .color_text = P.text,
        });
        dvui.label(@src(), "Abre un CSV o TSV para buscar, filtrar y ordenar sin modificar el original.", .{}, .{
            .color_text = P.muted,
        });
        {
            var actions = dvui.box(@src(), .{ .dir = .horizontal }, .{ .margin = .{ .y = 12 } });
            defer actions.deinit();
            if (ui.action(@src(), "+ Abrir archivo", .primary, P)) try openCsv(a);
            if (ui.action(@src(), "Introducir ruta", .secondary, P)) state.show_path = true;
        }
        dvui.label(@src(), "CSV / TSV  ·  Busqueda incremental  ·  ZData + DVUI", .{}, .{
            .color_text = P.muted,
        });
    }
}

fn columnsPanel(a: std.mem.Allocator) !void {
    const P = style.palette(state.appearance);
    if (!state.show_columns or state.dataset == null) return;
    const ds = state.dataset.?;
    var panel = dvui.box(@src(), .{ .dir = .vertical }, .{
        .min_size_content = .{ .w = 318, .h = 0 },
        .background = true,
        .color_fill = P.surface,
        .border = .all(1),
        .color_border = P.border,
        .corners = .round(18),
        .padding = .all(14),
        .margin = .{ .x = 5, .y = 4, .w = 12, .h = 4 },
        .expand = .vertical,
    });
    defer panel.deinit();
    dvui.label(@src(), "Columnas", .{}, .{ .font = .theme(.title), .color_text = P.text });
    dvui.label(@src(), "Mostrar y ocultar sin cambiar el CSV", .{}, .{ .color_text = P.muted });
    {
        var buttons = dvui.box(@src(), .{ .dir = .horizontal }, .{ .margin = .{ .y = 8 } });
        defer buttons.deinit();
        if (dvui.button(@src(), "Mostrar todas", .{}, .{ .color_fill = P.accent_soft, .corners = .round(8) })) {
            for (state.columns) |*c| c.visible = true;
            state.column_generation +%= 1;
        }
        if (dvui.button(@src(), "Cerrar", .{}, .{ .color_fill = P.elevated, .corners = .round(8) })) state.show_columns = false;
    }
    for (ds.headers, 0..) |name, col| {
        var line = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .id_extra = col, .padding = .{ .y = 3 },
        });
        defer line.deinit();
        const label = state.columns[col].title orelse name;
        dvui.label(@src(), "{s}", .{if (label.len > 17) label[0..17] else label}, .{
            .min_size_content = .{ .w = 125, .h = 0 }, .color_text = P.text, .gravity_y = 0.5,
        });
        if (dvui.button(@src(), if (state.columns[col].visible) "Visible" else "Oculta", .{}, .{
            .id_extra = col,
            .color_fill = if (state.columns[col].visible) P.accent_soft else P.elevated,
            .corners = .round(8), .padding = .all(5),
        })) state.toggleVisible(col);
        if (dvui.button(@src(), "Editar", .{}, .{ .id_extra = col, .color_fill = P.elevated, .corners = .round(8), .padding = .all(5) })) try state.openColumn(a, col);
    }
    dvui.label(@src(), "Siempre queda una columna visible.", .{}, .{ .color_text = P.muted });
}

fn scopesPanel() void {
    const P = style.palette(state.appearance);
    if (!state.show_scopes or state.dataset == null) return;
    const ds = state.dataset.?;
    var panel = dvui.box(@src(), .{ .dir = .vertical }, .{
        .min_size_content = .{ .w = 318, .h = 0 },
        .background = true,
        .color_fill = P.surface,
        .border = .all(1),
        .color_border = P.border,
        .corners = .round(18),
        .padding = .all(14),
        .margin = .{ .x = 5, .y = 4, .w = 12, .h = 4 },
        .expand = .vertical,
    });
    defer panel.deinit();
    dvui.label(@src(), "Buscar en", .{}, .{ .font = .theme(.title), .color_text = P.text });
    dvui.label(@src(), "Limita la busqueda a una columna", .{}, .{ .color_text = P.muted });
    if (dvui.button(@src(), "Todas las columnas", .{}, .{
        .color_fill = if (state.filter.search_column == null) P.accent_soft else P.elevated,
        .corners = .round(9), .margin = .{ .y = 5 },
    })) {
        if (state.filter.setScope(null)) state.page = 0;
        state.show_scopes = false;
    }
    for (ds.headers, 0..) |original, col| {
        const label = state.columns[col].title orelse original;
        if (dvui.button(@src(), label, .{}, .{
            .id_extra = col,
            .color_fill = if (state.filter.search_column == col) P.accent_soft else P.elevated,
            .corners = .round(9), .margin = .{ .y = 2 }, .expand = .horizontal,
        })) {
            if (state.filter.setScope(col)) state.page = 0;
            state.show_scopes = false;
        }
    }
}

fn columnPanel(a: std.mem.Allocator) !void {
    const P = style.palette(state.appearance);
    const selected = state.selected_column orelse return;
    if (state.dataset == null or selected >= state.columns.len) return;

    var panel = dvui.box(@src(), .{ .dir = .vertical }, .{
        .min_size_content = .{ .w = 318, .h = 0 },
        .background = true,
        .color_fill = P.surface,
        .border = .all(1),
        .color_border = P.border,
        .corners = .round(18),
        .padding = .all(14),
        .margin = .{ .x = 5, .y = 4, .w = 12, .h = 4 },
        .expand = .vertical,
    });
    defer panel.deinit();
    dvui.label(@src(), "Column Settings", .{}, .{ .font = .theme(.title), .color_text = P.text });
    dvui.label(@src(), "Configuracion local de la columna", .{}, .{ .color_text = P.muted });
    {
        var tabs = dvui.box(@src(), .{ .dir = .horizontal }, .{ .margin = .{ .y = 10 } });
        defer tabs.deinit();
        if (dvui.button(@src(), "Apariencia", .{}, .{
            .color_fill = if (state.panel_tab == .style) P.accent_soft else P.elevated,
            .corners = .round(9), .padding = .all(8),
        })) state.panel_tab = .style;
        if (dvui.button(@src(), "Datos / filtro", .{}, .{
            .color_fill = if (state.panel_tab == .data) P.accent_soft else P.elevated,
            .corners = .round(9), .padding = .all(8),
        })) state.panel_tab = .data;
    }

    if (state.panel_tab == .style) {
        dvui.label(@src(), "Name", .{}, .{ .color_text = P.muted });
        var title_entry = dvui.textEntry(@src(), .{
            .text = .{ .array_list = .{ .backing = &state.draft_name, .allocator = a, .limit = 200 } },
        }, .{
            .background = true, .color_fill = P.elevated, .color_border = P.border,
            .color_text = P.text, .border = .all(1), .corners = .round(12), .expand = .horizontal,
        });
        title_entry.deinit();
        dvui.label(@src(), "Tipo", .{}, .{ .color_text = P.muted });
        {
            var types = dvui.box(@src(), .{ .dir = .horizontal }, .{ .margin = .{ .y = 8 } });
            defer types.deinit();
            if (dvui.button(@src(), "Texto", .{}, .{
                .color_fill = if (!state.draft_badge) P.accent_soft else P.elevated,
                .corners = .round(10), .padding = .all(9),
            })) state.draft_badge = false;
            if (dvui.button(@src(), "Badge", .{}, .{
                .color_fill = if (state.draft_badge) P.accent_soft else P.elevated,
                .corners = .round(10), .padding = .all(9),
            })) state.draft_badge = true;
        }
        dvui.label(@src(), "Color: {s}", .{accent_names[state.draft_accent]}, .{ .color_text = P.muted });
        {
            var swatches = dvui.box(@src(), .{ .dir = .horizontal }, .{ .margin = .{ .y = 7 } });
            defer swatches.deinit();
            for (accent_names, 0..) |_, idx| {
                if (dvui.button(@src(), "A", .{}, .{
                    .id_extra = idx, .color_fill = style.accents(state.appearance.mode)[idx], .color_text = P.on_accent,
                    .border = if (state.draft_accent == idx) .all(2) else .all(0),
                    .color_border = P.text, .corners = .round(8), .padding = .all(5),
                })) state.draft_accent = idx;
            }
        }
        dvui.label(@src(), "Preview", .{}, .{ .color_text = P.muted });
        {
            var preview = dvui.box(@src(), .{}, .{
                .background = true, .color_fill = P.elevated, .corners = .round(12),
                .padding = .all(14), .expand = .horizontal,
            });
            defer preview.deinit();
            dvui.label(@src(), "{s}", .{state.draft_name.items}, .{
                .color_text = if (state.draft_badge) style.accents(state.appearance.mode)[state.draft_accent] else P.text,
            });
        }
        if (dvui.button(@src(), "Guardar apariencia", .{}, .{
            .color_fill = P.accent, .color_text = P.on_accent, .corners = .round(10), .margin = .{ .y = 10 },
        })) try state.saveColumn(a);
    } else {
        dvui.label(@src(), "Visibilidad", .{}, .{ .color_text = P.muted });
        if (dvui.button(@src(), if (state.columns[selected].visible) "Visible - ocultar" else "Oculta - mostrar", .{}, .{
            .color_fill = P.elevated, .corners = .round(9), .margin = .{ .y = 5 },
        })) state.toggleVisible(selected);
        dvui.label(@src(), "Ordenar", .{}, .{ .color_text = P.muted });
        {
            var orders = dvui.box(@src(), .{ .dir = .horizontal }, .{ .margin = .{ .y = 7 } });
            defer orders.deinit();
            if (dvui.button(@src(), "Ascendente", .{}, .{
                .color_fill = if (state.filter.sort_column == selected and state.filter.sort_order == .asc) P.accent_soft else P.elevated,
                .corners = .round(8), .padding = .all(6),
            })) {
                if (state.filter.setSort(selected, .asc)) state.page = 0;
            }
            if (dvui.button(@src(), "Descendente", .{}, .{
                .color_fill = if (state.filter.sort_column == selected and state.filter.sort_order == .desc) P.accent_soft else P.elevated,
                .corners = .round(8), .padding = .all(6),
            })) {
                if (state.filter.setSort(selected, .desc)) state.page = 0;
            }
        }
        if (dvui.button(@src(), "Quitar orden", .{}, .{
            .color_fill = P.elevated, .corners = .round(9), .margin = .{ .y = 4 },
        })) {
            if (state.filter.setSort(null, .asc)) state.page = 0;
        }
        dvui.label(@src(), "Filtrar esta columna", .{}, .{ .color_text = P.muted });
        const operators = [_]struct { op: search.Predicate, title: []const u8 }{
            .{ .op = .contains, .title = "Contiene" },
            .{ .op = .equals, .title = "Igual" },
            .{ .op = .starts_with, .title = "Empieza" },
            .{ .op = .greater, .title = ">" },
            .{ .op = .less, .title = "<" },
            .{ .op = .empty, .title = "Vacio" },
            .{ .op = .not_empty, .title = "No vacio" },
        };
        {
            var ops = dvui.box(@src(), .{ .dir = .horizontal }, .{ .margin = .{ .y = 4 } });
            defer ops.deinit();
            for (operators[0..3], 0..) |opt, index| {
                if (dvui.button(@src(), opt.title, .{}, .{
                    .id_extra = index,
                    .color_fill = if (state.filter_op_draft == opt.op) P.accent_soft else P.elevated,
                    .padding = .all(5), .corners = .round(8),
                })) state.filter_op_draft = opt.op;
            }
        }
        {
            var ops = dvui.box(@src(), .{ .dir = .horizontal }, .{ .margin = .{ .y = 4 } });
            defer ops.deinit();
            for (operators[3..], 0..) |opt, index| {
                if (dvui.button(@src(), opt.title, .{}, .{
                    .id_extra = index + 3,
                    .color_fill = if (state.filter_op_draft == opt.op) P.accent_soft else P.elevated,
                    .padding = .all(5), .corners = .round(8),
                })) state.filter_op_draft = opt.op;
            }
        }
        if (state.filter_op_draft != .empty and state.filter_op_draft != .not_empty) {
            var entry = dvui.textEntry(@src(), .{
                .placeholder = "Valor del filtro...",
                .text = .{ .array_list = .{
                    .backing = &state.filter_draft, .allocator = a, .limit = 256,
                } },
            }, .{
                .background = true, .color_fill = P.elevated, .color_border = P.border,
                .color_text = P.text, .border = .all(1), .corners = .round(10), .expand = .horizontal,
            });
            entry.deinit();
        }
        {
            var actions = dvui.box(@src(), .{ .dir = .horizontal }, .{ .margin = .{ .y = 8 } });
            defer actions.deinit();
            if (dvui.button(@src(), "Aplicar filtro", .{}, .{
                .color_fill = P.accent, .color_text = P.on_accent, .corners = .round(10), .padding = .all(8),
            })) {
                const op = state.filter_op_draft;
                if (try state.filter.setPredicate(a, selected, op, state.filter_draft.items)) state.page = 0;
            }
            if (dvui.button(@src(), "Quitar filtro", .{}, .{
                .color_fill = P.elevated, .corners = .round(10), .padding = .all(8),
            })) {
                if (try state.filter.setPredicate(a, null, .contains, "")) state.page = 0;
                state.filter_draft.clearRetainingCapacity();
            }
        }
        dvui.label(@src(), "Filtro y busqueda se combinan (AND).", .{}, .{ .color_text = P.muted });
        if (dvui.button(@src(), "Buscar solo aqui", .{}, .{
            .color_fill = P.elevated, .corners = .round(10), .margin = .{ .y = 8 },
        })) {
            if (state.filter.setScope(selected)) state.page = 0;
        }
    }
    if (dvui.button(@src(), "Cerrar panel", .{}, .{
        .color_fill = P.elevated, .corners = .round(11), .padding = .all(8), .margin = .{ .y = 9 },
    })) state.selected_column = null;
    dvui.label(@src(), "El CSV original no se modifica.", .{}, .{ .color_text = P.muted });
}

pub fn appFrame() !dvui.App.Result {
    dvui.currentWindow().themeSet(style.themeFor(state.appearance.mode));
    const P = style.palette(state.appearance);
    const a = dvui.currentWindow().gpa;
    var root = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = true,
        .color_fill = P.canvas,
    });
    defer root.deinit();

    try topBar(a);
    try searchPanel(a);
    appearancePanel();
    try pathBar(a);
    summaryBar();

    // At most 8,192 rows per frame. DVUI schedules the next frame only while
    // the scan is incomplete, so mouse/keyboard events remain responsive.
    if (state.dataset) |*ds| {
        if (!state.filter.complete) {
            state.filter.advance(a, ds.rows, if (state.filter.sorting) search.sort_budget else search.scan_budget) catch |err| {
                std.log.err("Error de memoria al buscar: {}", .{err});
                state.status = "La busqueda se interrumpio: memoria insuficiente.";
                state.filter.complete = true;
            };
            if (!state.filter.complete) dvui.refresh(null, @src(), null);
        }
    }

    {
        var center = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .both });
        defer center.deinit();
        try dataTable(a);
        try columnsPanel(a);
        scopesPanel();
        try columnPanel(a);
    }
    pageBar();
    return .ok;
}
