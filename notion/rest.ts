import { spawn } from 'node:child_process';
import { homedir } from 'node:os';
import { join } from 'node:path';

// Notion's REST API, through the official ntn CLI and its login: which pages changed, when, and their text.
export type Edited = { id: string; url: string; title: string; edited: number };
export type Block = { id: string; text: string };

const ntn = process.env.NTN_BIN || join(homedir(), '.local/bin/ntn');
const workspace = process.env.N_NOTION_WORKSPACE || '';

// ntn reads a request body from a piped stdin, so it gets none.
function api(path: string, body?: unknown, params: string[] = []): Promise<any> {
  return new Promise((resolve, reject) => {
    const child = spawn(ntn, ['api', path, ...params, ...(body === undefined ? [] : ['--data', JSON.stringify(body)])], { stdio: ['ignore', 'pipe', 'pipe'], timeout: 60000, env: { ...process.env, NOTION_WORKSPACE_ID: workspace } });
    let out = '', err = '';
    child.stdout.on('data', d => { out += d; });
    child.stderr.on('data', d => { err += d; });
    child.on('error', reject);
    child.on('close', code => code === 0 ? resolve(JSON.parse(out)) : reject(Error(err.trim() || `ntn exited ${code}`)));
  });
}

const title = (page: any) => {
  const t = Object.values(page.properties ?? {}).find((p: any) => p.type === 'title') as any;
  return (t?.title ?? []).map((r: any) => r.plain_text).join('');
};

// The most recently edited pages, newest first.
export async function edited(count = 25): Promise<Edited[]> {
  const r = await api('v1/search', { filter: { property: 'object', value: 'page' }, sort: { direction: 'descending', timestamp: 'last_edited_time' }, page_size: count });
  return (r.results ?? []).filter((p: any) => !p.in_trash && !p.archived)
    .map((p: any) => ({ id: p.id, url: p.url, title: title(p), edited: Date.parse(p.last_edited_time) }));
}

// Blocks whose text is prose, as Notion holds it: pending suggested edits are not in it yet.
const prose = new Set(['paragraph', 'heading_1', 'heading_2', 'heading_3', 'bulleted_list_item', 'numbered_list_item', 'to_do', 'toggle', 'quote', 'callout']);

// The page's prose blocks in order, nested ones after their parent; child pages are pages of their own.
export async function blocks(id: string): Promise<Block[]> {
  const out: Block[] = [];
  let cursor = '';
  do {
    const r = await api(`v1/blocks/${id}/children`, undefined, ['page_size==100', ...(cursor ? [`start_cursor==${cursor}`] : [])]);
    for (const b of r.results ?? []) {
      if (prose.has(b.type)) out.push({ id: b.id, text: (b[b.type].rich_text ?? []).map((t: any) => t.plain_text).join('') });
      if (b.has_children && b.type !== 'child_page' && b.type !== 'child_database') out.push(...await blocks(b.id));
    }
    cursor = r.has_more ? r.next_cursor : '';
  } while (cursor);
  return out;
}
