'use client';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import type { Finding } from '@/lib/checks';
import { segments } from '@/lib/pages';
import { useDictation } from './dictation';
import { CloseIcon, MicIcon } from './icons';

// A finding follows its phrase while the text around it changes, and is dropped once the phrase is gone.
export type Placed = Finding & { error: boolean };
export function place(text: string, found: Placed[]): Placed[] {
  return found.flatMap(f => {
    const near = text.indexOf(f.quote, Math.max(0, f.start - 400));
    const at = text.slice(f.start, f.end) === f.quote ? f.start : near >= 0 ? near : text.indexOf(f.quote);
    return at < 0 || !f.quote ? [] : [{ ...f, start: at, end: at + f.quote.length }];
  }).sort((a, b) => a.start - b.start);
}

// Where a phrase is: the sentence before it, its own sentence and the one after, the phrase marked.
const ends = /[.!?]["')\]]*\s+|\n{2,}/g;
function around(text: string, start: number, end: number) {
  const cuts = [0, ...[...text.matchAll(ends)].map(m => m.index + m[0].length), text.length];
  const from = cuts.filter(c => c <= start).slice(-2)[0] ?? 0;
  const to = cuts.filter(c => c >= end).slice(0, 2).pop() ?? text.length;
  return { before: text.slice(from, start), after: text.slice(end, to).trimEnd(), cut: [from > 0, to < text.length] };
}

// An error or a warning, in a sheet over the bottom of the page: where it is, N's question and reason, its
// suggestions (any of which replaces the phrase), and what the author means, typed or dictated, which the
// next Check takes into account.
export function FindingSheet({ f, text, id, apply, kept, close }: { f: Placed; text: string; id: string; apply: (f: Placed, choice: string) => void; kept?: string; close: () => void }) {
  const [intent, setIntent] = useState(kept ?? ''); const [note, setNote] = useState(kept ? 'Kept for the next Check' : '');
  const keep = async (v: string) => {
    const r = await fetch(`/api/intent/${segments(id)}`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ quote: f.quote, intent: v }) });
    setNote(r.ok ? (v.trim() ? 'Kept for the next Check' : '') : await r.text());
  };
  const { listening, toggle } = useDictation(said => { const v = intent ? `${intent} ${said}` : said; setIntent(v); void keep(v); }, setNote);
  const choices = [...new Set([...(f.fixable && f.new ? [f.new] : []), ...(f.options || [])])];
  const c = around(text, f.start, f.end);
  const tint = f.error ? 'text-error' : 'text-warning';
  return <div role="dialog" aria-label={f.error ? 'Error' : 'Warning'} className="pointer-events-auto mx-3 flex max-h-[72dvh] flex-col overflow-hidden rounded-2xl border border-line bg-surface shadow-2xl sm:mx-auto sm:w-full sm:max-w-[680px]">
    <div className="flex items-center justify-between border-b border-line px-4 py-2.5">
      <span className={`flex items-center gap-2 text-sm font-semibold ${tint}`}><span className="size-2 rounded-full bg-current" />{f.error ? 'Error' : 'Warning'}</span>
      <Button variant="quiet" size="icon" onClick={close} aria-label="Close" className="size-8"><CloseIcon className="size-4" /></Button>
    </div>
    <div className="flex flex-col gap-4 overflow-y-auto px-4 py-4">
      <blockquote className="font-serif text-[17px] leading-relaxed text-muted">
        {c.cut[0] ? '… ' : ''}{c.before}<mark className={`rounded-sm px-0.5 text-ink ${f.error ? 'bg-error/15' : 'bg-warning/20'}`}>{f.quote}</mark>{c.after}{c.cut[1] ? ' …' : ''}
      </blockquote>
      <div className="flex flex-col gap-1">
        <p className="text-[15px] font-medium">{f.question || f.why}</p>
        {f.question && <p className="text-sm leading-relaxed text-muted">{f.why}</p>}
      </div>
      {choices.length > 0 && <div className="flex flex-col gap-2">
        {choices.map(choice => <button key={choice} onClick={() => apply(f, choice)} className="rounded-xl border border-line px-3.5 py-2.5 text-left font-serif text-[16px] leading-snug hover:border-accent hover:bg-hover">{choice}</button>)}
      </div>}
      <div className="flex flex-col gap-1.5">
        <label className="text-sm text-muted" htmlFor={`intent-${f.start}`}>Or say what you mean</label>
        <div className="flex items-end gap-2 rounded-xl border border-line px-3 py-2 focus-within:border-accent">
          <textarea id={`intent-${f.start}`} rows={1} value={intent} onChange={e => setIntent(e.target.value)} onBlur={() => keep(intent)} placeholder="The next Check takes it into account"
            className="min-h-6 flex-1 resize-none bg-transparent text-[15px] leading-6 outline-none placeholder:text-faint" />
          <Button variant={listening ? 'default' : 'quiet'} size="icon" onClick={toggle} aria-pressed={listening} aria-label={listening ? 'Stop dictating' : 'Dictate'} className={`size-8 ${listening ? 'bg-error text-white' : 'text-muted'}`}><MicIcon className="size-[18px]" /></Button>
        </div>
        {note && <p className="text-sm text-muted">{note}</p>}
      </div>
    </div>
  </div>;
}

// View mode: the text as it reads, each error under a red squiggle and each warning under an amber one;
// tapping one opens it.
export function Squiggles({ text, shown, open, choose, className }: { text: string; shown: Placed[]; open: string | null; choose: (key: string | null) => void; className: string }) {
  const pieces: React.ReactNode[] = []; let at = 0;
  for (const f of shown) {
    if (f.start < at) continue;
    const key = keyOf(f);
    pieces.push(text.slice(at, f.start));
    // A span, not a button: a button will not flow inside a line of text.
    pieces.push(<span key={key} role="button" tabIndex={0} aria-label={`${f.error ? 'Error' : 'Warning'}: ${f.quote}`} onClick={() => choose(open === key ? null : key)}
      onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); choose(open === key ? null : key); } }}
      className={`cursor-pointer rounded-sm underline decoration-wavy decoration-[1.5px] underline-offset-[5px] ${f.error ? 'decoration-error' : 'decoration-warning'} ${open === key ? (f.error ? 'bg-error/15' : 'bg-warning/20') : 'hover:bg-hover'}`}>{text.slice(f.start, f.end)}</span>);
    at = f.end;
  }
  pieces.push(text.slice(at));
  return <div className={`${className} whitespace-pre-wrap break-words`}>{pieces}</div>;
}
export const keyOf = (f: Placed) => `${f.start}-${f.quote}`;
