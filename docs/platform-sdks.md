# Platform SDKs for ZData CSV Reader (DVUI + SDL3)

Zig can emit code for multiple CPUs and OS targets, but **a target triple is not
an entire desktop SDK**. DVUI uses SDL3 for windows, input and rendering; SDL3
may compile C and link system frameworks. We do not use Zero Native as a GUI
backend, and we do not download proprietary SDKs automatically.

## Preflight

```sh
just sdk-doctor x86_64-windows-gnu
just sdk-doctor aarch64-macos
just cross-headless aarch64-linux-gnu
just build-portable
```

`just cross` runs `sdk_doctor.py --require-build` first. It stops early for a
macOS GUI build attempted on Linux/Windows, with an explanation. **Headless
cross-test compilation is still allowed**: the parser and design tokens do not
require macOS frameworks.

## Host and target matrix

| Build target | Recommended host | SDK / build input | Runtime verification |
| --- | --- | --- | --- |
| Linux x86_64, aarch64 | Linux host, or Zig cross C toolchain | Linux GNU libc via Zig; SDL3 Zig build and system libraries as needed | X11/Wayland or headless compositor, OpenGL/driver compatibility, GLIBC baseline |
| Windows x86_64/ARM64 GNU | Linux or Windows with Zig 0.17.1 | Zig's GNU target + SDL3 source build; test linkage, do not assume Win32 dependencies are statically packaged | Native Windows session, renderer, IME, font, dialogs, DLL dependencies |
| macOS x86_64/ARM64 | macOS runner with Xcode/CLT | Apple macOS SDK discovered with `xcrun --sdk macosx --show-sdk-path`; AppKit, Foundation and required frameworks | Both architectures, application bundle, signing/notarization when distributing |

Windows `.gnu` and `.msvc` are distinct ABIs: these recipes currently use
`-gnu`. Having Zig or a Windows SDK installed does not certify Windows ARM64
compatibility. On macOS, SDK headers and frameworks are governed by Apple's
licensing; use an authorized macOS runner instead of bundling them in the repo.

### Linux / Arch

```sh
sudo pacman -S --needed just python zig
just doctor
just run
just build-portable
just windows-x64
```

Use your existing `mise` Zig 0.17.1 instead of `pacman` Zig if you want to match
the pinned compiler. Packaging an ELF may still need system libraries and
renderer drivers; a compiled binary is not automatically self-contained.

### Windows (native validation)

Use the Zig 0.17.1 Windows distribution and a supported shell to run `zig build`.
The Just recipes use Bash, which requires Git Bash/MSYS2/WSL, so Windows CI
runs Zig and Python directly. Verify the SDL renderer on a real Windows host.
The portable profile does not use native dialogs; enter a CSV path manually.

### macOS (SDK-required)

```sh
xcode-select -p
xcrun --sdk macosx --show-sdk-path
zig build -Dtarget=aarch64-macos -Dportable-gui=true -Doptimize=ReleaseFast
```

This works only if DVUI/SDL3's pinned build supports that host SDK and target.
For cross-architecture builds on macOS, verify the output on the corresponding
hardware or runner; notarization and universal `.app` bundles are separate.

## Portable profile tradeoff

`-Dportable-gui=true` disables optional FreeType, Tree-sitter and Tiny File
Dialogs integration. It **does not remove SDL3** and does not imply that all
static or runtime libraries disappear. The app provides a path-based import
fallback. If a cross-build fails, capture the exact compiler/linker error,
`zig version`, `target`, and the DVUI/SDL3 package hashes before changing flags.

## Why not zero-native / Native SDK as the backend?

[Native SDK](https://zero-native.dev/) is a distinct application toolkit with
native markup and typed state; its design-token and message-driven DX are
useful inspirations, but replacing DVUI would change rendering, widget APIs,
build topology and tests. We retain the verified DVUI/SDL3 code path and borrow
only architectural ideas. See [design system](design-system.md).
