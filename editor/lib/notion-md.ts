// A Notion page as Notion shows it, from its enhanced Markdown and back. Each line is a block: a heading,
// a list item, a to-do, a quote or a paragraph is written in place with its formatting; anything else (a
// child page, a divider, a table, code) is shown as it is and kept as it was. Saving writes a block back
// exactly as Notion gave it unless it was edited.
export type Kind = 'p' | 'h1' | 'h2' | 'h3' | 'ul' | 'ol' | 'todo' | 'done' | 'quote' | 'fixed';
export type Block = { raw: string; kind: Kind; prefix: string; body: string; indent: number };

const escapeHtml = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

// Tags that span several lines until they close (tables, toggles, callouts, columns) and code fences are
// one fixed block each.
export function parse(raw: string): Block[] {
  const lines = raw.split('\n'); const out: Block[] = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const fence = /^\s*```/.test(line);
    const opens = /^\s*<(table|details|callout|columns|column|summary|synced_block|audio|video|file|pdf|image|embed|bookmark|equation|toc)\b/.exec(line)?.[1];
    if (fence || (opens && !line.includes(`</${opens}>`))) {
      const closed = (l: string) => fence ? /^\s*```\s*$/.test(l) : l.includes(`</${opens}>`);
      let j = i + 1; while (j < lines.length && !closed(lines[j])) j++;
      j = Math.min(j, lines.length - 1);
      out.push({ raw: lines.slice(i, j + 1).join('\n'), kind: 'fixed', prefix: '', body: '', indent: 0 });
      i = j; continue;
    }
    const indent = /^\t*/.exec(line)![0].length + Math.floor((/^ */.exec(line.replace(/^\t*/, ''))![0].length) / 2);
    const m = /^(\s*)(#{1,3} |[-*+] \[[ xX]\] |[-*+] |\d+\. |> )?([\s\S]*)$/.exec(line)!;
    const marker = m[2] ?? '', body = m[3];
    if (/^\s*(---|\*\*\*|___)\s*$/.test(line) || /^\s*<(?!empty-block\b)[a-z][\w-]*[^>]*\/>\s*$/.test(line) || (/^\s*<page\b/.test(line) && !marker)) {
      out.push({ raw: line, kind: 'fixed', prefix: '', body: '', indent }); continue;
    }
    const kind: Kind = marker.startsWith('#') ? (`h${marker.trim().length}` as Kind) : /\[[xX]\]/.test(marker) ? 'done' : marker.includes('[') ? 'todo'
      : /^[-*+] $/.test(marker) ? 'ul' : /^\d+\. $/.test(marker) ? 'ol' : marker === '> ' ? 'quote' : 'p';
    out.push({ raw: line, kind, prefix: m[1] + marker, body: /^\s*<empty-block\/>\s*$/.test(body) ? '' : body, indent });
  }
  return out;
}

// ---- inline Markdown to HTML ----
const inlineToken = /(<span discussion-urls="[^"]*">)|(<\/span>)|(<(mention-[\w-]+|page)\b[^>]*?(?:\/>|>[\s\S]*?<\/\4>))|(<[a-zA-Z][^>]*>|<\/[a-zA-Z][^>]*>)|\[([^\]]*)\]\(([^)\s]*)\)|(\\[\\`*_{}\[\]()#+\-.!~<>|])|(\*\*)|(\*)|(~~)|(`)/g;

export function inlineHtml(body: string): string {
  let html = '', last = 0; const open: Array<{ tag: string; html: string }> = [];
  const start = (tag: string, h = `<${tag}>`) => { html += h; open.push({ tag, html: h }); };
  // Closing a tag that others opened inside of closes them, then opens them again after it.
  const close = (i: number) => { const above = open.splice(i); html += [...above].reverse().map(t => `</${t.tag}>`).join(''); for (const t of above.slice(1)) start(t.tag, t.html); };
  const toggle = (tag: string) => { const i = open.findLastIndex(t => t.tag === tag); if (i >= 0) close(i); else start(tag); };
  for (const m of body.matchAll(inlineToken)) {
    html += escapeHtml(body.slice(last, m.index)); last = m.index + m[0].length;
    if (m[1]) start('span', `<span class="n-comment" data-open="${escapeHtml(m[1])}">`);
    else if (m[2]) { const i = open.findLastIndex(t => t.tag === 'span'); if (i >= 0) close(i); }
    else if (m[3]) { const text = m[3].replace(/<[^>]+>/g, '') || m[3].match(/url="([^"]*)"/)?.[1] || '@'; const url = m[3].match(/url="([^"]*)"/)?.[1];
      html += `<a class="n-chip" contenteditable="false" data-raw="${escapeHtml(m[3])}"${url ? ` href="${escapeHtml(url)}"` : ''}>${escapeHtml(text)}</a>`; }
    else if (m[5]) html += `<span class="n-chip" contenteditable="false" data-raw="${escapeHtml(m[5])}">${escapeHtml(m[5])}</span>`;
    else if (m[7] !== undefined) html += `<a href="${escapeHtml(m[7])}" data-link="1">${escapeHtml(m[6])}</a>`;
    else if (m[8]) html += escapeHtml(m[8].slice(1));
    else if (m[9]) toggle('strong');
    else if (m[10]) toggle('em');
    else if (m[11]) toggle('s');
    else if (m[12]) toggle('code');
  }
  html += escapeHtml(body.slice(last)) + open.reverse().map(t => `</${t.tag}>`).join('');
  return html;
}

export function blockHtml(b: Block, i: number): string {
  if (b.kind === 'fixed') {
    const page = /<page url="([^"]*)">([\s\S]*?)<\/page>/.exec(b.raw);
    const shown = page ? `<a class="n-page" href="${escapeHtml(page[1])}">📄 ${escapeHtml(page[2])}</a>` : /^\s*(---|\*\*\*|___)\s*$/.test(b.raw) ? '<hr>' : `<pre>${escapeHtml(b.raw)}</pre>`;
    return `<div data-b="${i}" data-kind="fixed" contenteditable="false" style="margin-left:${b.indent * 1.5}rem">${shown}</div>`;
  }
  return `<div data-b="${i}" data-kind="${b.kind}" style="margin-left:${b.indent * 1.5}rem">${inlineHtml(b.body) || '<br>'}</div>`;
}
export const pageHtml = (blocks: Block[]) => blocks.map(blockHtml).join('');

// ---- the edited page back to Markdown ----
const escapeMd = (s: string) => s.replace(/\\/g, '\\\\').replace(/([*_`<]|~~)/g, '\\$1');

// Emphasis hugs its words: spaces at its edges go outside the markers, or Markdown would not read it.
const wrap = (m: string, inner: string) => { const [, lead, core, trail] = /^(\s*)([\s\S]*?)(\s*)$/.exec(inner)!; return core ? `${lead}${m}${core}${m}${trail}` : inner; };

export function inlineMd(node: Node): string {
  let out = '';
  node.childNodes.forEach(c => {
    if (c.nodeType === Node.TEXT_NODE) { out += escapeMd((c.textContent ?? '').replace(/ /g, ' ')); return; }
    if (!(c instanceof HTMLElement)) return;
    const raw = c.getAttribute('data-raw'); if (raw) { out += raw; return; }
    const tag = c.tagName.toLowerCase(), inner = inlineMd(c);
    if (c.classList.contains('n-comment')) out += (c.getAttribute('data-open') ?? '') + inner + '</span>';
    else if (tag === 'strong' || tag === 'b') out += wrap('**', inner);
    else if (tag === 'em' || tag === 'i') out += wrap('*', inner);
    else if (tag === 's' || tag === 'del' || tag === 'strike') out += wrap('~~', inner);
    else if (tag === 'code') out += inner ? '`' + (c.textContent ?? '') + '`' : '';
    else if (tag === 'a') out += `[${inner}](${c.getAttribute('href') ?? ''})`;
    else if (tag === 'br') out += '';
    else out += inner;
  });
  return out;
}

// Each block of the edited page: one Notion gave, kept exactly when unchanged; one it split (Enter) keeps
// its kind; a new one is a paragraph. `canon` is what each given block serializes to before any edit.
export function pageMd(root: HTMLElement, blocks: Block[], canon: string[]): string {
  const used = new Set<number>(); const lines: string[] = [];
  root.childNodes.forEach(n => {
    if (!(n instanceof HTMLElement)) { const t = (n.textContent ?? '').trim(); if (t) lines.push(escapeMd(t)); return; }
    const i = Number(n.getAttribute('data-b')); const b = Number.isInteger(i) && n.hasAttribute('data-b') ? blocks[i] : undefined;
    if (b?.kind === 'fixed') { lines.push(b.raw); used.add(i); return; }
    const body = inlineMd(n);
    if (b && !used.has(i) && body === canon[i]) { lines.push(b.raw); used.add(i); return; }
    if (b && !used.has(i)) used.add(i);
    const prefix = b ? b.prefix.replace(/\[[xX]\]/, n.getAttribute('data-kind') === 'done' ? '[x]' : '[ ]') : '';
    lines.push(prefix + (body.trim() ? body : prefix ? body : '<empty-block/>'));
  });
  return lines.join('\n');
}

// What N reads: each block's text, blocks apart by a blank line, and where each text node sits in it.
export function textOf(root: HTMLElement): { text: string; nodes: Array<{ node: Text; at: number }> } {
  let text = ''; const nodes: Array<{ node: Text; at: number }> = [];
  root.childNodes.forEach(block => {
    if (text) text += '\n\n';
    const walk = document.createTreeWalker(block, NodeFilter.SHOW_TEXT);
    let t: Node | null;
    while ((t = walk.nextNode())) { nodes.push({ node: t as Text, at: text.length }); text += (t as Text).data; }
  });
  return { text, nodes };
}

export function rangeAt(nodes: Array<{ node: Text; at: number }>, start: number, end: number): Range | null {
  const s = nodes.find(n => start >= n.at && start <= n.at + n.node.data.length);
  const e = [...nodes].reverse().find(n => end >= n.at && end <= n.at + n.node.data.length);
  if (!s || !e) return null;
  const r = document.createRange(); r.setStart(s.node, start - s.at); r.setEnd(e.node, end - e.at); return r;
}
