# Zevui CSV Explorer — UI guidelines (M0.3)

The GUI should act like a compact data inspector, not a spreadsheet clone.
The supplied Excel picture is a *functional reference* for tabular affordances,
not a request to replicate Microsoft's ribbon, branding or styling.

## Hierarchy

1. **Document toolbar:** Zevui identity, CSV Explorer title, open file, columns, manual path.
2. **Context toolbar:** flexible search entry, optional column scope, theme, accent and density.
3. **Dataset status:** filename, input rows, visible columns and matched rows.
4. **Work surface:** virtualized grid with a row-number gutter, headers and subtle alternating row colors.
5. **Navigation:** minimal first/previous/next/last and page-size readout when a dataset exists.

The empty state should never show a blank giant grid. It must provide real
Open file / Enter path actions. Avoid fictitious sample data or buttons that
require a fixture missing from a distributed executable.

## Spacing and themes

Use `tokens.spacing(state.appearance.density)` instead of hard-coded per-theme
spacing for row height and toolbar gutters. Compact is the default for a
data tool, comfortable remains selectable. Graphite, Light and Contrast are
session-only visual choices. Accents are purely decorative; success/warning/
error need their independent semantic palette colors.

The number gutter displays **source row numbers** (1-based data rows,
excluding the CSV header). Sorted and filtered views still show source row
numbers, which must not be confused with visible result rank.

## Keyboard, accessibility and layout review

Review at 780×520, 1100×720 and 1390×840, using each theme. Check that the
search entry and action buttons remain usable in the minimum width; DVUI's
input and focus behavior requires a genuine GUI review. No claim is made that
static color-contrast tests prove full accessibility.

Capture a real screenshot **after** loading `testdata/sample_1500.csv`, one
screenshot for the empty state and another for the table with a filter active.
Save them as e.g. `docs/screenshots/empty.png` and
`docs/screenshots/table.png` only when they reflect the shipped UI. Then add
those paths to README. Do not include Excel template images as actual app UI.

## Separation of responsibilities

`framework/src/ui/` contains no CSV decoding or SDK algorithms. `examples/csv-explorer/src/csv.zig` owns CSV
semantics, `examples/csv-explorer/src/search.zig` owns operations, and ZData provides generic
structural scanning. No data conversion or filtering runs as part of theme
changes; UI state changes request redraws through DVUI.

## M0.4 - Less chrome, more data

The search row is hidden until **Buscar** is selected. Search state remains
when the row is dismissed. The density toggle is inside **Apariencia**, no
longer beside or over the text entry. Check the toolbar at 780 px minimum
width and verify the column panel has no duplicate widget ID warnings.
