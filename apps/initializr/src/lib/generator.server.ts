/** Thin server adapter: all planning/rendering/ZIP bytes come from Initializr Core. */
import { readFile } from "node:fs/promises";
import { realpath, lstat } from "node:fs/promises";
import { relative, resolve, sep } from "node:path";
import { useKV } from "nitro/kv";
import type { Catalog } from "./types";
import {
  generateProject as generateFiles, normalizeProject, zipProject, requiredSources,
} from "../../../../packages/initializr-core/src/generator.js";
import { planProject, PlanError } from "../../../../packages/initializr-core/src/index.js";

export function repoRoot(): string {
  return resolve(process.env.ZEVUI_REPO_ROOT ?? resolve(process.cwd(), "../.."));
}

function packaged(): boolean {
  return process.env.VERCEL === "1" || process.env.ZEVUI_USE_PACKAGED_ASSETS === "1";
}

/** The Vercel function cannot rely on its build-time repository cwd. */
async function readReviewed(path: string): Promise<Uint8Array> {
  if (packaged()) {
    const key = path.replaceAll("/.gitignore", "/__gitignore");
    const raw = await useKV("assets:zevui").getItemRaw<Uint8Array>(key);
    if (raw == null) throw new GeneratorError(`Missing packaged source: ${path}`, 503);
    return typeof raw === "string" ? new TextEncoder().encode(raw) : new Uint8Array(raw);
  }
  return new Uint8Array(await readFile(resolve(repoRoot(), path)));
}

export async function readCatalog(): Promise<Catalog> {
  return JSON.parse(new TextDecoder().decode(await readReviewed("registry/catalog.json")));
}

export class GeneratorError extends Error {
  constructor(message: string, readonly status: number) { super(message); }
}

function randomFingerprintId(): number {
  let id = 0;
  while (id === 0 || id === 0xffffffff) id = crypto.getRandomValues(new Uint32Array(1))[0];
  return id;
}

/** Read only planner-declared repository sources, never paths from raw request input. */
async function loadSources(paths: string[]): Promise<Record<string, Uint8Array>> {
  const root = packaged() ? null : await realpath(repoRoot());
  const result: Record<string, Uint8Array> = Object.create(null) as Record<string, Uint8Array>;
  for (const source of [...new Set(paths)].sort()) {
    if (!/^[a-zA-Z0-9_.\/-]{1,255}$/.test(source) || source.split("/").some((part) => ["", ".", ".."].includes(part)))
      throw new GeneratorError("Invalid reviewed source path", 500);
    if (packaged()) {
      result[source] = await readReviewed(source);
      continue;
    }
    const full = resolve(root!, source);
    const actual = await realpath(full);
    const rel = relative(root!, actual);
    if (rel === "" || rel === ".." || rel.startsWith(".." + sep) || rel.startsWith(sep))
      throw new GeneratorError("Source outside repository", 500);
    if (!(await lstat(actual)).isFile()) throw new GeneratorError("Source is not a file", 500);
    result[source] = new Uint8Array(await readFile(actual));
  }
  return result;
}

export async function generateProject(request: unknown): Promise<Uint8Array> {
  const catalog = await readCatalog();
  const project = normalizeProject(request, catalog, randomFingerprintId());
  const plan = planProject(project, catalog);
  const sources = await loadSources(requiredSources(plan));
  return zipProject(generateFiles(project, catalog, sources));
}

export { PlanError };
