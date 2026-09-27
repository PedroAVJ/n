import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { answer, profile, type Finding } from './agent.ts';
import { blocks, edited, type Block, type Edited } from './rest.ts';

// N on Notion. Every little while it asks the REST API which pages changed; once a page has rested, it
// reads the page's text there, has N's editor check it, and has an agent answer each finding in a block
// that changed, on the website: a suggested edit where one rewrite keeps the meaning, a comment on the
// phrase where it has more than one reading.
type Mark = { start: number; end: number; level: string; why: string; question: string; fixable: boolean; new: string; options: string[] };
export type State = { since: number; checked: Record<string, number>; blocks: Record<string, string>; flagged: Record<string, true> };

const every = 20_000;
const rest = 90_000;
const checkUrl = process.env.N_CHECK_URL || 'http://127.0.0.1:4610/api/check';
const stateFile = process.env.N_NOTION_STATE || join(homedir(), 'Library/Application Support/N/notion.json');

const log = (...xs: unknown[]) => console.log(new Date().toISOString(), ...xs);
const hash = (text: string) => createHash('sha256').update(text).digest('hex').slice(0, 16);
const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

function load(): State {
  try { return JSON.parse(readFileSync(stateFile, 'utf8')); } catch { return { since: Date.now(), checked: {}, blocks: {}, flagged: {} }; }
}
function save(state: State) {
  mkdirSync(dirname(stateFile), { recursive: true });
  writeFileSync(stateFile, JSON.stringify(state));
}

async function check(text: string): Promise<Mark[]> {
  const response = await fetch(checkUrl, { method: 'POST', body: text, signal: AbortSignal.timeout(150_000) });
  const r = await response.json() as { marks?: Mark[]; error?: string };
  if (!response.ok || !r.marks) throw Error(r.error || `N check answered ${response.status}`);
  return r.marks;
}

// Pages edited since N last read them (Notion rounds edit times down to the minute), and resting now.
function due(pages: Edited[], state: State, now: number): Edited[] {
  return pages.filter(p => p.edited >= state.since - 60_000 && p.edited > (state.checked[p.id] ?? 0) - 60_000 && now - p.edited >= rest);
}

function lines(m: Mark): string[] {
  return [`N: ${m.question || m.why}`, ...m.options.map((o, i) => `${i + 1}. ${o}`)];
}

class SignedOut extends Error {}

export async function review(p: Edited, state: State) {
  const all = await blocks(p.id);
  const changed = new Set(all.filter(b => b.text.trim() && state.blocks[b.id] !== hash(b.text)).map(b => b.id));
  if (!changed.size) return;
  // The whole page is checked, so each block is read in its context; only changed blocks are answered.
  let text = '';
  const at: Array<{ block: Block; start: number }> = [];
  for (const b of all) { if (text) text += '\n\n'; at.push({ block: b, start: text.length }); text += b.text; }
  log(`checking "${p.title}": ${changed.size} changed of ${all.length} blocks`);
  const marks = await check(text);
  const found = marks.flatMap(m => {
    const where = at.find(a => m.start >= a.start && m.end <= a.start + a.block.text.length);
    if (!where || !changed.has(where.block.id)) return [];
    const quote = text.slice(m.start, m.end), key = `${where.block.id}:${quote}`;
    if (!quote.trim() || state.flagged[key]) return [];
    const f: Finding = m.fixable
      ? { kind: 'suggest', block: where.block.id, text: where.block.text, quote, rewrite: m.new }
      : { kind: 'comment', block: where.block.id, text: where.block.text, quote, comment: lines(m) };
    return [{ key, f }];
  });
  if (found.length) {
    const outcome = await answer(p.url, found.map(x => x.f));
    if (outcome.signedOut) throw new SignedOut('N\'s browser is signed out of Notion');
    for (const i of outcome.done) if (found[i - 1]) state.flagged[found[i - 1].key] = true;
    for (const [i, x] of found.entries()) log(`  ${outcome.done.includes(i + 1) ? 'answered' : 'missed  '} ${x.f.kind} "${x.f.quote}"`);
    log(`"${p.title}": ${found.length} findings to answer, ${outcome.done.length} answered`);
  }
  for (const b of all) state.blocks[b.id] = hash(b.text);
  log(`checked "${p.title}": ${marks.length} findings`);
}

async function run() {
  const state = load();
  save(state);
  log('N on Notion: watching pages edited from', new Date(state.since - 60_000).toISOString());
  for (;;) {
    const now = Date.now();
    try {
      for (const p of due(await edited(), state, now)) {
        try { await review(p, state); state.checked[p.id] = Date.now(); }
        catch (error) { if (error instanceof SignedOut) throw error; log(`failed "${p.title}":`, (error as Error).message); state.checked[p.id] = Date.now(); }
        save(state);
      }
    } catch (error) {
      log((error as Error).message);
      if (error instanceof SignedOut) try { login(); } catch (e) { log((e as Error).message); }
    }
    await sleep(every);
  }
}

// Logging N's Chrome profile in to Notion with Pedro's Chrome's login: its Notion cookies, and no others.
function login() {
  const from = join(homedir(), 'Library/Application Support/Google/Chrome/Default/Cookies');
  const to = join(profile, 'Default');
  const copy = join(to, 'Cookies.copy');
  mkdirSync(to, { recursive: true });
  rmSync(copy, { force: true });
  execFileSync('/usr/bin/sqlite3', [`file:${from}?immutable=1`, `.backup '${copy}'`]);
  execFileSync('/usr/bin/sqlite3', [copy, "delete from cookies where host_key not like '%notion.so' and host_key not like '%notion.com'; vacuum;"]);
  rmSync(join(to, 'Cookies-journal'), { force: true });
  renameSync(copy, join(to, 'Cookies'));
  log('copied Chrome\'s Notion login');
}

if (import.meta.main) await (process.argv[2] === 'login' ? login() : run());
