import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import type { Catalog } from "./types";

// Default: `cd apps/initializr` as prescribed by `just initializr`.
// Production deployments may point to a bundled repo using ZEVUI_REPO_ROOT.
export function repoRoot(): string {
  return resolve(process.env.ZEVUI_REPO_ROOT ?? resolve(process.cwd(), "../.."));
}

export async function readCatalog(): Promise<Catalog> {
  return JSON.parse(await readFile(resolve(repoRoot(), "registry/catalog.json"), "utf8"));
}

export class GeneratorError extends Error {
  constructor(message: string, readonly status: number) { super(message); }
}

export async function generateProject(requestJSON: string): Promise<Uint8Array> {
  const python = process.env.ZEVUI_PYTHON || "python3";
  return new Promise<Uint8Array>((ok, fail) => {
    const child = spawn(python, ["-m", "initializr.bridge"], {
      cwd: repoRoot(), stdio: ["pipe", "pipe", "pipe"], shell: false,
      env: { ...process.env, PYTHONIOENCODING: "utf-8" },
    });
    const stdout: Buffer[] = [];
    const stderr: Buffer[] = [];
    let size = 0;
    let done = false;
    const timeout = setTimeout(() => child.kill("SIGKILL"), 15_000);
    child.stdout.on("data", (chunk: Buffer) => {
      size += chunk.length;
      if (size > 8 * 1024 * 1024) { child.kill("SIGKILL"); return; }
      stdout.push(chunk);
    });
    child.stderr.on("data", (chunk: Buffer) => { if (Buffer.concat(stderr).length < 4096) stderr.push(chunk); });
    child.on("error", (err) => { if (!done) { done = true; clearTimeout(timeout); fail(new GeneratorError(err.message, 503)); } });
    child.on("close", (code, signal) => {
      clearTimeout(timeout);
      if (done) return;
      done = true;
      const message = Buffer.concat(stderr).toString("utf8").trim();
      if (size > 8 * 1024 * 1024) return fail(new GeneratorError("Generated archive exceeded limit", 500));
      if (code === 2) return fail(new GeneratorError(message || "Invalid project parameters", 400));
      if (code !== 0 || signal) return fail(new GeneratorError(message || "Project generator unavailable", 503));
      ok(new Uint8Array(Buffer.concat(stdout)));
    });
    child.stdin.end(requestJSON);
  });
}
