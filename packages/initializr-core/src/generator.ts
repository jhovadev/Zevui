/** The single production Zevui project generator. Pure: no fs, DOM, HTTP or Node APIs. */
import { planProject, PlanError, type Catalog, type Plan, type ProjectInput } from "./index.js";

export type BinaryFile = Uint8Array;
export type Sources = Readonly<Record<string, Uint8Array | string>>;
export interface GeneratedProject { plan: Plan; files: ReadonlyMap<string, BinaryFile> }

const encoder = new TextEncoder();
const UTF8 = 0x0800;
const FILE_MODE = 0o100644;
const ZIP_DATE = ((2026 - 1980) << 9) | (1 << 5) | 1;
const MAX_FILES = 512;
const MAX_ARCHIVE = 32 * 1024 * 1024;
const pathPattern = /^[a-zA-Z0-9_.\/-]+$/;

function safePath(path: string): boolean {
  return path.length > 0 && path.length < 256 && pathPattern.test(path) &&
    !path.startsWith("/") && !path.includes("//") &&
    path.split("/").every((part) => part !== "" && part !== "." && part !== "..");
}
function value(source: Uint8Array | string | undefined, path: string): Uint8Array {
  if (source === undefined) throw new PlanError("source", `Missing reviewed source: ${path}`);
  return typeof source === "string" ? encoder.encode(source) : new Uint8Array(source);
}
function zigString(input: string): string {
  // JSON quoted strings are compatible with Zig string literals for printable UTF-8.
  return JSON.stringify(input);
}
/** Normalize only documented optional input fields, then let the planner validate. */
export function normalizeProject(input: unknown, catalog: Catalog, fingerprintId: number): ProjectInput {
  if (!input || typeof input !== "object" || Array.isArray(input))
    throw new PlanError("input", "Expected a project JSON object");
  const p = input as Record<string, unknown>;
  for (const key of Object.keys(p)) {
    if (!["name", "title", "organization", "version", "addons", "zig", "target", "fingerprintId"].includes(key))
      throw new PlanError("input", `Unknown project field: ${key}`);
  }
  return {
    name: (p.name ?? "my-zevui-app") as string,
    title: (p.title ?? "My Zevui App") as string,
    organization: (p.organization ?? "dev.example") as string,
    version: (p.version ?? "0.1.0") as string,
    addons: (p.addons ?? ["design_tokens"]) as string[],
    zig: (p.zig ?? catalog.zig) as string,
    target: (p.target ?? "linux") as string,
    fingerprintId: (p.fingerprintId ?? fingerprintId) as number,
  };
}

function renderBuild(addons: string[]): string {
  const entries = addons.map((id) => `, "src/addons/${id}.zig"`).join("");
  return `const std = @import("std");
const zevui = @import("zevui/build.zig");

pub fn build(b: *std.Build) void {
    const cfg: zevui.Config = @import("zevui.zon");
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const portable = b.option(bool, "portable-gui", "Disable optional DVUI native dependencies") orelse false;
    const windows_console = b.option(bool, "windows-console", "Enable Windows debug console") orelse false;
    _ = zevui.addApp(b, cfg, .{
        .target = target,
        .optimize = optimize,
        .root_source_file = "src/main.zig",
        .portable_gui = portable,
        .windows_console = windows_console,
    });
    const tests = b.step("test", "Run Zevui configuration and addon tests");
    inline for (.{ "zevui/config.zig"${entries} }) |path| {
        const unit = b.addTest(.{ .root_module = b.createModule(.{
            .root_source_file = b.path(path), .target = target, .optimize = optimize,
        }) });
        tests.dependOn(&b.addRunArtifact(unit).step);
    }
}
`;
}
function renderZon(plan: Plan): string {
  const p = plan.project;
  return `.{
    .identity = .{
        .name = ${zigString(p.name)},
        .title = ${zigString(p.title)},
        .display_name = ${zigString(p.title)},
        .short_name = "APP",
        .screen_name = "Home",
        .version = ${zigString(p.version)},
        .organization = ${zigString(p.organization)},
        .application = ${zigString(p.name)},
    },
    .window = .{ .width = 1100, .height = 720, .min_width = 640, .min_height = 480 },
    .appearance = .{ .theme = "graphite", .accent = "lavender", .density = "compact" },
    .modules = .{ .zdata = false },
}
`;
}
function renderManifest(plan: Plan): string {
  const p = plan.project;
  const dvui = plan.dependencies.dvui;
  if (!plan.fingerprint || !dvui) throw new PlanError("pin", "Missing fingerprint or reviewed DVUI pin");
  const name = p.name.replaceAll("-", "_");
  return `.{
    .name = .${name},
    .version = ${zigString(p.version)},
    .fingerprint = ${plan.fingerprint},
    .minimum_zig_version = ${zigString(p.zig ?? "0.17.1")},
    .dependencies = .{
        .dvui = .{
            .url = ${zigString(dvui.url)},
            .hash = ${zigString(dvui.hash)},
        },
    },
    .paths = .{ "" },
}
`;
}
function addonImports(plan: Plan, catalog: Catalog): { source: string; docs: string[] } {
  const addons = new Set(plan.resolvedAddons);
  const lines: string[] = [];
  const docs: string[] = [];
  for (const addon of catalog.addons) {
    const id = addon.id;
    if (!addons.has(id)) continue;
    for (const mapping of addon.files) {
      const rel = mapping.to.replace(/^src\//, "");
      if (id === "memory_store") {
        lines.push('comptime { _ = @import("addons/memory_store.zig").MemoryStore(64, 96, 1024); }');
        docs.push('Memory Store: @import("addons/memory_store.zig").MemoryStore(64, 96, 1024)');
      } else {
        lines.push(`comptime { _ = @import(${zigString(rel)}); }`);
        docs.push(`${addon.name}: @import(${zigString(rel)})`);
      }
    }
  }
  return { source: lines.map((line) => `\n${line}\n`).join(""), docs };
}
function renderReadme(plan: Plan, docs: string[]): string {
  return `# ${plan.project.title}\n\nGenerated with **Zevui Initializr** (Zig ${plan.project.zig} / DVUI + SDL3).\n\n` +
    'This is a standalone Zig project; no Zevui CLI or Python is needed to build.\n\n' +
    '```sh\nzig build\nzig build run\nzig build -Dportable-gui=true\n```\n\n' +
    'Addons:\n' + docs.map((line) => `- ${line}\n`).join("") + '\n' +
    'The SDL3 GUI may require native graphics libraries/SDKs for your target.\n' +
    'Windows uses the GUI subsystem by default; `-Dwindows-console=true` enables a debug console.\n' +
    'Generated from the M0.5 local Build Core; the Zevui package is not yet published.\n';
}
/** Every emitted path must occur in the exact same canonical planner operations. */
export function generateProject(input: ProjectInput, catalog: Catalog, sources: Sources): GeneratedProject {
  const plan = planProject(input, catalog);
  if (!plan.fingerprint) throw new PlanError("fingerprint", "Supply a non-reserved fingerprintId");
  const addon = addonImports(plan, catalog);
  const generated: Record<string, Uint8Array> = {
    "build.zig": encoder.encode(renderBuild(plan.resolvedAddons)),
    "build.zig.zon": encoder.encode(renderManifest(plan)),
    "zevui.zon": encoder.encode(renderZon(plan)),
    "README.md": encoder.encode(renderReadme(plan, addon.docs)),
    ".gitignore": encoder.encode(".zig-cache/\nzig-out/\ndist/\n"),
    "src/main.zig": (() => {
      const base = value(sources["templates/compat/minimal/main.zig"], "templates/compat/minimal/main.zig");
      const suffix = encoder.encode(addon.source);
      const result = new Uint8Array(base.length + suffix.length);
      result.set(base); result.set(suffix, base.length);
      return result;
    })(),
  };
  const files = new Map<string, Uint8Array>();
  if (plan.operations.length > MAX_FILES) throw new PlanError("size", "Too many planned files");
  let size = 0;
  for (const op of plan.operations) {
    if (!safePath(op.path) || files.has(op.path)) throw new PlanError("path", `Unsafe or repeated output path: ${op.path}`);
    const content = op.kind === "copy" ? value(sources[op.source!], op.source!) : generated[op.path];
    if (!content) throw new PlanError("plan", `No renderer for ${op.path}`);
    size += content.length;
    if (size > MAX_ARCHIVE) throw new PlanError("size", "Project exceeds size limit");
    files.set(op.path, content);
  }
  return { plan, files };
}

function crc32(data: Uint8Array): number {
  let crc = 0xffffffff;
  for (const v of data) {
    crc ^= v;
    for (let i = 0; i < 8; i++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function u16(buf: Uint8Array, offset: number, value: number): void {
  new DataView(buf.buffer, buf.byteOffset, buf.byteLength).setUint16(offset, value, true);
}
function u32(buf: Uint8Array, offset: number, value: number): void {
  new DataView(buf.buffer, buf.byteOffset, buf.byteLength).setUint32(offset, value >>> 0, true);
}
function join(parts: Uint8Array[], length: number): Uint8Array {
  const out = new Uint8Array(length);
  let pos = 0;
  for (const part of parts) { out.set(part, pos); pos += part.length; }
  return out;
}
/** Deterministic, dependency-free ZIP STORE encoder (method 0, no ZIP64). */
export function zipProject(generated: GeneratedProject): Uint8Array {
  const root = generated.plan.project.name;
  if (!safePath(root)) throw new PlanError("path", "Invalid archive root");
  const sorted = [...generated.files].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0);
  if (sorted.length > MAX_FILES) throw new PlanError("size", "Too many ZIP entries");
  const parts: Uint8Array[] = [], central: Uint8Array[] = [];
  let length = 0, centerSize = 0;
  for (const [path, bytes] of sorted) {
    if (!safePath(path)) throw new PlanError("path", `Invalid archive path: ${path}`);
    const name = encoder.encode(`${root}/${path}`);
    if (name.length > 0xffff) throw new PlanError("path", "ZIP filename too long");
    const crc = crc32(bytes);
    const localOffset = length;
    const local = new Uint8Array(30 + name.length);
    u32(local, 0, 0x04034b50); u16(local, 4, 20); u16(local, 6, UTF8);
    u16(local, 8, 0); u16(local, 10, 0); u16(local, 12, ZIP_DATE);
    u32(local, 14, crc); u32(local, 18, bytes.length); u32(local, 22, bytes.length);
    u16(local, 26, name.length); u16(local, 28, 0); local.set(name, 30);
    parts.push(local, bytes); length += local.length + bytes.length;
    const cd = new Uint8Array(46 + name.length);
    u32(cd, 0, 0x02014b50); u16(cd, 4, 0x0314); u16(cd, 6, 20);
    u16(cd, 8, UTF8); u16(cd, 10, 0); u16(cd, 12, 0); u16(cd, 14, ZIP_DATE);
    u32(cd, 16, crc); u32(cd, 20, bytes.length); u32(cd, 24, bytes.length);
    u16(cd, 28, name.length); u16(cd, 30, 0); u16(cd, 32, 0);
    u16(cd, 34, 0); u16(cd, 36, 0); u32(cd, 38, FILE_MODE << 16);
    u32(cd, 42, localOffset); cd.set(name, 46);
    central.push(cd); centerSize += cd.length;
    if (length + centerSize > MAX_ARCHIVE) throw new PlanError("size", "ZIP exceeds size limit");
  }
  const eocd = new Uint8Array(22);
  u32(eocd, 0, 0x06054b50); u16(eocd, 4, 0); u16(eocd, 6, 0);
  u16(eocd, 8, sorted.length); u16(eocd, 10, sorted.length);
  u32(eocd, 12, centerSize); u32(eocd, 16, length); u16(eocd, 20, 0);
  return join([...parts, ...central, eocd], length + centerSize + eocd.length);
}
