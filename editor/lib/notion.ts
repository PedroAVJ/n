import 'server-only';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { run } from './cli';

// Notion, through its REST API with the official ntn CLI: recent pages, and a page's content as Markdown.
export type Page = { id: string; title: string; url: string; edited: string; parent: string };

const ntn = process.env.NTN_BIN || join(homedir(), '.local/bin/ntn');
const workspace = process.env.N_NOTION_WORKSPACE || '';
export const idOk = (id: string) => /^[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}$/i.test(id);

async function api(path: string, method = 'GET', body?: unknown): Promise<any> {
  const args = ['api', path, ...(method === 'GET' ? [] : ['-X', method]), ...(body === undefined ? [] : ['--data', JSON.stringify(body)])];
  return JSON.parse(await run(ntn, args, undefined, { NOTION_WORKSPACE_ID: workspace }));
}

const titleOf = (p: any) => {
  const t = Object.values(p.properties ?? {}).find((x: any) => x.type === 'title') as any;
  return (t?.title ?? []).map((r: any) => r.plain_text).join('') || 'Untitled';
};
const page = (p: any): Page => ({ id: p.id, title: titleOf(p), url: p.url, edited: p.last_edited_time, parent: p.parent?.page_id || '' });

export async function recent(count = 30): Promise<Page[]> {
  const r = await api('v1/search', 'POST', { filter: { property: 'object', value: 'page' }, sort: { direction: 'descending', timestamp: 'last_edited_time' }, page_size: count });
  return (r.results ?? []).filter((p: any) => !p.in_trash && p.parent?.type !== 'data_source_id' && p.parent?.type !== 'database_id').map(page);
}

// The page's own text, block by block, as Notion holds it: its suggested edits pending are not in it, while
// its Markdown shows them merged in.
async function texts(id: string): Promise<string[]> {
  const r = await api(`v1/blocks/${id}/children?page_size=100`);
  return (r.results ?? []).flatMap((b: any) => b[b.type]?.rich_text ? [(b[b.type].rich_text as any[]).map(t => t.plain_text).join('')] : []);
}
const plain = (s: string) => s.replace(/<[^>]+>/g, '').replace(/\[([^\]]*)\]\([^)]*\)/g, '$1').replace(/[*_`~]/g, '').replace(/\s+/g, ' ').trim();

export async function read(id: string): Promise<{ page: Page; raw: string; pending: boolean }> {
  const [p, m, ts] = await Promise.all([api(`v1/pages/${id}`), api(`v1/pages/${id}/markdown`), texts(id)]);
  const raw: string = m.markdown ?? '';
  const flat = plain(raw);
  return { page: page(p), raw, pending: ts.some(t => t.trim() && !flat.includes(plain(t))) };
}

// Saving sends only what changed, as one search-and-replace grown to whole lines until it is unique, so the
// rest of the page (its blocks, their comments) stays as it is.
export async function save(id: string, before: string, after: string): Promise<string> {
  if (before === after) return before;
  let start = 0, end = 0;
  while (start < before.length && start < after.length && before[start] === after[start]) start++;
  while (end < before.length - start && end < after.length - start && before[before.length - 1 - end] === after[after.length - 1 - end]) end++;
  let a = start, b = before.length - end;
  const unique = () => b > a && before.indexOf(before.slice(a, b)) === before.lastIndexOf(before.slice(a, b));
  do {
    a = a > 0 ? before.lastIndexOf('\n', a - 2) + 1 : 0;
    b = b < before.length ? (before.indexOf('\n', b + 1) + 1 || before.length) : before.length;
  } while (!unique() && (a > 0 || b < before.length));
  const old = before.slice(a, b), next = after.slice(a, after.length - (before.length - b));
  const r = old
    ? await api(`v1/pages/${id}/markdown`, 'PATCH', { type: 'update_content', update_content: { content_updates: [{ old_str: old, new_str: next }] } })
    : await api(`v1/pages/${id}/markdown`, 'PATCH', { type: 'replace_content', replace_content: { new_str: after } });
  return r.markdown ?? after;
}
