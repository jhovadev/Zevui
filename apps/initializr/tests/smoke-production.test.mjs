import test from 'node:test';
import assert from 'node:assert/strict';
import { inspectZip, runSmoke, verifyHomepage } from '../scripts/smoke-production.mjs';

const CORE = ['README.md', 'build.zig', 'build.zig.zon', 'mise.toml', 'src/main.zig',
  'zevui.zon', '.gitignore', 'zevui/build.zig', 'zevui/config.zig'];
const SQLITE = ['src/addons/sqlite.zig', 'src/addons/sqlite_off.zig',
  'src/addons/sqlite_vendor.py', 'src/addons/sqlite_LICENSE.txt'];

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let k = 0; k < 8; k++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function fakeZip(root, paths) {
  const parts = []; const central = [];
  let offset = 0;
  for (const rel of paths) {
    const name = Buffer.from(`${root}/${rel}`);
    const payload = Buffer.from(rel === 'mise.toml' ? '[tools]\nzig = "0.17.1"\n' : 'test file');
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(name.length, 26);
    local.writeUInt32LE(crc32(payload), 14);
    local.writeUInt32LE(payload.length, 18);
    local.writeUInt32LE(payload.length, 22);
    parts.push(local, name, payload);
    const entry = Buffer.alloc(46);
    entry.writeUInt32LE(0x02014b50, 0);
    entry.writeUInt32LE(crc32(payload), 16);
    entry.writeUInt32LE(payload.length, 20);
    entry.writeUInt32LE(payload.length, 24);
    entry.writeUInt16LE(name.length, 28);
    entry.writeUInt32LE(offset, 42);
    central.push(entry, name);
    offset += local.length + name.length + payload.length;
  }
  const directory = Buffer.concat(central);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(paths.length, 8);
  end.writeUInt16LE(paths.length, 10);
  end.writeUInt32LE(directory.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...parts, directory, end]);
}

const TITLE = '<title>Zevui Initializr — Start native</title>';
const SHELL = `<!doctype html><html lang="es"><head>${TITLE}</head><body>` +
  '<div id="app"></div><script type="module" src="/_build/assets/entry-client.js"></script></body></html>';
const SSR = `<!doctype html><html lang="es"><head>${TITLE}</head><body>` +
  '<div id="app"><h1>Build native.</h1></div><script src="/_build/client.js"></script></body></html>';
const htmlResponse = (body, contentType = 'text/html; charset=utf-8') =>
  new Response(body, { headers: { 'content-type': contentType } });

const catalog = {
  zig: '0.17.1', addons: [{ id: 'sqlite', status: 'available', targets: ['linux'] },
    { id: 'design_tokens', status: 'available', targets: ['linux', 'windows', 'macos'] }],
};

function mockFetch({ addons = catalog.addons, changeZip, status = 200, homepage = SHELL } = {}) {
  return async function mock(url, options = {}) {
    const path = new URL(url).pathname;
    if (path === '/') return new Response(homepage, { headers: { 'content-type': 'text/html; charset=utf-8' } });
    if (path === '/api/metadata') {
      if (options.headers?.['If-None-Match']) return new Response(null, { status: 304 });
      return Response.json({ ...catalog, addons }, { headers: { etag: '"smoke"' } });
    }
    if (path === '/api/catalog') return Response.json({ ...catalog, addons });
    const project = JSON.parse(options.body);
    const paths = project.addons.includes('sqlite') ? [...CORE, ...SQLITE] : CORE;
    if (path === '/api/plan') return Response.json({ project, resolvedAddons: project.addons,
      operations: paths.map(path => ({ path })) });
    if (path === '/api/generate') return new Response(
      changeZip ? changeZip(project, paths) : fakeZip(project.name, paths),
      { status, headers: { 'Content-Type': 'application/zip' } },
    );
    throw new Error(`Unexpected route: ${path}`);
  };
}

test('production smoke checks homepage, metadata, plan, minimal and SQLite ZIPs', async () => {
  const log = [];
  await runSmoke({ baseUrl: 'https://zevui-initializr.vercel.app/',
    fetchImpl: mockFetch(), log: message => log.push(message) });
  assert.equal(log.filter(line => line.startsWith('PASS zevui-smoke-')).length, 2);
  assert.match(log.at(-1), /PASS Zevui production smoke/);
});

test('recognizes SSR and the official CSR document without relying on hero text', async () => {
  assert.equal(verifyHomepage(htmlResponse(SSR), SSR), 'SSR');
  assert.equal(verifyHomepage(htmlResponse(SHELL), SHELL), 'CSR shell');
  const log = [];
  await runSmoke({ fetchImpl: mockFetch({ homepage: SHELL }), log: line => log.push(line) });
  assert.ok(log.includes('PASS homepage (CSR shell)'));
});

test('rejects unrelated HTML, auth challenges, invalid content types and empty shells', async () => {
  const unrelated = '<!doctype html><title>Vercel Authentication</title><p>Sign in</p>';
  assert.throws(() => verifyHomepage(htmlResponse(unrelated), unrelated),
    /title="Vercel Authentication"/);
  assert.throws(() => verifyHomepage(htmlResponse(SHELL, 'text/plain'), SHELL),
    /content-type="text\/plain"/);
  const empty = `<!doctype html><title>Zevui Initializr — Start native</title><div id="app"></div>`;
  assert.throws(() => verifyHomepage(htmlResponse(empty), empty), /boot-script=false/);
  await assert.rejects(runSmoke({ fetchImpl: mockFetch({ homepage: unrelated }), log: () => {} }),
    /Homepage: expected Zevui Initializr HTML/);
});

test('fails closed when SQLite is not available in production', async () => {
  await assert.rejects(runSmoke({ fetchImpl: mockFetch({ addons: [catalog.addons[1]] }), log: () => {} }),
    /SQLite addon missing/);
});

test('rejects malformed, traversal and missing ZIP entries', () => {
  assert.throws(() => inspectZip(Buffer.from('not zip'), 'myapp'), /ZIP:/);
  assert.throws(() => inspectZip(fakeZip('myapp', [...CORE, '../escape']), 'myapp'), /unsafe path/);
  assert.throws(() => inspectZip(fakeZip('myapp', CORE.filter(p => p !== 'mise.toml')), 'myapp'), /missing mise.toml/);
  const damaged = fakeZip('myapp', CORE);
  damaged[30 + Buffer.byteLength('myapp/README.md')] ^= 1;
  assert.throws(() => inspectZip(damaged, 'myapp'), /checksum mismatch/);
});

test('detects plan/ZIP mismatch and generation server errors', async () => {
  await assert.rejects(runSmoke({ fetchImpl: mockFetch({
    changeZip: (project, paths) => fakeZip(project.name, paths.filter(p => p !== '.gitignore')),
  }), log: () => {} }), /plan and ZIP paths disagree/);
  await assert.rejects(runSmoke({ fetchImpl: mockFetch({ status: 503 }), log: () => {} }),
    /HTTP 503/);
});

test('rejects invalid smoke base URL', async () => {
  await assert.rejects(runSmoke({ baseUrl: 'file:///etc/passwd', fetchImpl: mockFetch() }),
    /Expected a public http/);
  await assert.rejects(runSmoke({ baseUrl: 'https://example.com/admin', fetchImpl: mockFetch() }),
    /without a path/);
});
