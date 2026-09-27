import { mkdirSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { query } from '@anthropic-ai/claude-agent-sdk';

// Notion's hypermedia API is its website, and a website is read by a person or an agent, not a script: an
// agent with a browser, logged in as Pedro in a Chrome profile of N's own, answers N's findings there. Only
// there can a comment be anchored to a phrase, or an edit be suggested.
export type Finding = { block: string; text: string; quote: string } & ({ kind: 'comment'; comment: string[] } | { kind: 'suggest'; rewrite: string });
export type Outcome = { signedOut: boolean; done: number[] };

export const profile = process.env.N_NOTION_PROFILE || join(homedir(), 'Library/Application Support/N/notion-browser');
const here = dirname(fileURLToPath(import.meta.url));

// Chrome with its own keychain entry, so the profile can hold the Notion login copied from Pedro's Chrome.
function config(): string {
  const file = join(dirname(profile), 'notion-browser.json');
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, JSON.stringify({ browser: { browserName: 'chromium', userDataDir: profile,
    launchOptions: { channel: 'chrome', headless: true, ignoreDefaultArgs: ['--use-mock-keychain'] },
    contextOptions: { viewport: { width: 1280, height: 900 } } } }));
  return file;
}

function describe(f: Finding, i: number): string {
  const what = f.kind === 'comment'
    ? `COMMENT anchored to the quote, with exactly this text (one line each, Shift+Enter between lines):\n${f.comment.map(l => `    ${l}`).join('\n')}`
    : f.rewrite ? `SUGGEST replacing the quote with: ${JSON.stringify(f.rewrite)}` : 'SUGGEST deleting the quote';
  return `${i}. Block ${f.block}, whose text is ${JSON.stringify(f.text)}\n   Quote: ${JSON.stringify(f.quote)}\n   ${what}`;
}

function prompt(url: string, findings: Finding[]): string {
  return [
    `Open ${url} in the browser. It is logged in to Notion as Pedro, whose page it is. Answer each of N's findings below on the page, as Pedro would by hand.`,
    '',
    'A COMMENT is anchored to exactly the quote: select exactly those characters in that block (not the whole block, not more), then open the comment box (the Comment button in the toolbar that appears over a selection, or Cmd+Shift+M), type the text, and press Enter to post it.',
    'A SUGGEST is a suggested edit: first turn on Suggest edits (the page\'s ••• menu at the top right, then Suggest edits), then select exactly the quote and type the rewrite over it (or press Backspace to delete it), so Notion records it as a suggestion Pedro can accept or reject. Do all comments before turning on Suggest edits.',
    'Each block is the element with data-block-id equal to its id. To select exactly the quote you may set the DOM selection with a script over the text of that block\'s contenteditable element.',
    'Change nothing else on the page. Only type once the comment box or the selection is where it must be; if anything lands in the wrong place, undo it (Cmd+Z) until the page is as it was. Check each result on the page before counting it done.',
    'If the block already has a comment or suggested edit (from N, starting "N:", or Pedro\'s own) about the same thing, add nothing for that finding and count it done.',
    'If Notion asks to sign in, do nothing and answer {"signedOut": true, "done": []}.',
    '',
    'Findings:',
    ...findings.map((f, i) => describe(f, i + 1)),
    '',
    'Finish with only JSON: {"signedOut": false, "done": [the numbers of the findings you completed and checked]}.',
  ].join('\n');
}

export async function answer(url: string, findings: Finding[]): Promise<Outcome> {
  const abort = new AbortController();
  const timer = setTimeout(() => abort.abort(), 15 * 60_000);
  try {
    let result = '';
    for await (const message of query({ prompt: prompt(url, findings), options: {
      model: 'claude-opus-5-5', effort: 'medium', tools: [], settingSources: [], persistSession: false, maxTurns: 120, abortController: abort,
      mcpServers: { browser: { type: 'stdio', command: process.execPath, args: [join(here, 'node_modules/@playwright/mcp/cli.js'), '--config', config()] } },
      allowedTools: ['mcp__browser'],
      systemPrompt: 'You are N\'s hands on Notion\'s website: you place the suggested edits and comments N found, exactly as asked, and touch nothing else.',
    } })) {
      if (message.type !== 'result') continue;
      if (message.subtype !== 'success') throw Error(`the agent ended: ${message.subtype}`);
      result = message.result;
    }
    const json = result.slice(result.indexOf('{'), result.lastIndexOf('}') + 1);
    const r = JSON.parse(json) as Outcome;
    return { signedOut: !!r.signedOut, done: Array.isArray(r.done) ? r.done : [] };
  } finally { clearTimeout(timer); }
}
