import 'server-only';
import { mkdir, readdir, readFile, writeFile, access, rename as move } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';

// .n documents: one folder of files named by letters, digits, spaces, &, - and _ (no space first or last). A
// document's title is its first # heading, or its name. A name travels in URLs encoded (see named).
export const folder = process.env.N_DOCUMENTS || join(homedir(), 'Library/Application Support/N/documents');
export const nameOk = (name: string) => /^[A-Za-z0-9_&-](?:[A-Za-z0-9 _&-]{0,62}[A-Za-z0-9_&-])?$/.test(name);
export const nameRule = "A document's name is letters, digits, spaces, &, - and _";
// A route's name segment, decoded, or null when it is not a document's name.
export const named = async (params: Promise<{ name: string }>) => { const n = decodeURIComponent((await params).name); return nameOk(n) ? n : null; };
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

// Renaming moves the file; the document's check, intents and draft follow it (see checks.rename).
export async function rename(from: string, to: string) {
  const taken = await access(file(to)).then(() => true, () => false);
  if (taken && from.toLowerCase() !== to.toLowerCase()) throw Error(`${to}.n already exists`);
  await move(file(from), file(to));
}
