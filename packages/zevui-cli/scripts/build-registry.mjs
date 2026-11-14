#!/usr/bin/env node
/** Deterministic bridge from Zevui's canonical Zig manifests to an offline
 * shadcn-shaped registry. No npm dependencies and no network access. */
import { createHash } from 'node:crypto';
import { readFile, readdir, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
const repo = resolve(import.meta.dirname, '../../..');
const directory = join(repo, 'registry/components');
const manifestNames = (await readdir(directory)).filter(n => /^[a-z][a-z0-9-]*\.json$/.test(n)).sort();
const items = [];
for (const filename of manifestNames) {
  const m = JSON.parse(await readFile(join(directory, filename), 'utf8'));
  if (m.schema !== 1 || m.zig !== '0.17.1' || filename !== `${m.id}.json` || !m.files?.length) throw Error(`Invalid source manifest: ${filename}`);
  const files = [];
  for (const file of m.files) {
    if (!/^framework\/src\/ui\/[\w/-]+\.zig$/.test(file.source) || !/^src\/components\/[\w/-]+\.zig$/.test(file.target)) throw Error(`Unsafe component path: ${m.id}`);
    const content = await readFile(join(repo, file.source), 'utf8');
    files.push({ path: file.source, type: 'registry:ui', target: file.target, content, sha256: createHash('sha256').update(content).digest('hex') });
  }
  items.push({
    $schema: 'https://ui.shadcn.com/schema/registry-item.json',
    name: m.id, type: 'registry:ui', title: m.name, description: m.description,
    registryDependencies: m.registryDependencies ?? [],
    files,
    meta: { zevui: { schema: 1, zig: m.zig, renderer: m.renderer, status: m.status, category: m.category } },
  });
}
if (!items.length) throw Error('Empty components registry');
const out = JSON.stringify({ $schema: 'https://ui.shadcn.com/schema/registry.json', name: 'zevui',
  homepage: 'https://zevui-initializr.vercel.app/components', items }, null, 2) + '\n';
const target = resolve(import.meta.dirname, '../registry-bundle.json');
// Zig 0.17.x @embedFile is restricted to the module root (src/).
// Keep a byte-identical generated mirror so both `zig run src/main.zig`
// and `zig build` embed the same offline verified sources.
const embeddedTarget = resolve(import.meta.dirname, '../src/registry-bundle.json');
const indexPath = resolve(import.meta.dirname, '../registry.json');
const index = JSON.stringify({
  $schema: 'https://ui.shadcn.com/schema/registry.json',
  name: 'zevui', homepage: 'https://zevui-initializr.vercel.app/components',
  items: items.map(({ name, title, description, type, registryDependencies, files }) => ({
    name, title, description, type, registryDependencies,
    files: files.map(({ path, type, target }) => ({ path, type, target })),
  })),
}, null, 2) + '\n';
if (process.argv.includes('--check')) {
  if (await readFile(target, 'utf8').catch(() => '') !== out ||
      await readFile(embeddedTarget, 'utf8').catch(() => '') !== out ||
      await readFile(indexPath, 'utf8').catch(() => '') !== index) {
    throw Error('CLI registry is stale: run node scripts/build-registry.mjs');
  }
  console.log(`Verified ${items.length} CLI items against Zig sources`);
} else {
  await writeFile(target, out);
  await writeFile(embeddedTarget, out);
  await writeFile(indexPath, index);
  console.log(`Generated ${items.length} CLI items: index + embedded bundle`);
}
