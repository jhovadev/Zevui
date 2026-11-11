# F7 — Deploy Zevui Initializr (SolidStart/Nitro) to Vercel

## Why the Vercel Root Directory is the repository root

The generator depends on `packages/initializr-core`, `registry/catalog.json`, `templates/`, and official addon files. Deploying with `apps/initializr` as an isolated root risks excluding those inputs. The project Root Directory must therefore be **repository root (`./`)**. The root `vercel.json` installs the app's dependencies and invokes its app-specific build.

`apps/initializr/scripts/stage-assets.mjs` compiles the *canonical* planner's list of needed source paths into `.zevui-server-assets/` (private; never placed under `public/`). Nitro bundles them with `serverAssets` and the function loads them with `useKV('assets:zevui').getItemRaw(path)`. The runtime never requires the original Git checkout and does not expose its contents over static HTTP. The `.gitignore` starter input is staged as `__gitignore` to avoid dotfile glob exclusions, then mapped back when read.

No Zig compiler, Python, SQLite C amalgamation, network vendor fetch or ZData is needed to run the Initializr website. The generated SQLite project contains a separate explicit vendor bootstrap script and does not embed the upstream C code in the ZIP. The existing deterministic, STORE-format ZIP algorithm remains unchanged.

## Vercel dashboard

1. Go to [New Project](https://vercel.com/new), connect GitHub, and import **jhovadev/Zevui**.
2. Set **Root Directory** to the repository root (`./`), **Framework Preset** to **Other**, and **Node.js** to **24.x**.
3. Use the committed `vercel.json` defaults: install `npm install --prefix apps/initializr --no-audit --no-fund`, build `node apps/initializr/scripts/vercel-build.mjs`.
4. Deploy. Nitro's `vercel` preset creates `apps/initializr/.vercel/output` and the script moves it to the repository-root `.vercel/output` (the Vercel Build Output API).
5. Test the site and `/api/metadata`, `/api/catalog`, `/api/plan`, `/api/generate` with valid same-origin requests. Test both a plain starter and SQLite starter.
6. Each subsequent push to `main` triggers automatic deployment once the Git integration is connected; other branches use preview deployments.

The Root Directory must not be set to `apps/initializr` for this configuration. No secrets or framework environment variables are required. On Vercel, `VERCEL=1` selects the packaged server assets.

## Local regression checks

```bash
cd ~/Documents/sideProjects/zdata-dvui-examples
just check
just ecosystem-check
just initializr-build
node --test apps/initializr/tests/stage-assets.test.mjs
```

The Vercel-specific output format can be tested with `npm --prefix apps/initializr run build:vercel` after installing dependencies. Confirm `.vercel/output/config.json` exists and that the output has a function and static assets. The final deployment and its runtime APIs must be smoke-tested on a real Vercel preview/production URL; local output existence alone is not sufficient.

### Constraints

- A Vercel Function response cannot exceed **4.5 MB**. The API fails closed above 4.4 MB to retain a margin; it does not silently truncate ZIPs.
- SQLite C vendoring is deliberately **not** part of the generated ZIP, so current ZIPs remain small. Large future addons may need DEFLATE ZIP or object-storage delivery.
- Server assets are a reviewed allowlist derived from `requiredSources(plan)`. Symlinks, missing source files and traversal are rejected during staging.
- No actual Vercel deployment is performed by this patch. Configure project access in the Vercel dashboard or CLI.
