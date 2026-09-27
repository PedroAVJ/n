import 'server-only';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { read, save } from './documents';
import { check, type Mark, type Which } from './n';

// Check, as N.n asks for it: all of N at once, in the background. The type check, lint and format run in
// turn on the saved document; each makes every fix it is sure of, and later checks work around what the
// type check left wrong. What is left is a list of errors (type) and warnings (lint). The fixed text is
// written back while the document is as it was when the check began. A check keeps running with no page
// open, and its result waits in N/checks for the page to come back.
export type Finding = Mark & { quote: string };
export type Result = { status: 'running' | 'done' | 'failed'; base: string; text: string; fixed: number; errors: Finding[]; warnings: Finding[]; error: string; started: number; finished: number };
export type Intent = { quote: string; intent: string };

const folder = process.env.N_CHECKS || join(homedir(), 'Library/Application Support/N/checks');
const at = (name: string, kind: string) => join(folder, `${name}.${kind}.json`);
async function get<T>(name: string, kind: string, none: T): Promise<T> { try { return JSON.parse(await readFile(at(name, kind), 'utf8')); } catch { return none; } }
async function put(name: string, kind: string, value: unknown) { await mkdir(folder, { recursive: true }); await writeFile(at(name, kind), JSON.stringify(value)); }

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
    let text = r.base; const unparsed: string[] = [];
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
    // Type check; lint around what the type check left wrong; then format, which works around only what
    // could not be understood, in passes until it has nothing left to fix.
    const typed = await pass('type', []);
    r.errors.push(...typed.left); unparsed.push(...typed.left.map(f => f.quote));
    const linted = await pass('lint', unparsed);
    r.warnings.push(...linted.left);
    for (let i = 0; i < 3; i++) {
      const formatted = await pass('format', unparsed);
      r.warnings.push(...formatted.left);
      if (!formatted.fixed) break;
    }
    if (text !== r.base && (await read(name)) === r.base) await save(name, text);
    Object.assign(r, { status: 'done', finished: Date.now() });
  } catch (e) { Object.assign(r, { status: 'failed', error: (e as Error).message, finished: Date.now() }); }
  await put(name, 'result', r);
}
