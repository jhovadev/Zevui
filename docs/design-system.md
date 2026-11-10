# Zevui Design System (DVUI)

**Status: M0.4, experimental.** This is an adapter-specific component library
for the CSV Reader, not part of the Zig Data Engine runtime.

## Layers and import rules

```text
framework/src/ui/tokens.zig       pure Zig, no DVUI, tested headlessly
  ├── framework/src/ui/hooks.zig  explicit pointers to persistent application state
  └── framework/src/ui/dvui_style.zig      color tokens -> DVUI ColorOrGradient
        └── framework/src/ui/components.zig      semantic controls, forwarding @src()

examples/csv-explorer/src/main.zig             view, state, events, CSV reader
examples/csv-explorer/src/csv.zig              CSV-specific semantics + zdata primitives
```

Consumers can import `const tokens = @import("zevui").ui.tokens;`; standalone
headless tests can import `framework/src/ui/tokens.zig` directly. UI
modules are not exposed through ZData; the general-purpose SDK remains free of
DVUI, fonts, OS windowing and SDL3.

## Themes, accents and density

- Themes: `graphite` (default), `light`, `contrast`. Color pairs are checked for
  a minimum 4.5:1 contrast ratio on the main text, muted text and accent text.
  These are token-level checks; keyboard focus and actual rendered contrast
  still require GUI and accessibility testing.
- Accents: `lavender`, `coral`, `mint`, `sky`, `amber`.
- Density: `compact` (default), `comfortable`. It changes spacing in the top bar and
  data cells; responsive layout must still be tested at 780 / 1100 / 1390 px.
- Semantic colors (`positive`, `negative`, `warning`) are separate from brand
  colors, and should be used only for meaning.

The backend's `adwaita_dark`/`adwaita_light` supplies default font and focus
styles; explicit `dvui.ColorOrGradient` options use the ZData tokens. Contrast
mode currently selects the dark Adwaita base + high contrast token palette.
This **does not imply OS high-contrast accessibility integration**.

## State handles (not React hooks)

```zig
var appearance: tokens.Appearance = .{};
const theme = hooks.useTheme(&appearance);
theme.cycle();               // Graphite -> Light -> Contrast -> Graphite
theme.nextAccent();          // Lavender -> Coral -> ...
theme.toggleDensity();
const p = theme.current();   // pure tokens, no backend dependency
```

`useTheme` returns a lightweight handle containing an explicit pointer, with
**no hidden allocation, lifecycle, scheduling or effect execution**. State
must be owned by the app and outlive the handle. `useDisclosure(&bool)` provides
a similar helper for a local panel. UI input callbacks directly mutate the
state and call `dvui.refresh` if they need an immediate redraw.

## Components and widget identity

`ui.action(@src(), "Guardar", .primary, palette)` centralizes button styling.
Always pass `@src()` from the caller, and use distinct call sites or DVUI's
`id_extra` for repeated widgets. A wrapper that hides a single `@src()` in
itself will reuse widget IDs and break focus/interaction.

## CSV Reader interactions

- Main toolbar: Zevui title, Open CSV, columns, search disclosure, path and appearance.
- Search disclosure: compact input and per-column scope, rendered only when requested.
- Appearance disclosure: theme, accent and density are separate from searching.
- Table: compact row-number gutter and source-row indices, plus alternating backgrounds.
- Page footer: pagination only when a dataset is open.
- Portable build (`-Dportable-gui=true`): native file dialogs are disabled;
  `Ruta` opens a path entry so users can still import a CSV file.
- Theme and density changes are **in-memory only**. Persistent settings,
  animation, custom fonts and WCAG-tested navigation are future work.

## Validation

```sh
zig build test
zig build test -Doptimize=ReleaseSafe
python3 -m unittest discover -s tests -v
just run
just run-portable
```

Use manual screenshots and keyboard checks on real Linux/Windows/macOS
sessions. Headless token tests do not prove a final pixel output or physical
keyboard accessibility.

See [`ui-guidelines.md`](ui-guidelines.md) for the visual hierarchy, screenshot checklist and width targets.

## Custom SVG icons and app branding

Zevui keeps editable toolbar SVGs in `framework/src/ui/assets/*.svg` and
`assets/branding/zevui.svg`. `framework/src/ui/icons.zig` converts small SVG icons into
TinyVG once during window initialization using `dvui.svgToTvg`; icon buttons
render TinyVG, not raster images. If a pinned DVUI build has no TinyVG support
(or conversion fails), actions remain accessible as labeled text buttons.

The native window/taskbar icon is `examples/csv-explorer/src/app/assets/zevui.png` via DVUI's
`App.Options.icon`. The Windows executable embeds
`assets/branding/zevui.ico` through the Win32 `.rc` resource file. SVG itself
is the editable source, **not** an OS-level icon binary.

Edit application identity in **`zevui.zon`** (window title, name,
organization, application identifier, version and window dimensions). The
`examples/csv-explorer/src/app/identity.zig` shim reads generated build options. When
rebranding the template, export the PNG into `examples/csv-explorer/src/app/assets/`, regenerate
the ICO from your SVG, and change the
Windows icon asset. For packaging macOS, create a `.icns` and `Info.plist` in
a later packaging step; cross compiling a Mach-O executable is insufficient.

### Why Zig embeds live under `src/`

Zig 0.17.1 enforces the root of each compilation module for `@embedFile`.
The GUI module starts at `examples/csv-explorer/src/main.zig`; the branding unit test starts at
`examples/csv-explorer/src/app/identity.zig`. The PNG therefore lives in `examples/csv-explorer/src/app/assets/`, inside
both allowed roots. Toolbar SVGs live in `framework/src/ui/assets/`,
within the Zevui SDK module. The CSV executable imports this module as
`@import("zevui")`, rather than embedding icons from outside its own root. The editable brand SVG and Windows ICO remain in `assets/branding/`.
Avoid `@embedFile("../../assets/...")`: it escapes the module root.


## M0.5 defaults from ZON

`zevui.zon` sets the default theme, accent, and density for newly started apps.
These compile-time defaults are passed as `zevui_config` to the CSV example;
all user interactions continue modifying the in-memory `tokens.Appearance`.
There is no automatic persistence yet, and ZON is **not** a user settings file.
