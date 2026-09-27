import 'server-only';
import { access, mkdir, readdir, readFile, rename as move, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { nameOf, parentOf } from './pages';

// .n pages. A page is a file named by letters, digits, spaces, &, - and _ (no space first or last); its
// subpages are the pages in the folder of the same name beside it, as deep as wanted. A page's id is its
// path (see pages.ts). Its title is its first # heading, or its name.
export const folder = process.env.N_DOCUMENTS || join(homedir(), 'Library/Application Support/N/documents');
export const nameOk = (name: string) => /^[A-Za-z0-9_&-](?:[A-Za-z0-9 _&-]{0,62}[A-Za-z0-9_&-])?$/.test(name);
export const nameRule = "A page's name is letters, digits, spaces, &, - and _";
export const idOk = (id: string) => { const names = id.split('/'); return names.length <= 8 && names.every(nameOk); };
// A route's path, decoded, as a page's id, or null when it is not one.
export const pageId = async (params: Promise<{ path: string[] }>) => { const id = (await params).path.map(decodeURIComponent).join('/'); return idOk(id) ? id : null; };
const file = (id: string) => join(folder, ...id.split('/')) + '.n';
const under = (id: string) => id ? join(folder, ...id.split('/')) : folder;
export const titleOf = (text: string, fallback: string) => text.match(/^#\s+(.+)$/m)?.[1].trim() || fallback;

// The pages under a page (or the top pages), each with its title and how many pages are under it.
export async function list(parent = '') {
  await mkdir(folder, { recursive: true });
  const pagesIn = async (id: string) => (await readdir(under(id)).catch(() => [] as string[])).filter(f => f.endsWith('.n')).map(f => f.slice(0, -2)).filter(nameOk).sort();
  return Promise.all((await pagesIn(parent)).map(async name => {
    const id = parent ? `${parent}/${name}` : name;
    return { id, name, title: titleOf(await readFile(file(id), 'utf8'), name), pages: (await pagesIn(id)).length };
  }));
}
export async function read(id: string) {
  try { return await readFile(file(id), 'utf8'); } catch { return null; }
}
export async function save(id: string, text: string) {
  await mkdir(dirname(file(id)), { recursive: true });
  await writeFile(file(id), text, 'utf8');
}
// A new page, under a page that exists.
export async function create(id: string) {
  if (parentOf(id) && (await read(parentOf(id))) === null) throw Error('No such page to put it under');
  await mkdir(dirname(file(id)), { recursive: true });
  try { await access(file(id)); } catch { await writeFile(file(id), `# ${nameOf(id)}\n\n`, 'utf8'); }
}

// Renaming moves the page and the pages under it, and answers its new id; its check, intents and drafts
// follow it (see checks.rename).
export async function rename(id: string, name: string) {
  const to = parentOf(id) ? `${parentOf(id)}/${name}` : name;
  const taken = await access(file(to)).then(() => true, () => false);
  if (taken && id.toLowerCase() !== to.toLowerCase()) throw Error(`${name}.n already exists here`);
  await move(file(id), file(to));
  await move(under(id), under(to)).catch(() => {});
  return to;
}
