# Troubleshooting

## Invalid `fingerprint` in build.zig.zon

Use Zig **0.17.1**, and apply the
[packaging hotfix](../README.md) if you started from the older ZIP. The
manifest's `.fingerprint` should be `0x525d57945f45ed28`. Do **not** copy a
fingerprint from a different package name.

## `no dependency named 'zdata'` or layout check asks for setup

Run `just setup` (or `zig fetch --save=zdata
 git+https://github.com/jhovadev/zigdataengine.git`), then inspect and commit
`build.zig.zon`. If you already pinned an SDK revision, do not run setup again
unless you intentionally want to change it.

## No Wayland / no video device / blank window

Headless parser and search tests do not require a display, but DVUI/SDL3 does.
Check your window-system environment, GPU drivers and the SDL3 backend
configuration. On some Linux installations, the DVUI project documents
`-Dlinux_display_backend=X11` as a fallback. The appropriate runtime libraries
vary by distribution; check the upstream DVUI troubleshooting guide.

## Cross compilation fails on another OS

Try `just cross-headless <target>` first. If that succeeds but `just cross
<target>` fails, inspect the DVUI/SDL3 backend build, C translation and link
errors. For macOS you may need Apple SDK headers/frameworks; this template
neither ships an SDK nor signs an app. Don't mark a target supported from
compiler success alone.

## `just` is missing

On Arch Linux: `sudo pacman -S just`. Or run Zig directly:

```sh
zig build test -Doptimize=ReleaseSafe
zig build sdl3-app -Doptimize=ReleaseFast
zig build -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseFast --prefix dist/x86_64-windows-gnu
```

## Keeping generated data out of Git

`.gitignore` excludes Zig build/cache directories, `dist/` and other generated
files. Keep only the synthetic CSV fixture under `testdata/`; do not add
production customer files or private CSVs.

## Mac cross build fails before compilation

`just macos-arm64` and `just macos-x64` require a macOS host/runner with the
Apple macOS SDK. Run `just sdk-doctor aarch64-macos` for diagnostics, then
`xcrun --sdk macosx --show-sdk-path` on that Mac. Do not fetch unlicensed SDK
copies as a workaround. You can still run `just cross-headless aarch64-macos`
from Linux to compile pure Zig tests.

## Portable GUI runs, but the native file dialog is missing

This is expected for `-Dportable-gui=true`: it intentionally omits the Tiny
File Dialogs integration and other optional dependencies. Click **Ruta** and
enter the local CSV path. Use `just run` for the regular native build.

## Theme looks different from system dark mode

The three named themes are selected explicitly in the application. Only
adwaita light/dark supplies default font and focus styles; our token palette
styles individual controls. Theme selection is not yet persisted.
