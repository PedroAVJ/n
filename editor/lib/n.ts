import 'server-only';
import { execFile } from 'node:child_process';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { query, type SDKUserMessage } from '@anthropic-ai/claude-agent-sdk';

// N's checks. The screen is N's binary asking Jev which phrases are unclear. N check is N's whole-document
// checker prompt, answered by Claude Opus on the owner's Claude subscription through one warm Agent SDK
// session, and read back into marks by N's binary.
export type Mark = { start: number; end: number; level: string; why: string; question: string; fixable: boolean; new: string; options: string[] };
export type Review = { marks: Mark[]; assessor: string; seconds: number };

const binary = process.env.N_BIN || join(homedir(), 'Library/Application Support/N/bin/n');
const keychainItem = process.env.N_KEYCHAIN || '';

function runN(args: string[], input: unknown): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = execFile(binary, args, { timeout: 30000, maxBuffer: 16 << 20 }, (error, stdout) => error ? reject(error) : resolve(stdout));
    child.stdin?.end(JSON.stringify(input));
  });
}

// N counts offsets in characters (code points); the browser counts UTF-16 units.
const units = (text: string, points: number) => Array.from(text).slice(0, points).join('').length;
const inUnits = (text: string, marks: Mark[]) => marks.map(m => ({ ...m, start: units(text, m.start), end: units(text, m.end) }));

class Checker {
  private waiting: Array<(m: SDKUserMessage) => void> = [];
  private queued: SDKUserMessage[] = [];
  private pending: Array<{ resolve(t: string): void; reject(e: Error): void }> = [];
  private used = 0;
  private closed = false;
  constructor() { void this.listen(); }
  private async *input(): AsyncGenerator<SDKUserMessage> {
    while (!this.closed) yield this.queued.shift() ?? await new Promise<SDKUserMessage>(resolve => this.waiting.push(resolve));
  }
  private async listen() {
    try {
      for await (const message of query({ prompt: this.input(), options: {
        model: 'claude-opus-5-5', effort: 'low', tools: [], settingSources: [], persistSession: false,
        systemPrompt: 'You are N, a type checker for documents. Each message is an independent check: ignore earlier ones. Answer with the JSON the message asks for and nothing else.',
      } })) {
        if (message.type !== 'result') continue;
        const next = this.pending.shift();
        if (message.subtype === 'success') next?.resolve(message.result);
        else next?.reject(Error(`Claude ended the check: ${message.subtype}`));
      }
    } catch (error) { for (const next of this.pending.splice(0)) next.reject(error as Error); }
    this.closed = true;
  }
  get usable() { return !this.closed && this.used < 20; }
  ask(prompt: string): Promise<string> {
    this.used += 1;
    const message: SDKUserMessage = { type: 'user', message: { role: 'user', content: prompt }, parent_tool_use_id: null };
    return new Promise((resolve, reject) => {
      this.pending.push({ resolve, reject });
      const waiter = this.waiting.shift();
      if (waiter) waiter(message); else this.queued.push(message);
    });
  }
  close() { this.closed = true; for (const w of this.waiting.splice(0)) w({ type: 'user', message: { role: 'user', content: '' }, parent_tool_use_id: null }); }
}

let checker: Checker | null = null;
let turn: Promise<unknown> = Promise.resolve();
function claude(prompt: string): Promise<string> {
  const answer = turn.then(() => {
    if (!checker?.usable) { checker?.close(); checker = new Checker(); }
    return checker.ask(prompt);
  });
  turn = answer.catch(() => {});
  return answer;
}

export async function screen(text: string): Promise<Review> {
  const started = Date.now();
  const r = JSON.parse(await runN(['screen', keychainItem], { text, conversation: '' })) as { marks: Mark[]; assessor: string };
  return { marks: inUnits(text, r.marks), assessor: r.assessor, seconds: (Date.now() - started) / 1000 };
}

export async function check(text: string): Promise<Review> {
  const started = Date.now();
  const prompt = await runN(['prompt'], { text });
  const answer = await claude(prompt);
  const r = JSON.parse(await runN(['read'], { text, answer })) as { marks: Mark[] };
  return { marks: inUnits(text, r.marks), assessor: 'Claude Opus 5.5', seconds: (Date.now() - started) / 1000 };
}
