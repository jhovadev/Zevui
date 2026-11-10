import type { APIEvent } from "@solidjs/start/server";
import { GeneratorError, generateProject } from "../../lib/bridge.server";

const MAX_BODY = 16 * 1024;
async function readLimited(request: Request): Promise<string> {
  if (Number(request.headers.get("content-length") || 0) > MAX_BODY) throw new GeneratorError("Request too large", 413);
  if (!request.body) throw new GeneratorError("Missing JSON body", 400);
  const reader = request.body.getReader();
  const parts: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_BODY) { await reader.cancel(); throw new GeneratorError("Request too large", 413); }
    parts.push(value);
  }
  const out = new Uint8Array(total);
  let offset = 0;
  for (const part of parts) { out.set(part, offset); offset += part.byteLength; }
  return new TextDecoder("utf-8", { fatal: true }).decode(out);
}

export async function POST({ request }: APIEvent) {
  const origin = request.headers.get("origin");
  if (origin && origin !== new URL(request.url).origin)
    return Response.json({ error: "Cross-origin generation is disabled" }, { status: 403 });
  if (!(request.headers.get("content-type") || "").startsWith("application/json"))
    return Response.json({ error: "Expected application/json" }, { status: 415 });
  try {
    const body = await readLimited(request);
    const payload: unknown = JSON.parse(body);
    if (!payload || typeof payload !== "object" || Array.isArray(payload)) throw new GeneratorError("Invalid project object", 400);
    const project = payload as Record<string, unknown>;
    // Python owns final validation; this guard only creates a safe download filename.
    const safeName = typeof project.name === "string" && /^[a-z][a-z0-9_-]{1,31}$/.test(project.name)
      ? project.name : "zevui-app";
    const result = await generateProject(body);
    return new Response(result as BodyInit, {
      headers: {
        "Content-Type": "application/zip",
        "Content-Disposition": `attachment; filename="${safeName}.zip"`,
        "Content-Length": String(result.byteLength),
        "Cache-Control": "no-store",
        "X-Content-Type-Options": "nosniff",
      },
    });
  } catch (err) {
    const status = err instanceof GeneratorError ? err.status : err instanceof SyntaxError || err instanceof TypeError ? 400 : 500;
    return Response.json({ error: status === 500 ? "Unexpected generation error" : err instanceof Error ? err.message : "Bad request" }, { status, headers: { "Cache-Control": "no-store" } });
  }
}
