import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
const root = resolve(import.meta.dirname, '..');
const bundle = JSON.parse(readFileSync(join(root, 'registry-bundle.json'), 'utf8'));
const probe = spawnSync('zig', ['version'], { encoding: 'utf8' });
const zig017 = probe.status === 0 && probe.stdout.trim() === '0.17.1';
const cli = args => spawnSync('zig', ['run', join(root, 'src/main.zig'), '-O', 'ReleaseSafe', '--', ...args], { encoding: 'utf8' });
test('embedded component registry is present and identical to canonical snapshot', () => {
  assert.equal(bundle.items.length, 8);
  assert.equal(readFileSync(join(root, 'src/registry-bundle.json'), 'utf8'),
    readFileSync(join(root, 'registry-bundle.json'), 'utf8'));
});
test('native CLI compiles and lists components', { skip: !zig017 && 'Requires Zig 0.17.1 in PATH' }, () => {
  const result = cli(['list']);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /calendar/);
  assert.match(result.stdout, /heatmap/);
});
test('init add doctor preserve local edits', { skip: !zig017 && 'Requires Zig 0.17.1 in PATH' }, () => {
  const project = mkdtempSync(join(tmpdir(), 'zevui-native-'));
  try {
    writeFileSync(join(project, 'build.zig'), '// Zig project\n');
    let r = cli(['init', '--project', project]); assert.equal(r.status, 0, r.stderr);
    r = cli(['add', 'calendar', 'input', '--project', project]); assert.equal(r.status, 0, r.stderr);
    assert.ok(existsSync(join(project, 'src/components/calendar_model.zig')));
    r = cli(['doctor', '--project', project]); assert.equal(r.status, 0, r.stderr);
    const target = join(project, 'src/components/input.zig');
    writeFileSync(target, '// local edit\n');
    r = cli(['update', 'input', '--project', project]); assert.notEqual(r.status, 0);
    assert.equal(readFileSync(target, 'utf8'), '// local edit\n');
  } finally { rmSync(project, { recursive: true, force: true }); }
});
