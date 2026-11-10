/** Thin server adapter: all planning/rendering/ZIP bytes come from Initializr Core. */
import { readFile } from "node:fs/promises";
import { realpath, lstat } from "node:fs/promises";
import { relative, resolve, sep } from "node:path";
import type { Catalog } from "./types";
import {
  generateProject as generateFiles, normalizeProject, zipProject, requiredSources,
} from "../../../../packages/initializr-core/src/generator.js";
import { planProject, PlanError } from "../../../../packages/initializr-core/src/index.js";

export function repoRoot(): string {
  return resolve(process.env.ZEVUI_REPO_ROOT ?? resolve(process.cwd(), "../.."));
}

export async function readCatalog(): Promise<Catalog> {
  return JSON.parse(await readFile(resolve(repoRoot(), "registry/catalog.json"), "utf8"));
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
  const root = await realpath(repoRoot());
  const result: Record<string, Uint8Array> = Object.create(null) as Record<string, Uint8Array>;
  for (const source of [...new Set(paths)].sort()) {
    if (!/^[a-zA-Z0-9_.\/-]{1,255}$/.test(source) || source.split("/").some((part) => ["", ".", ".."].includes(part)))
      throw new GeneratorError("Invalid reviewed source path", 500);
    const full = resolve(root, source);
    const actual = await realpath(full);
    const rel = relative(root, actual);
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
