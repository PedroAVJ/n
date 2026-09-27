import 'server-only';
import { mkdir, readFile, rename as renameIn, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { read, rename as renameFile, save } from './documents';
import { drop as dropDraft, keys as draftKeys, read as readDraft, save as saveDraft } from './drafts';
import { check, format, type Mark, type Which } from './n';

// Check, as N.n asks for it: all of N at once, in the background. The type check, lint and format run in
// turn on the saved document: the type check and lint make every fix they are sure of, format prints the
// whole text again, and later checks work around what the type check left wrong. What is left is a list
// of errors (type) and warnings (lint). The fixed text is
// written back while the document is as it was when the check began. A check keeps running with no page
// open, and its result waits in N/checks for the page to come back.
export type Finding = Mark & { quote: string };
export type Result = { status: 'running' | 'done' | 'failed'; base: string; text: string; fixed: number; formatted?: boolean; errors: Finding[]; warnings: Finding[]; error: string; started: number; finished: number };
export type Intent = { quote: string; intent: string };

const folder = process.env.N_CHECKS || join(homedir(), 'Library/Application Support/N/checks');
// A page's check and intents sit at its path in N/checks, the pages under it in the folder beside them.
const at = (id: string, kind: string) => join(folder, ...id.split('/')) + `.${kind}.json`;
async function get<T>(name: string, kind: string, none: T): Promise<T> { try { return JSON.parse(await readFile(at(name, kind), 'utf8')); } catch { return none; } }
async function put(name: string, kind: string, value: unknown) { await mkdir(dirname(at(name, kind)), { recursive: true }); await writeFile(at(name, kind), JSON.stringify(value)); }

export const result = (name: string) => get<Result | null>(name, 'result', null);
export const intents = (name: string) => get<Intent[]>(name, 'intents', []);

// What the author means about a finding: kept for every later check, one per phrase.
export async function intend(name: string, quote: string, intent: string) {
  const all = (await intents(name)).filter(i => i.quote !== quote);
  if (intent.trim()) all.push({ quote, intent: intent.trim() });
  await put(name, 'intents', all.slice(-100));
}

const running = new Set<string>();
export async function start(name: string): Promise<Result | null> {
  if (running.has(name)) return result(name);
  const base = await read(name); if (base === null) return null;
  const began: Result = { status: 'running', base, text: base, fixed: 0, errors: [], warnings: [], error: '', started: Date.now(), finished: 0 };
  await put(name, 'result', began);
  running.add(name);
  void run(name, began).finally(() => running.delete(name));
  return began;
}

async function run(name: string, r: Result) {
  try {
    const wanted = (await intents(name)).map(i => `"${i.quote}": ${i.intent}`);
    let text = r.base;
    // One pass of a check: every fix it is sure of made, from the end back so each phrase is still where N
    // found it (one overlapping a fix already made is left out); what it cannot fix is returned.
    const pass = async (which: Which, isolate: string[]) => {
      const found = (await check(text, which, wanted, isolate)).marks.map(m => ({ ...m, quote: text.slice(m.start, m.end) }));
      const fix: Finding[] = [];
      for (const f of found.filter(f => f.fixable && !f.options?.length).sort((a, b) => b.start - a.start))
        if (!fix.some(g => f.start < g.end && g.start < f.end)) fix.push(f);
      for (const f of fix) text = text.slice(0, f.start) + f.new + text.slice(f.end);
      r.fixed += fix.length; r.text = text; await put(name, 'result', r);
      return { fixed: fix.length, left: found.filter(f => !fix.includes(f)) };
    };
    // The type check and lint fix what they are sure of; format prints the whole text again around what the
    // type check could not fix; then the type check and lint run once more, on the formatted text, and what
    // they cannot fix is the list of errors and warnings.
    const first = await pass('type', []);
    const unparsed = first.left.map(f => f.quote);
    await pass('lint', unparsed);
    const formatted = await format(text, wanted, unparsed);
    // Kept only if every span the type check could not fix is still there as it was, and most of the text
    // was not dropped.
    if (unparsed.every(q => formatted.includes(q)) && formatted.length >= text.length * 0.25 && formatted !== text) { r.fixed += 1; text = formatted; r.formatted = true; }
    r.text = text; await put(name, 'result', r);
    const typed = await pass('type', []);
    r.errors = typed.left;
    const linted = await pass('lint', typed.left.map(f => f.quote));
    r.warnings = linted.left;
    if (text !== r.base && (await read(name)) === r.base) await save(name, text);
    Object.assign(r, { status: 'done', finished: Date.now() });
  } catch (e) { Object.assign(r, { status: 'failed', error: (e as Error).message, finished: Date.now() }); }
  await put(name, 'result', r);
}

// A page renamed: its file and the pages under it move, and so do their checks, intents and drafts; the
// answer is its new id. Not while a check runs on it or under it, which would write back under the old name.
export async function rename(id: string, name: string) {
  if ([...running].some(r => r === id || r.startsWith(`${id}/`))) throw Error('N is checking this page: rename it when the check is done');
  const to = await renameFile(id, name);
  for (const kind of ['result', 'intents']) await renameIn(at(id, kind), at(to, kind)).catch(() => {});
  await renameIn(join(folder, ...id.split('/')), join(folder, ...to.split('/'))).catch(() => {});
  for (const key of await draftKeys()) {
    const page = key.startsWith('doc:') ? key.slice(4) : null;
    if (page === null || (page !== id && !page.startsWith(`${id}/`))) continue;
    const draft = await readDraft(key);
    if (draft !== null) await saveDraft(`doc:${to}${page.slice(id.length)}`, draft);
    await dropDraft(key);
  }
  return to;
}
