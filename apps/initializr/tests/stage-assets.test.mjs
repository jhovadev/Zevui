import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, readdir, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { stageAssets } from '../scripts/stage-assets.mjs';

const root = new URL('../../../', import.meta.url).pathname;

test('server asset staging includes only canonical project sources', async () => {
  const dest = await mkdtemp(join(tmpdir(), 'zevui-vercel-assets-'));
  try {
    const info = await stageAssets(root, join(dest, 'assets'));
    assert.ok(info.count >= 12);
    const catalog = JSON.parse(await readFile(join(dest, 'assets/registry/catalog.json'), 'utf8'));
    assert.equal(catalog.zig, '0.17.1');
    await stat(join(dest, 'assets/templates/minimal/mise.toml.tmpl'));
    await stat(join(dest, 'assets/templates/minimal/__gitignore'));
    assert.rejects(stat(join(dest, 'assets/templates/minimal/.gitignore')));
    await stat(join(dest, 'assets/addons/storage-sqlite/src/root.zig'));
    assert.rejects(stat(join(dest, 'assets/.git/config')));
    assert.deepEqual(await readdir(join(dest, 'assets')), ['addons', 'registry', 'templates']);
  } finally { await rm(dest, { recursive: true, force: true }); }
});
