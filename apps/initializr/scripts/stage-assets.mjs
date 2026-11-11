/** Stage ONLY reviewed project-generator inputs as private Nitro server assets. */
import { readFile, realpath, lstat, mkdtemp, mkdir, rm, rename, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative, resolve, sep } from 'node:path';

const repo = fileURLToPath(new URL('../../../', import.meta.url));
const app = fileURLToPath(new URL('../', import.meta.url));
const sourcePath = /^[a-zA-Z0-9_.\/-]{1,255}$/;

export async function stageAssets(repoRoot = repo, dest = join(app, '.zevui-server-assets')) {
  const root = await realpath(repoRoot);
  const catalog = JSON.parse(await readFile(join(root, 'registry/catalog.json'), 'utf8'));
  // The compiled canonical planner is the source of truth; no independent glob of repo files.
  const [{ requiredSources }, { planProject }] = await Promise.all([
    import('../../../packages/initializr-core/dist/generator.js'),
    import('../../../packages/initializr-core/dist/index.js'),
  ]);
  const request = (addons, target = 'linux') => ({
    name: 'zevui-deployment-smoke', title: 'Deployment Smoke', organization: 'dev.zevui',
    version: '0.1.0', zig: catalog.zig, target, addons, fingerprintId: 1,
  });
  const sources = new Set(['registry/catalog.json', ...requiredSources(planProject(request([]), catalog))]);
  for (const addon of catalog.addons) {
    if (addon.status !== 'available') continue;
    const plan = planProject(request([addon.id], addon.targets[0]), catalog);
    for (const path of requiredSources(plan)) sources.add(path);
  }
  await mkdir(dirname(dest), { recursive: true });
  const temp = await mkdtemp(join(dirname(dest), '.zevui-stage-'));
  let size = 0;
  try {
    for (const path of [...sources].sort()) {
      if (!sourcePath.test(path) || path.split('/').some(p => !p || p === '.' || p === '..')) {
        throw new Error(`Unsafe reviewed source path: ${path}`);
      }
      const source = resolve(root, path);
      const actual = await realpath(source);
      const rel = relative(root, actual);
      if (rel === '' || rel === '..' || rel.startsWith('..' + sep) || rel.startsWith(sep)) {
        throw new Error(`Source escapes repository: ${path}`);
      }
      if (!(await lstat(source)).isFile()) throw new Error(`Expected regular file: ${path}`);
      const bytes = await readFile(actual);
      size += bytes.byteLength;
      if (size > 32 * 1024 * 1024) throw new Error('Reviewed generator assets exceed 32 MiB');
      // Nitro globbing may exclude dotfiles; preserve .gitignore under a safe key.
      const key = path.replaceAll('/.gitignore', '/__gitignore');
      await mkdir(dirname(join(temp, key)), { recursive: true });
      await writeFile(join(temp, key), bytes);
    }
    await rm(dest, { recursive: true, force: true });
    await rename(temp, dest);
  } catch (error) {
    await rm(temp, { recursive: true, force: true });
    throw error;
  }
  return { count: sources.size, bytes: size, dest };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const result = await stageAssets();
    console.log(`Zevui reviewed server assets: ${result.count} files (${result.bytes} bytes)`);
  } catch (error) {
    console.error(error);
    process.exitCode = 1;
  }
}
