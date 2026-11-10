# Cross-compiling ZData CSV Reader

This template uses the upstream **Zig 0.17.1 build system**, the DVUI SDL3 backend
and the publicly fetched ZData package. `just` is a developer convenience layer;
it does not provide a compiler or SDK. The target list below represents **build
recipes offered, not verified release artifacts**.

## Prerequisites

**M0.2 update:** `just cross` now enables `-Dportable-gui=true` and performs a
read-only `scripts/sdk_doctor.py --require-build` check first. This profile
omits optional native dialogs, FreeType and Tree-sitter integration. Opening a
CSV by typing a path remains available. For macOS, run the GUI build from a
macOS host with an authorized Apple SDK; pure headless tests still cross compile.
See [platform SDK guide](platform-sdks.md) for per-OS details.


- Zig 0.17.1 (`zig version`); `just` (for the recipes); Python 3 for static checks.
- Run `just setup` once, then **commit the pinned `build.zig.zon`**. CI must not
  fetch a moving `main` branch on every run.
- A working C toolchain / platform SDK for the *transitive DVUI + SDL3 backend*
  when required. Zig cross-compiles many C sources, but this alone doesn't
  provide every target's frameworks, native libraries, runtime or distribution
  packaging requirements.
- Available RAM, disk space and internet for fetching the pinned dependencies.

## Pick a target

| Recipe | Zig target | Result | Caveat |
| --- | --- | --- | --- |
| `just linux-x64` | `x86_64-linux-gnu` | ELF executable | Validate libc baseline and system graphics |
| `just linux-arm64` | `aarch64-linux-gnu` | ELF executable | Needs ARM64 run/CI verification |
| `just windows-x64` | `x86_64-windows-gnu` | Windows executable | SDL3 backend and DLL packaging must be checked |
| `just windows-arm64` | `aarch64-windows-gnu` | Windows executable | Toolchain/runtime support must be checked |
| `just macos-x64` | `x86_64-macos` | macOS executable | Apple SDK/frameworks; code signing/notarization not provided |
| `just macos-arm64` | `aarch64-macos` | macOS executable | Apple SDK/frameworks; code signing/notarization not provided |

**No platform in this matrix has yet been verified as a distributed release.**
The native Linux environment used for the CSV prototype is not evidence of
Windows or macOS support. Use a matching-OS CI runner or physical/virtual machine
to run GUI smoke tests after compilation.

## Commands

```sh
just targets
just sdk-doctor x86_64-windows-gnu
just sdk-doctor aarch64-macos

# Headless parser/search Zig test binaries: compile for ARM64, never execute.
just cross-headless aarch64-linux-gnu

# Full native DVUI/SDL3 executable for Windows x86-64.
just windows-x64
# Same command using an explicit triple:
just cross x86_64-windows-gnu

# Native quick checks (these actually run, on your host):
just check
just run
```

A full build for target `T` uses `zig build -Dtarget=T -Doptimize=ReleaseFast
--prefix dist/T`; the produced files are under `dist/T/bin/`. The prefix is
unique per target to avoid overwriting the last build. `dist/` is ignored by
Git and is **not** a validated release bundle.

To get only the headless compilation signal from CI, `zig build test-compile
-Dtarget=T` uses the parser and search test compile steps; it does **not** run
them. Running `zig build test -Dtarget=T` on your local host is *not* a
meaningful cross-platform test: it attempts to execute a foreign binary.

## How to verify a cross build properly

1. Compile for the target and record Zig version, target triple, SDK and SDL3
   dependency revisions.
2. Inspect `dist/<target>/bin/`; check expected executable type. Confirm DLL/
   shared-library dependencies and fonts/graphics/runtime availability.
3. Run it on the **target OS/architecture** (or a compatible runner), open
   `testdata/sample_1500.csv`, filter, sort numeric, toggle column visibility,
   open another file and close normally.
4. Run the same parser/search tests on that target if your runner can execute
   them, and compare the end-to-end benchmark to the native baseline.
5. Only then mark the target verified in your release documentation.

`just cross` does not download or copy a macOS SDK. On a non-macOS host, it
will now stop before attempting a macOS GUI build and explain what is missing.
 Windows cross compilation
may work for a given pinned SDL3 dependency without external setup, but must
be tested; treat a link or translation error as a backend/toolchain issue until
identified. For macOS, see DVUI's own SDK-header and framework handling.

## See also

- [Zig build system documentation](https://ziglang.org/intro/build-system/)
- [DVUI README and troubleshooting](https://github.com/david-vanderson/dvui)
- [Just command runner](https://just.systems/)

## Windows: graphical subsystem and icon

The GUI is linked with `app.subsystem = .windows` for Windows targets. The
standalone benchmark remains a console executable. A Win32 resource embeds
`assets/branding/zevui.ico` in the PE file.

After a successful cross-build:

```bash
just windows-x64
just windows-gui-check
```

`windows-gui-check` inspects the PE optional header (subsystem `2` = GUI),
but **does not prove** that the application runs correctly on Windows. Use
`just windows-console-debug` for an intentionally console-enabled diagnostic
build, then run that executable in Windows to capture SDL/DVUI logs.

The Win32 icon and default GUI subsystem are independent of macOS/Linux icon
packaging. Windows desktop runtime validation is still required.
