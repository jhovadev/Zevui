/** Build SolidStart/Nitro for Vercel and place Build Output API at the repo root. */
import { spawnSync } from 'node:child_process';
import { cp, rm, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const app = fileURLToPath(new URL('../', import.meta.url));
const root = fileURLToPath(new URL('../../../', import.meta.url));
const result = spawnSync('npm', ['run', 'build'], {
  cwd: app, stdio: 'inherit',
  env: { ...process.env, NITRO_PRESET: 'vercel', ZEVUI_USE_PACKAGED_ASSETS: '1' },
});
if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status || 1);

const from = join(app, '.vercel/output');
const to = join(root, '.vercel/output');
try { await stat(join(from, 'config.json')); }
catch { throw new Error(`Nitro did not produce Vercel Build Output API at ${from}`); }
await rm(to, { recursive: true, force: true });
await cp(from, to, { recursive: true });
console.log(`Zevui Initializr Vercel Build Output API: ${to}`);
