import 'server-only';
import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';

// Drafts: what is being written and not yet sent or saved, one file per text, named by its key.
const folder = process.env.N_DRAFTS || join(homedir(), 'Library/Application Support/N/drafts');
export const keyOk = (key: string) => /^[\w:@.& -]{1,200}$/.test(key);
const file = (key: string) => join(folder, `${encodeURIComponent(key)}.txt`);

export async function read(key: string): Promise<string | null> {
  try { return await readFile(file(key), 'utf8'); } catch { return null; }
}
export async function save(key: string, text: string) {
  await mkdir(folder, { recursive: true });
  await writeFile(file(key), text, 'utf8');
}
export async function drop(key: string) {
  await rm(file(key), { force: true });
}
