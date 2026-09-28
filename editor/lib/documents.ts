import 'server-only';
import { access, mkdir, readdir, readFile, rename as move, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { nameOf, parentOf } from './pages';

// .n pages. A page is a file named by letters, digits, spaces, &, - and _ (no space first or last); its
// subpages are the pages in the folder of the same name beside it, as deep as wanted. A page's id is its
// path (see pages.ts). Its title is its first # heading, or its name. A deleted page goes to N/trash.
export const folder = process.env.N_DOCUMENTS || join(homedir(), 'Library/Application Support/N/documents');
export const nameOk = (name: string) => /^[A-Za-z0-9_&-](?:[A-Za-z0-9 _&-]{0,62}[A-Za-z0-9_&-])?$/.test(name);
export const nameRule = "A page's name is letters, digits, spaces, &, - and _";
export const idOk = (id: string) => { const names = id.split('/'); return names.length <= 8 && names.every(nameOk); };
// A route's path, decoded, as a page's id, or null when it is not one.
export const pageId = async (params: Promise<{ path: string[] }>) => { const id = (await params).path.map(decodeURIComponent).join('/'); return idOk(id) ? id : null; };
const file = (id: string) => join(folder, ...id.split('/')) + '.n';
const under = (id: string) => id ? join(folder, ...id.split('/')) : folder;
export const titleOf = (text: string, fallback: string) => text.match(/^#\s+(.+)$/m)?.[1].trim() || fallback;

// The order of the pages under a page (or of the top pages), as the author set it, in .order.json beside
// them. Pages it does not name come after, by name.
const orderFile = (parent: string) => join(under(parent), '.order.json');
async function order(parent: string): Promise<string[]> { try { return JSON.parse(await readFile(orderFile(parent), 'utf8')); } catch { return []; } }
export async function setOrder(parent: string, names: string[]) {
  await mkdir(under(parent), { recursive: true });
  await writeFile(orderFile(parent), JSON.stringify(names));
}
const pagesIn = async (id: string) => (await readdir(under(id)).catch(() => [] as string[])).filter(f => f.endsWith('.n')).map(f => f.slice(0, -2)).filter(nameOk).sort();

// The pages under a page (or the top pages), in the author's order, each with its title and how many pages
// are under it.
export async function list(parent = '') {
  await mkdir(folder, { recursive: true });
  const [names, set] = await Promise.all([pagesIn(parent), order(parent)]);
  const rank = (n: string) => { const i = set.indexOf(n); return i < 0 ? set.length : i; };
  const sorted = names.sort((a, b) => rank(a) - rank(b) || a.localeCompare(b));
  return Promise.all(sorted.map(async name => {
    const id = parent ? `${parent}/${name}` : name;
    return { id, name, title: titleOf(await readFile(file(id), 'utf8'), name), pages: (await pagesIn(id)).length };
  }));
}
// Every page, as a tree: the top pages, each with the pages under it.
export type Node = { id: string; name: string; title: string; pages: Node[] };
export async function tree(parent = '', depth = 0): Promise<Node[]> {
  return Promise.all((await list(parent)).map(async p => ({ id: p.id, name: p.name, title: p.title, pages: p.pages && depth < 8 ? await tree(p.id, depth + 1) : [] })));
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
  try { await access(file(id)); } catch {
    await writeFile(file(id), `# ${nameOf(id)}\n\n`, 'utf8');
    const set = await order(parentOf(id)); if (set.length) await setOrder(parentOf(id), [...set, nameOf(id)]);
  }
}

// Renaming moves the page and the pages under it, and answers its new id; its check, intents and drafts
// follow it (see checks.rename).
export async function rename(id: string, name: string) {
  const to = parentOf(id) ? `${parentOf(id)}/${name}` : name;
  const taken = await access(file(to)).then(() => true, () => false);
  if (taken && id.toLowerCase() !== to.toLowerCase()) throw Error(`${name}.n already exists here`);
  await move(file(id), file(to));
  await move(under(id), under(to)).catch(() => {});
  const set = await order(parentOf(id)); if (set.includes(nameOf(id))) await setOrder(parentOf(id), set.map(n => n === nameOf(id) ? name : n));
  return to;
}

// Deleting moves the page and the pages under it to N/trash, into a folder named for when, where they were
// under it, and takes it out of its parent's order.
const trash = join(dirname(folder), 'trash');
export async function remove(id: string) {
  if ((await read(id)) === null) throw Error('No such page');
  const to = join(trash, new Date().toISOString().replace(/[:.]/g, '-'), ...id.split('/'));
  await mkdir(dirname(to), { recursive: true });
  await move(file(id), `${to}.n`);
  await move(under(id), to).catch(() => {});
  const set = await order(parentOf(id)); if (set.includes(nameOf(id))) await setOrder(parentOf(id), set.filter(n => n !== nameOf(id)));
}
