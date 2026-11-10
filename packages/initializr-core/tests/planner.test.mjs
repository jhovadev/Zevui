import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { planProject, validateCatalog, zigFingerprint, PlanError } from '../dist/index.js';
const registry = JSON.parse(readFileSync(new URL('../../../registry/catalog.json', import.meta.url)));
const project = { name: 'my-zevui-app', title: 'Mi Aplicación', organization: 'dev.example', version: '0.1.0', addons: ['memory_store', 'design_tokens'], fingerprintId: 0x12345678 };
const failure = (code, fn) => assert.throws(fn, e => e instanceof PlanError && e.code === code);
test('registry is valid and package pin is immutable data', () => {
  validateCatalog(registry);
  assert.match(registry.packages.dvui.hash, /^dvui-/);
});
test('fingerprint uses crc32(name) upper 32 bits', () => {
  assert.equal(zigFingerprint('zig_data_engine', 1), '0x4ab5573700000001');
  failure('fingerprint', () => zigFingerprint('test', 0));
});
test('same input yields byte-identical plan and stable order', () => {
  const a = planProject(project, registry);
  const b = planProject({ ...project, addons: [...project.addons].reverse() }, registry);
  assert.equal(JSON.stringify(a), JSON.stringify(b));
  assert.ok(a.operations.some(f => f.path === 'src/addons/memory_store.zig'));
  assert.equal(a.fingerprint.slice(-8), '12345678');
});
test('no addon means no addon code', () => {
  const result = planProject({ ...project, addons: [] }, registry);
  assert.equal(result.resolvedAddons.length, 0);
  assert.equal(result.operations.filter(f => f.path.startsWith('src/addons/')).length, 0);
});
test('rejected incomplete, non-official and invalid targets', () => {
  failure('addon', () => planProject({ ...project, addons: ['sqlite'] }, registry));
  failure('addon', () => planProject({ ...project, addons: ['__bad__'] }, registry));
  failure('target', () => planProject({ ...project, target: 'haiku' }, registry));
  failure('zig', () => planProject({ ...project, zig: '0.99.0' }, registry));
  failure('input', () => planProject({ ...project, name: '../oops' }, registry));
});
test('cycles, missing requirements, conflicts and target mismatch are rejected', () => {
  const r = structuredClone(registry);
  const a = r.addons.find(a => a.id === 'memory_store');
  const b = r.addons.find(a => a.id === 'design_tokens');
  a.requires = ['design_tokens'];
  b.requires = ['memory_store'];
  failure('cycle', () => planProject(project, r));
  b.requires = [];
  assert.deepEqual(planProject({ ...project, addons: ['memory_store'] }, r).resolvedAddons, ['design_tokens', 'memory_store']);
  b.conflicts = ['memory_store'];
  failure('conflict', () => planProject(project, r));
  b.conflicts = [];
  a.targets = ['linux'];
  failure('compatibility', () => planProject({ ...project, target: 'windows' }, r));
});
test('malicious file paths and output collisions fail before writing anything', () => {
  const r = structuredClone(registry);
  const a = r.addons.find(a => a.id === 'memory_store');
  a.files[0].to = 'src/addons/../../etc/passwd';
  failure('path', () => planProject(project, r));
  a.files[0].to = 'src/addons/design_tokens.zig';
  failure('collision', () => planProject(project, r));
});
