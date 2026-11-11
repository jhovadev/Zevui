import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { generateProject, normalizeProject, zipProject, requiredSources } from '../dist/generator.js';
import { planProject, PlanError } from '../dist/index.js';

const root = new URL('../../../', import.meta.url);
const read = (p) => readFileSync(new URL(p, root));
const registry = JSON.parse(read('registry/catalog.json'));
const golden = JSON.parse(read('tests/fixtures/initializr-f2-golden.json'));
const compatibility = JSON.parse(read('tests/fixtures/f41-golden-overrides.json')).overrides;
const sources = Object.fromEntries([
  'templates/minimal/build.zig.tmpl', 'templates/minimal/build.zig.zon.tmpl',
  'templates/minimal/zevui.zon.tmpl', 'templates/minimal/README.md.tmpl',
  'templates/minimal/.gitignore', 'templates/minimal/src/main.zig',
  'templates/compat/zevui/build.zig', 'templates/compat/zevui/config.zig',
  'addons/design-tokens/src/root.zig', 'addons/memory-store/src/root.zig',
  'templates/sqlite/build.zig.tmpl', 'templates/sqlite/README.md.tmpl', 'templates/sqlite/src/main.zig',
  'addons/storage-sqlite/src/root.zig', 'addons/storage-sqlite/src/off.zig',
  'addons/storage-sqlite/tools/vendor_starter.py', 'addons/storage-sqlite/LICENSE',
].map(p => [p, read(p)]));

for (const [key, { project, files }] of Object.entries(golden)) {
  test(`TS generator matches frozen Python output for ${key}`, () => {
    const g = generateProject(project, registry, sources);
    assert.deepEqual([...g.files.keys()].sort(), Object.keys(files).sort());
    for (const [path, expected] of Object.entries(files)) {
      const actual = createHash('sha256').update(g.files.get(path)).digest('hex');
      assert.equal(actual, compatibility[path]?.sha256 ?? expected, path);
    }
  });
}
test('same selection, including reordered addons, yields byte-identical ZIP', () => {
  const p = golden.addons.project;
  const a = zipProject(generateProject(p, registry, sources));
  const b = zipProject(generateProject({...p, addons: [...p.addons].reverse()}, registry, sources));
  assert.deepEqual(a, b);
  assert.equal(new DataView(a.buffer).getUint32(0, true), 0x04034b50);
  assert.equal(new DataView(a.buffer).getUint32(a.length - 22, true), 0x06054b50);
  assert.ok(a.length < 100_000);
});
test('planner and ZIP share identical paths with safe project root', () => {
  const p = golden.addons.project;
  const g = generateProject(p, registry, sources);
  assert.deepEqual([...g.files.keys()], g.plan.operations.map(x => x.path));
  assert.ok([...g.files.keys()].every(x => !x.startsWith('/') && !x.includes('..')));
  const zip = zipProject(g);
  const bytes = new DataView(zip.buffer, zip.byteOffset, zip.byteLength);
  const pos = zip.length - 22;
  assert.equal(bytes.getUint16(pos + 8, true), g.files.size);
  assert.equal(bytes.getUint32(pos + 12, true) > 0, true);
});
test('invalid and inactive addons never reach source reads', () => {
  const p = golden.addons.project;
  assert.throws(() => generateProject({...p,addons:['tray']}, registry, sources), e => e instanceof PlanError && e.code === 'addon');
  assert.throws(() => generateProject({...p,addons:['../x']}, registry, sources), e => e instanceof PlanError && e.code === 'addon');
});
test('missing source fails closed before producing a ZIP', () => {
  const p = golden.addons.project;
  assert.throws(() => generateProject(p, registry, {}), e => e instanceof PlanError && e.code === 'source');
});
test('normalizer supplies defaults and rejects unexpected keys', () => {
  const p = normalizeProject({}, registry, 123);
  assert.equal(p.name, 'my-zevui-app');
  assert.deepEqual(p.addons, ['design_tokens']);
  assert.equal(p.fingerprintId, 123);
  assert.equal(planProject(p, registry).project.zig, '0.17.1');
  assert.throws(() => normalizeProject({ injected: 'payload' }, registry, 1), e => e instanceof PlanError && e.code === 'input');
  assert.throws(() => generateProject({...p,fingerprintId:0},registry,sources), e => e instanceof PlanError && e.code === 'fingerprint');
});

test('ZIP metadata uses normalized permissions, timestamp and UTF8 flags', () => {
  const p = golden.unicode.project;
  const g = generateProject(p, registry, sources);
  const archive = zipProject(g);
  const view = new DataView(archive.buffer, archive.byteOffset, archive.byteLength);
  assert.equal(view.getUint16(6, true), 0x0800);
  assert.equal(view.getUint16(8, true), 0); // STORE
  assert.equal(view.getUint16(10, true), 0); // fixed time
  assert.equal(view.getUint16(12, true), ((2026 - 1980) << 9) | 33);
  const eocd = archive.length - 22;
  const centralOffset = view.getUint32(eocd + 16, true);
  assert.equal(view.getUint32(centralOffset, true), 0x02014b50);
  assert.equal(view.getUint32(centralOffset + 38, true) >>> 16, 0o100644);
});

test('CLI disk adapter uses the same renderer, refuses overwrite', async () => {
  const {mkdtempSync, rmSync, readdirSync, readFileSync} = await import('node:fs');
  const {tmpdir} = await import('node:os');
  const {join} = await import('node:path');
  const {spawnSync} = await import('node:child_process');
  const tmp = mkdtempSync(join(tmpdir(), 'zevui-f2-'));
  try {
    const args = ['packages/initializr-core/scripts/new.mjs', 'generated-app', '--output', tmp, '--addon', 'design_tokens'];
    const first = spawnSync(process.execPath, args, {cwd: new URL('../../../', import.meta.url), encoding:'utf8'});
    assert.equal(first.status, 0, first.stderr);
    assert.ok(readFileSync(join(tmp, 'generated-app/build.zig.zon')).includes('dvui-0.6.0-dev'));
    assert.deepEqual(readdirSync(join(tmp, 'generated-app/src/addons')), ['design_tokens.zig']);
    const second = spawnSync(process.execPath, args, {cwd: new URL('../../../', import.meta.url), encoding:'utf8'});
    assert.notEqual(second.status, 0);
    assert.match(second.stderr, /already exists/);
  } finally { rmSync(tmp, {recursive:true, force:true}); }
});

test('production API and CLI consume only canonical source list, including templates', () => {
  const p = golden.addons.project;
  const plan = planProject(p, registry);
  const expected = requiredSources(plan);
  assert.equal(expected.length, 8 + 2); // 6 starter templates, 2 compat SDK, 2 selected addons
  assert.deepEqual(expected, [...expected].sort());
  assert.deepEqual(expected, Object.keys(sources).filter(p => !p.startsWith('templates/sqlite/') && !p.startsWith('addons/storage-sqlite/')).sort());
  const generated = generateProject(p, registry, sources);
  assert.ok(generated.files.has('src/main.zig'));
});

test('missing template and unknown template tokens fail closed', () => {
  const p = golden.minimal.project;
  const missing = {...sources};
  delete missing['templates/minimal/build.zig.tmpl'];
  assert.throws(() => generateProject(p, registry, missing), e => e instanceof PlanError && e.code === 'source');
  const corrupt = {...sources, 'templates/minimal/build.zig.tmpl': '{{UNKNOWN_FIELD}}'};
  assert.throws(() => generateProject(p, registry, corrupt), e => e instanceof PlanError && e.code === 'template');
});

test('user-supplied braces are inert data and never reinterpreted as template tokens', () => {
  const p = {...golden.minimal.project, title: 'Real {{TITLE_RAW}} App'};
  const g = generateProject(p, registry, sources);
  const readme = new TextDecoder().decode(g.files.get('README.md'));
  assert.ok(readme.includes('Real {{TITLE_RAW}} App'));
});

test('SQLite is opt-in, native C-link build is isolated, and ZIP remains deterministic', () => {
  const p = {...golden.minimal.project, addons: ['sqlite']};
  const plan = planProject(p, registry);
  const required = requiredSources(plan);
  assert.ok(required.includes('addons/storage-sqlite/src/root.zig'));
  assert.ok(required.includes('templates/sqlite/build.zig.tmpl'));
  const g = generateProject(p, registry, sources);
  assert.deepEqual([...g.files.keys()], plan.operations.map(op => op.path));
  assert.deepEqual([...g.files.keys()].filter(x => x.startsWith('src/addons/')).sort(), [
    'src/addons/sqlite.zig','src/addons/sqlite_LICENSE.txt','src/addons/sqlite_off.zig','src/addons/sqlite_vendor.py',
  ]);
  const build = new TextDecoder().decode(g.files.get('build.zig'));
  assert.match(build, /sqlite_vendor\/sqlite3\.c/);
  assert.match(build, /sqlite3/);
  assert.match(build, /\.off => \{\}/);
  assert.match(new TextDecoder().decode(g.files.get('src/main.zig')), /@import\("storage_sqlite"\)/);
  assert.match(new TextDecoder().decode(g.files.get('src/main.zig')), /SQLite storage addon selected/);
  const without = generateProject({...p, addons: []}, registry, sources);
  assert.doesNotMatch(new TextDecoder().decode(without.files.get('build.zig')), /SqliteMode/);
  assert.equal([...without.files.keys()].filter(x => x.startsWith('src/addons/')).length, 0);
  assert.deepEqual(zipProject(g), zipProject(generateProject({...p,addons:['sqlite']}, registry, sources)));
});

test('SQLite selection fails closed when a required source is missing', () => {
  const p = {...golden.minimal.project,addons:['sqlite']};
  const missing = {...sources};
  delete missing['addons/storage-sqlite/tools/vendor_starter.py'];
  assert.throws(() => generateProject(p, registry, missing), e => e instanceof PlanError && e.code === 'source');
});

test('SQLite availability rejects unverified Windows/macOS generator targets', () => {
  const p = {...golden.minimal.project,addons:['sqlite']};
  for (const target of ['windows','macos']) {
    assert.throws(() => planProject({...p,target}, registry),
      e => e instanceof PlanError && e.code === 'compatibility');
  }
});
