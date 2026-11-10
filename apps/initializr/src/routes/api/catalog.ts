import type { APIEvent } from "@solidjs/start/server";
import { readCatalog } from "../../lib/bridge.server";

export async function GET(_event: APIEvent) {
  try {
    return Response.json(await readCatalog(), { headers: { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" } });
  } catch {
    return Response.json({ error: "Addon catalog unavailable" }, { status: 503 });
  }
}
