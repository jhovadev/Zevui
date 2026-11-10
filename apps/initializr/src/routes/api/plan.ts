import type { APIEvent } from "@solidjs/start/server";
import { readCatalog } from "../../lib/generator.server";
import { planProject, PlanError } from "../../../../../packages/initializr-core/src/index.js";
import type { ProjectInput } from "../../../../../packages/initializr-core/src/index.js";

const MAX_BODY = 16 * 1024;
export async function POST({ request }: APIEvent) {
  const origin = request.headers.get("origin");
  if (origin && origin !== new URL(request.url).origin)
    return Response.json({ error: "Cross-origin planning is disabled" }, { status: 403 });
  if (!(request.headers.get("content-type") ?? "").startsWith("application/json"))
    return Response.json({ error: "Expected application/json" }, { status: 415 });
  if (Number(request.headers.get("content-length") ?? 0) > MAX_BODY)
    return Response.json({ error: "Request too large" }, { status: 413 });
  try {
    if (!request.body) return Response.json({ error: "Missing request body" }, { status: 400 });
    const reader = request.body.getReader();
    const parts: Uint8Array[] = [];
    let total = 0;
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > MAX_BODY) { await reader.cancel(); return Response.json({ error: "Request too large" }, { status: 413 }); }
      parts.push(value);
    }
    const data = new Uint8Array(total);
    let offset = 0;
    for (const part of parts) { data.set(part, offset); offset += part.byteLength; }
    const raw: unknown = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(data));
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new PlanError("input", "Invalid project input");
    return Response.json(planProject(raw as ProjectInput, await readCatalog()), {
      headers: { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" },
    });
  } catch (error) {
    const status = error instanceof PlanError || error instanceof SyntaxError || error instanceof TypeError ? 400 : 503;
    return Response.json({ error: status === 400 && error instanceof Error ? error.message : "Plan unavailable" }, { status });
  }
}
