#!/usr/bin/env node
// Optional npm/bunx transport only. ALL command parsing, safety and file writes
// happen in the Zig binary (or Zig source via `zig run`).
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const platform = process.platform === 'win32' ? '.exe' : '';
const native = join(root, 'bin', `zevui-native${platform}`);
const args = process.argv.slice(2);
const command = existsSync(native) ? native : 'zig';
const commandArgs = existsSync(native)
  ? args
  : ['run', join(root, 'src/main.zig'), '-O', 'ReleaseSafe', '--', ...args];
const result = spawnSync(command, commandArgs, { stdio: 'inherit', cwd: process.cwd(), shell: false });
if (result.error) {
  console.error(`Zevui native CLI launcher: ${result.error.message}. Install Zig 0.17.1 or provide a packaged native binary.`);
  process.exit(127);
}
if (result.signal) {
  console.error(`Zevui Zig process stopped by ${result.signal}`);
  process.exit(1);
}
process.exit(result.status ?? 1);
