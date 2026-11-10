#!/usr/bin/env node
/** Node-only disk adapter to the single pure TypeScript Initializr generator. */
import { readFile, mkdir, writeFile, rename, rm, access } from 'node:fs/promises';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomInt } from 'node:crypto';
import { planProject, PlanError } from '../dist/index.js';
import { generateProject, normalizeProject } from '../dist/generator.js';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const argv = process.argv.slice(2);
function usage() {
  throw new Error('Usage: node packages/initializr-core/scripts/new.mjs <name> [--title TITLE] [--organization ORG] [--version VERSION] [--addon ID ...] [--output DIR]');
}
async function main() {
  if (!argv.length || argv[0].startsWith('-')) usage();
  const config = { name: argv.shift(), addons: [] };
  let output = process.cwd();
  while (argv.length) {
    const option = argv.shift();
    const argument = argv.shift();
    if (!argument || !['--addon', '--title', '--organization', '--version', '--output'].includes(option)) usage();
    if (option === '--addon') config.addons.push(argument);
    else if (option === '--output') output = argument;
    else config[option.slice(2)] = argument;
  }
  const catalog = JSON.parse(await readFile(join(ROOT, 'registry/catalog.json'), 'utf8'));
  const request = normalizeProject(config, catalog, randomInt(1, 0xffffffff));
  const plan = planProject(request, catalog);
  const sources = Object.create(null);
  const paths = ['examples/minimal/main.zig', ...plan.operations.filter(o => o.kind === 'copy').map(o => o.source)];
  for (const file of new Set(paths)) sources[file] = new Uint8Array(await readFile(join(ROOT, file)));
  const generated = generateProject(request, catalog, sources);
  const dest = resolve(output, request.name);
  try { await access(dest); throw new Error(`Destination already exists: ${dest}`); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  const tmp = resolve(output, `.zevui-${request.name}-${process.pid}-${randomInt(0, 1 << 30).toString(16)}`);
  await mkdir(tmp);
  try {
    for (const [path, bytes] of generated.files) {
      const full = resolve(tmp, path);
      await mkdir(dirname(full), {recursive: true});
      await writeFile(full, bytes);
    }
    await rename(tmp, dest);
  } catch (error) { await rm(tmp, {recursive:true,force:true}); throw error; }
  console.log(`Created ${dest} (${generated.files.size} files). Run: cd ${request.name} && zig build run`);
}
main().catch(error => {
  console.error(error instanceof PlanError ? `${error.code}: ${error.message}` : error.message);
  process.exitCode = 1;
});
