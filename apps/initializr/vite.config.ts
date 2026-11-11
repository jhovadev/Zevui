import { defineConfig } from "vite";
import { solidStart } from "@solidjs/start/config";
import { nitro } from "nitro/vite";
import { fileURLToPath } from "node:url";

export default defineConfig({
  // Diagnostic escape hatch only: disable HTML SSR while investigating
  // a hydration mismatch. API routes still run on the server.
  plugins: [solidStart({ ssr: process.env.ZEVUI_INITIALIZR_CSR === "1" ? false : true }), nitro()],
  nitro: {
    // Curated private inputs, staged by scripts/stage-assets.mjs before production build.
    serverAssets: [{ baseName: "zevui", dir: "./.zevui-server-assets" }],
  },
  // The pure planner lives outside apps/initializr; permit its source in dev.
  server: { host: "127.0.0.1", port: 8765, strictPort: true,
    fs: { allow: [fileURLToPath(new URL("../../", import.meta.url))] } },
  preview: { host: "127.0.0.1", port: 8765, strictPort: true },
});
