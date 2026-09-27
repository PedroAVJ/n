import 'server-only';
import { mkdir, readdir, readFile, writeFile, access } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';

// .n documents: one folder of files named by letters, digits, - and _. A document's title is its first # heading.
export const folder = process.env.N_DOCUMENTS || join(homedir(), 'Library/Application Support/N/documents');
export const nameOk = (name: string) => /^[A-Za-z0-9_-]{1,64}$/.test(name);
const file = (name: string) => join(folder, `${name}.n`);
export const titleOf = (text: string, fallback: string) => text.match(/^#\s+(.+)$/m)?.[1].trim() || fallback;

export async function list() {
  await mkdir(folder, { recursive: true });
  const names = (await readdir(folder)).filter(f => f.endsWith('.n')).map(f => f.slice(0, -2)).filter(nameOk).sort();
  return Promise.all(names.map(async name => ({ name, title: titleOf(await readFile(file(name), 'utf8'), name) })));
}
export async function read(name: string) {
  try { return await readFile(file(name), 'utf8'); } catch { return null; }
}
export async function save(name: string, text: string) {
  await mkdir(folder, { recursive: true });
  await writeFile(file(name), text, 'utf8');
}
export async function create(name: string) {
  await mkdir(folder, { recursive: true });
  try { await access(file(name)); } catch { await writeFile(file(name), `# ${name}\n\n`, 'utf8'); }
}
