'use client';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import type { Finding } from '@/lib/checks';
import { useDictation } from './dictation';

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

// An error or a warning: where it is, its phrase (chosen, it is selected in the text), N's question and reason, its
// suggestions, any of which replaces the phrase, and the author's intent, typed or dictated, which the next
// Check takes into account.
function One({ f, text, name, pick, apply, kept }: { f: Placed; text: string; name: string; pick: (f: Placed) => void; apply: (f: Placed, choice: string) => void; kept?: string }) {
  const [intent, setIntent] = useState(kept ?? ''); const [note, setNote] = useState(kept ? 'Kept for the next Check' : '');
  const keep = async (v: string) => {
    const r = await fetch(`/api/intent/${name}`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ quote: f.quote, intent: v }) });
    setNote(r.ok ? (v.trim() ? 'Kept for the next Check' : '') : await r.text());
  };
  const { listening, toggle } = useDictation(said => { const v = intent ? `${intent} ${said}` : said; setIntent(v); void keep(v); }, setNote);
  const choices = [...new Set([...(f.fixable && f.new ? [f.new] : []), ...(f.options || [])])];
  const c = around(text, f.start, f.end);
  return <div className={`flex flex-col gap-2 rounded-lg border p-3 ${f.error ? 'border-red-300 dark:border-red-900' : 'border-orange-300 dark:border-orange-900'}`}>
    <div className="flex items-baseline gap-2">
      <span className={`rounded px-1.5 text-xs font-semibold uppercase ${f.error ? 'bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300' : 'bg-orange-100 text-orange-800 dark:bg-orange-950 dark:text-orange-300'}`}>{f.error ? 'Error' : 'Warning'}</span>
      <button onClick={() => pick(f)} className="text-left font-semibold underline decoration-dotted">{f.quote}</button>
    </div>
    <blockquote className="border-l-2 border-stone-300 pl-3 text-sm leading-relaxed text-stone-600 dark:border-zinc-700 dark:text-zinc-400">
      {c.cut[0] ? '… ' : ''}{c.before}<mark className={`rounded px-0.5 font-medium text-inherit ${f.error ? 'bg-red-200/70 dark:bg-red-900/60' : 'bg-orange-200/70 dark:bg-orange-900/60'}`}>{f.quote}</mark>{c.after}{c.cut[1] ? ' …' : ''}
    </blockquote>
    <p>{f.question || f.why}</p>
    {f.question && <p className="text-sm text-stone-500 dark:text-zinc-400">{f.why}</p>}
    {choices.length > 0 && <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap">{choices.map(c => <Button key={c} onClick={() => apply(f, c)} className="rounded-md border border-stone-300 px-3 py-2 text-left whitespace-normal hover:border-orange-700 dark:border-zinc-700">{c}</Button>)}</div>}
    <div className="flex gap-2">
      <label className="sr-only" htmlFor={`intent-${f.start}`}>What you mean</label>
      <textarea id={`intent-${f.start}`} rows={2} value={intent} onChange={e => setIntent(e.target.value)} onBlur={() => keep(intent)} placeholder="Or say what you mean; the next Check takes it into account"
        className="flex-1 rounded-md border border-stone-300 bg-transparent px-3 py-2 outline-none focus:border-orange-700 dark:border-zinc-700" />
      <Button onClick={toggle} aria-pressed={listening} className={`rounded-md border px-3 py-2 ${listening ? 'border-orange-700 bg-orange-700 text-white' : 'border-stone-300 hover:border-orange-700 dark:border-zinc-700'}`}>{listening ? 'Stop' : 'Dictate'}</Button>
    </div>
    {note && <p className="text-sm text-stone-500 dark:text-zinc-400">{note}</p>}
  </div>;
}

export function Findings({ shown, text, name, pick, apply, intents }: { shown: Placed[]; text: string; name: string; pick: (f: Placed) => void; apply: (f: Placed, choice: string) => void; intents: Record<string, string> }) {
  if (!shown.length) return null;
  return <section aria-live="polite" className="flex flex-col gap-2">{shown.map(f => <One key={`${f.start}-${f.quote}`} f={f} text={text} name={name} pick={pick} apply={apply} kept={intents[f.quote]} />)}</section>;
}
