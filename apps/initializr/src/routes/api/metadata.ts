import type { APIEvent } from "@solidjs/start/server";
import { createHash } from "node:crypto";
import { readCatalog } from "../../lib/bridge.server";
import { validateCatalog } from "../../../../../packages/initializr-core/src/index.js";

export async function GET({ request }: APIEvent) {
  try {
    const catalog = await readCatalog();
    validateCatalog(catalog);
    const raw = JSON.stringify(catalog);
    const etag = `"${createHash("sha256").update(raw).digest("hex")}"`;
    const headers = { ETag: etag, "Cache-Control": "public, max-age=60", "X-Content-Type-Options": "nosniff" };
    if (request.headers.get("if-none-match") === etag) return new Response(null, { status: 304, headers });
    return new Response(raw, { status: 200, headers: { ...headers, "Content-Type": "application/json; charset=utf-8" } });
  } catch {
    return Response.json({ error: "Addon registry unavailable" }, { status: 503 });
  }
}
