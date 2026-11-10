/** Pure Zevui Initializr planner. No filesystem, DOM, Zig compiler or network calls. */
export type Status = "available" | "manual" | "planned";
export interface FileMapping { from: string; to: string }
export interface Addon {
  id: string; name: string; category: string; description: string;
  status: Status; default: boolean;
  kind: "zig" | "c-bundled" | "c-system" | "planned";
  requires: string[]; conflicts: string[]; targets: string[];
  zig: string[]; zevui: string; trust: string; license: string;
  files: FileMapping[];
}
export interface Catalog {
  schemaVersion: number; registryVersion: string; zig: string;
  supportedZig: string[]; framework: string;
  packages: Record<string, { url: string; hash: string }>;
  addons: Addon[];
}
export interface ProjectInput {
  name: string; title: string; organization: string; version: string;
  addons: string[]; zig?: string; target?: string; fingerprintId?: number;
}
export interface FileOperation {
  kind: "copy" | "render"; path: string; source?: string;
}
export interface Plan {
  schemaVersion: 1; project: Readonly<ProjectInput>;
  resolvedAddons: string[]; dependencies: Record<string, { url: string; hash: string }>;
  operations: FileOperation[]; fingerprint: string | null;
}
export class PlanError extends Error {
  constructor(readonly code: string, message: string) { super(message); this.name = "PlanError"; }
}
const NAME = /^[a-z][a-z0-9_-]{1,31}$/;
const ORG = /^[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*)+$/;
const VER = /^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$/;
const ID = /^[a-z][a-z0-9_-]{1,63}$/;
const PATH = /^[a-zA-Z0-9_.\/-]+$/;
const TARGETS = new Set(["linux", "windows", "macos"]);
function err(code: string, message: string): never { throw new PlanError(code, message); }
function safePath(path: string): boolean {
  return path.length < 256 && PATH.test(path) && !path.startsWith("/") &&
    !path.includes("//") && path.split("/").every((v) => v !== "." && v !== ".." && v !== "");
}
/** Same CRC32-IEEE algorithm used for the upper Zig package fingerprint u32. */
export function zigFingerprint(name: string, id: number): string {
  if (!Number.isInteger(id) || id <= 0 || id >= 0xffff_ffff) err("fingerprint", "Invalid fingerprint identifier");
  let crc = 0xffff_ffff;
  for (const byte of new TextEncoder().encode(name)) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  const high = (crc ^ 0xffff_ffff) >>> 0;
  return `0x${high.toString(16).padStart(8, "0")}${id.toString(16).padStart(8, "0")}`;
}
/** Validate registry data before consuming any addon-declared paths/dependencies. */
export function validateCatalog(catalog: Catalog): void {
  if (catalog.schemaVersion !== 2 || !Array.isArray(catalog.addons) ||
      !Array.isArray(catalog.supportedZig) || !catalog.supportedZig.includes(catalog.zig))
    err("registry", "Unsupported registry schema or Zig version");
  if (!catalog.packages?.dvui || !/^dvui-/.test(catalog.packages.dvui.hash) ||
      !/^git\+https:\/\//.test(catalog.packages.dvui.url))
    err("registry", "Missing reviewed DVUI package pin");
  const ids = new Set<string>();
  for (const addon of catalog.addons) {
    if (!ID.test(addon.id) || ids.has(addon.id)) err("registry", "Invalid or duplicate addon ID");
    ids.add(addon.id);
    if (!["available", "manual", "planned"].includes(addon.status) ||
        !Array.isArray(addon.requires) || !Array.isArray(addon.conflicts) ||
        !Array.isArray(addon.targets) || !Array.isArray(addon.zig) || !Array.isArray(addon.files))
      err("registry", `Invalid fields for ${addon.id}`);
    for (const path of addon.files) {
      if (!safePath(path.from) || !safePath(path.to) || !path.to.startsWith("src/addons/"))
        err("path", `Unsafe addon file mapping in ${addon.id}`);
    }
    if (addon.status !== "available" && addon.files.length !== 0)
      err("registry", `Unavailable addon cannot include source files: ${addon.id}`);
  }
  for (const addon of catalog.addons) {
    for (const ref of [...addon.requires, ...addon.conflicts]) {
      if (!ids.has(ref)) err("registry", `Unknown addon reference ${ref}`);
    }
  }
}
/** Resolve requirements, reject incompatible combos, and emit a stable file plan. */
export function planProject(project: ProjectInput, catalog: Catalog): Plan {
  validateCatalog(catalog);
  if (!project || !NAME.test(project.name) || !ORG.test(project.organization) ||
      !VER.test(project.version) || typeof project.title !== "string" ||
      project.title.length < 1 || project.title.length > 80 || /[\x00-\x1f]/.test(project.title))
    err("input", "Invalid project identity; check name, title, organization and version");
  if (!Array.isArray(project.addons) || project.addons.length > 32 ||
      project.addons.some((id) => typeof id !== "string") ||
      new Set(project.addons).size !== project.addons.length)
    err("input", "Invalid or repeated addons");
  const zig = project.zig ?? catalog.zig;
  if (!catalog.supportedZig.includes(zig)) err("zig", `Unsupported Zig version: ${zig}`);
  const target = project.target ?? "linux";
  if (!TARGETS.has(target)) err("target", `Unsupported target: ${target}`);
  const addons = new Map(catalog.addons.map((a) => [a.id, a]));
  const visiting = new Set<string>(), resolved = new Set<string>();
  const visit = (id: string): void => {
    const addon = addons.get(id);
    if (!addon) err("addon", `Unknown addon: ${id}`);
    if (addon.status !== "available") err("addon", `Addon not available: ${id}`);
    if (!addon.zig.includes(zig) || !addon.targets.includes(target))
      err("compatibility", `Addon ${id} does not support Zig ${zig} on ${target}`);
    if (visiting.has(id)) err("cycle", `Addon dependency cycle at ${id}`);
    if (resolved.has(id)) return;
    visiting.add(id);
    for (const requirement of [...addon.requires].sort()) visit(requirement);
    visiting.delete(id);
    resolved.add(id);
  };
  for (const id of [...project.addons].sort()) visit(id);
  const ids = [...resolved].sort();
  for (const id of ids) {
    const addon = addons.get(id)!;
    const conflict = addon.conflicts.find((other) => resolved.has(other));
    if (conflict) err("conflict", `${id} conflicts with ${conflict}`);
  }
  const files: FileOperation[] = [
    { kind: "render", path: "build.zig" }, { kind: "render", path: "build.zig.zon" },
    { kind: "render", path: "zevui.zon" }, { kind: "render", path: "README.md" },
    { kind: "render", path: ".gitignore" }, { kind: "render", path: "src/main.zig" },
    { kind: "copy", path: "zevui/build.zig", source: "templates/compat/zevui/build.zig" },
    { kind: "copy", path: "zevui/config.zig", source: "templates/compat/zevui/config.zig" },
  ];
  for (const id of ids) for (const file of addons.get(id)!.files)
    files.push({ kind: "copy", path: file.to, source: file.from });
  const destinations = new Set<string>();
  for (const file of files) {
    if (!safePath(file.path) || destinations.has(file.path))
      err("collision", `Unsafe or duplicate output path: ${file.path}`);
    destinations.add(file.path);
  }
  const fp = project.fingerprintId === undefined ? null :
    zigFingerprint(project.name.replaceAll("-", "_"), project.fingerprintId);
  return {
    schemaVersion: 1,
    project: { name: project.name, title: project.title, organization: project.organization,
      version: project.version, zig, target, addons: [...project.addons].sort(),
      ...(project.fingerprintId === undefined ? {} : { fingerprintId: project.fingerprintId }) },
    resolvedAddons: ids,
    dependencies: { dvui: { ...catalog.packages.dvui } },
    operations: files.sort((a, b) => a.path.localeCompare(b.path, "en")),
    fingerprint: fp,
  };
}
