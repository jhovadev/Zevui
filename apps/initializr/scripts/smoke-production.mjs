/** Read-only smoke of a deployed Zevui Initializr: catalog, plan and ZIP bytes.
 * Usage: node apps/initializr/scripts/smoke-production.mjs [https://your-domain]
 * Does not create files or require Zig. POST /api/generate is an ephemeral request.
 */
import { pathToFileURL } from 'node:url';

const DEFAULT_URL = 'https://zevui-initializr.vercel.app/';
const MAX_ZIP_BYTES = 4_400_000;
const REQUIRED = ['README.md', 'build.zig', 'build.zig.zon', 'mise.toml', 'src/main.zig', 'zevui.zon'];

function assert(condition, message) { if (!condition) throw new Error(message); }

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let k = 0; k < 8; k++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

export function inspectZip(bytes, projectName) {
  const b = Buffer.from(bytes);
  assert(b.length >= 22 && b.length <= MAX_ZIP_BYTES, 'ZIP: invalid or excessive size');
  let eocd = -1;
  for (let i = b.length - 22; i >= Math.max(0, b.length - 22 - 65_535); i--) {
    if (b.readUInt32LE(i) === 0x06054b50 && i + 22 + b.readUInt16LE(i + 20) === b.length) {
      eocd = i; break;
    }
  }
  assert(eocd >= 0, 'ZIP: end-of-central-directory not found');
  assert(b.readUInt16LE(eocd + 4) === 0 && b.readUInt16LE(eocd + 6) === 0, 'ZIP: split archives unsupported');
  const total = b.readUInt16LE(eocd + 10);
  assert(total > 0 && total <= 512 && b.readUInt16LE(eocd + 8) === total, 'ZIP: unexpected entry count');
  const size = b.readUInt32LE(eocd + 12);
  const start = b.readUInt32LE(eocd + 16);
  assert(start + size === eocd, 'ZIP: central directory bounds mismatch');
  const names = new Set();
  let p = start;
  for (let i = 0; i < total; i++) {
    assert(p + 46 <= eocd && b.readUInt32LE(p) === 0x02014b50, 'ZIP: invalid central entry');
    const nameLength = b.readUInt16LE(p + 28);
    const extraLength = b.readUInt16LE(p + 30);
    const commentLength = b.readUInt16LE(p + 32);
    const next = p + 46 + nameLength + extraLength + commentLength;
    assert(next <= eocd, 'ZIP: truncated central entry');
    const name = b.subarray(p + 46, p + 46 + nameLength).toString('utf8');
    assert(name.startsWith(`${projectName}/`), `ZIP: unexpected root ${name}`);
    const rel = name.slice(projectName.length + 1);
    assert(rel && /^[a-zA-Z0-9_.\/-]+$/.test(rel) &&
      rel.split('/').every(segment => segment && segment !== '.' && segment !== '..'),
    `ZIP: unsafe path ${name}`);
    assert(!names.has(rel), `ZIP: duplicate path ${rel}`);
    names.add(rel);
    const localOffset = b.readUInt32LE(p + 42);
    assert(localOffset + 30 <= start && b.readUInt32LE(localOffset) === 0x04034b50,
      `ZIP: invalid local entry for ${name}`);
    assert(b.readUInt16LE(p + 10) === 0 && b.readUInt16LE(localOffset + 8) === 0,
      `ZIP: unexpected compression method for ${name}`);
    const compressed = b.readUInt32LE(p + 20);
    const uncompressed = b.readUInt32LE(p + 24);
    const localNameLength = b.readUInt16LE(localOffset + 26);
    const extra = b.readUInt16LE(localOffset + 28);
    const dataOffset = localOffset + 30 + localNameLength + extra;
    assert(compressed === uncompressed &&
      dataOffset + compressed <= start &&
      b.subarray(localOffset + 30, localOffset + 30 + localNameLength).equals(Buffer.from(name)),
      `ZIP: invalid stored payload for ${name}`);
    const data = b.subarray(dataOffset, dataOffset + compressed);
    assert(crc32(data) === b.readUInt32LE(p + 16),
      `ZIP: checksum mismatch for ${name}`);
    if (rel === 'mise.toml') {
      assert(data.toString('utf8').trim() === '[tools]\nzig = "0.17.1"',
        'ZIP: incorrect Zig 0.17.1 pin');
    }
    p = next;
  }
  assert(p === eocd, 'ZIP: central directory trailing bytes');
  for (const file of REQUIRED) assert(names.has(file), `ZIP: missing ${file}`);
  return names;
}

async function checkedFetch(fetchImpl, url, options = {}) {
  const response = await fetchImpl(url, {
    ...options,
    signal: AbortSignal.timeout(30_000),
    headers: { ...(options.headers || {}), 'User-Agent': 'Zevui-Initializr-Smoke/1.0' },
  });
  assert(response.status >= 200 && response.status < 300,
    `${new URL(url).pathname}: HTTP ${response.status} (expected 2xx)`);
  return response;
}

async function json(fetchImpl, url, options = {}) {
  const response = await checkedFetch(fetchImpl, url, options);
  assert((response.headers.get('content-type') || '').includes('application/json'),
    `${new URL(url).pathname}: expected application/json`);
  return { value: await response.json(), response };
}

export async function runSmoke({ baseUrl = DEFAULT_URL, fetchImpl = fetch, log = console.log } = {}) {
  const base = new URL(baseUrl);
  assert(['https:', 'http:'].includes(base.protocol) && base.username === '' && base.password === '',
    'Expected a public http(s) URL without credentials');
  assert(base.pathname === '/' && !base.search && !base.hash, 'Use the deployment origin without a path');
  const endpoint = (path) => new URL(path, base).toString();

  const home = await checkedFetch(fetchImpl, endpoint('/'));
  const html = await home.text();
  assert(html.includes('zevui') && html.includes('Build native'), 'Homepage does not contain Initializr markers');
  log('PASS homepage');

  const { value: catalog, response: metadataResponse } = await json(fetchImpl, endpoint('/api/metadata'));
  assert(catalog?.zig === '0.17.1' && Array.isArray(catalog.addons) && catalog.addons.length > 0,
    'Metadata: missing or invalid Zig 0.17.1 addon catalog');
  const sqlite = catalog.addons.find(addon => addon.id === 'sqlite');
  assert(sqlite?.status === 'available' && sqlite.targets?.includes('linux'),
    'Metadata: SQLite addon missing or not available on Linux');
  log(`PASS metadata: ${catalog.addons.length} addons, SQLite enabled for Linux`);

  const etag = metadataResponse.headers.get('etag');
  if (etag) {
    const conditional = await fetchImpl(endpoint('/api/metadata'), {
      headers: { 'If-None-Match': etag }, signal: AbortSignal.timeout(30_000),
    });
    assert(conditional.status === 304, `Metadata: ETag returned ${conditional.status}, expected 304`);
    log('PASS ETag revalidation');
  }
  const { value: secondaryCatalog } = await json(fetchImpl, endpoint('/api/catalog'));
  assert(JSON.stringify(secondaryCatalog) === JSON.stringify(catalog), 'Catalog and metadata disagree');
  log('PASS catalog parity');

  for (const scenario of [{ name: 'zevui-smoke-minimal', addons: [] },
                          { name: 'zevui-smoke-sqlite', addons: ['sqlite'] }]) {
    const project = {
      name: scenario.name, title: 'Zevui production smoke', organization: 'dev.zevui',
      version: '0.1.0', zig: '0.17.1', target: 'linux', addons: scenario.addons, fingerprintId: 123,
    };
    const init = { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(project) };
    const { value: plan } = await json(fetchImpl, endpoint('/api/plan'), init);
    assert(plan?.project?.name === scenario.name && Array.isArray(plan.operations) && plan.operations.length > 0,
      `${scenario.name}: invalid plan`);
    assert(JSON.stringify(plan.resolvedAddons) === JSON.stringify(scenario.addons),
      `${scenario.name}: unexpected resolved addons`);

    const response = await checkedFetch(fetchImpl, endpoint('/api/generate'), init);
    assert((response.headers.get('content-type') || '').includes('application/zip'),
      `${scenario.name}: expected application/zip`);
    const bytes = Buffer.from(await response.arrayBuffer());
    const names = inspectZip(bytes, scenario.name);
    const planned = new Set(plan.operations.map(item => item.path));
    assert(names.size === planned.size && [...planned].every(path => names.has(path)),
      `${scenario.name}: plan and ZIP paths disagree`);
    if (scenario.addons.includes('sqlite')) {
      assert(names.has('src/addons/sqlite.zig') && names.has('src/addons/sqlite_vendor.py'),
        'SQLite ZIP: native sources or vendor bootstrap missing');
    } else {
      assert(![...names].some(name => name.includes('sqlite')),
        'Minimal ZIP unexpectedly includes SQLite');
    }
    log(`PASS ${scenario.name}: plan + ${names.size} ZIP entries, ${bytes.length} bytes`);
  }
  log(`PASS Zevui production smoke: ${base.origin}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runSmoke({ baseUrl: process.argv[2] ?? process.env.ZEVUI_INITIALIZR_URL ?? DEFAULT_URL })
    .catch(err => { console.error(`FAIL Zevui production smoke: ${err.message}`); process.exitCode = 1; });
}
