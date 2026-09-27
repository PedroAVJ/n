'use client';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { names, order, tone, type Found, type Which } from './use-n';

// The three checks as buttons, in order: one passed shows a tick, one not yet reachable is disabled.
export function Checks({ done, unlocked, running, run }: { done: number; unlocked: (w: Which) => boolean; running: Which | null; run: (w: Which) => void }) {
  return <div className="flex flex-wrap items-center gap-2">
    {order.map((w, i) => { const ok = i < done;
      return <Button key={w} onClick={() => run(w)} disabled={!!running || !unlocked(w)} aria-pressed={ok}
        className={`inline-flex items-center gap-1.5 rounded-md border px-4 py-2 ${ok ? 'border-green-700 bg-green-100 text-green-900 dark:bg-green-950 dark:text-green-200' : 'border-orange-700 text-orange-800 hover:bg-orange-700 hover:text-white dark:text-orange-300'}`}>
        {running === w && <span aria-hidden className="size-3 animate-spin rounded-full border-2 border-current border-t-transparent" />}
        {ok ? '✓ ' : ''}{names[w]}</Button>; })}
  </div>;
}

// Each finding a check could not fix: its phrase (chosen, it is selected in the text), N's question and
// reason, and its readings, any of which replaces the phrase, or the writer's own rewrite.
function Finding({ f, pick, apply }: { f: Found; pick: (f: Found) => void; apply: (f: Found, choice: string) => void }) {
  const [own, setOwn] = useState('');
  const choices = [...new Set([...(f.fixable && f.new ? [f.new] : []), ...(f.options || [])])];
  return <div className="flex flex-col gap-2 rounded-lg border border-stone-200 p-3 dark:border-zinc-800">
    <button onClick={() => pick(f)} className={`self-start text-left font-semibold underline decoration-wavy ${tone(f)}`}>{f.quote}</button>
    <p>{f.question || f.why}</p>
    {f.question && <p className="text-sm text-stone-500 dark:text-zinc-400">{f.why}</p>}
    {choices.length > 0 && <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap">{choices.map(c => <Button key={c} onClick={() => apply(f, c)} className="rounded-md border border-stone-300 px-3 py-2 text-left whitespace-normal hover:border-orange-700 dark:border-zinc-700">{c}</Button>)}</div>}
    <div className="flex gap-2">
      <label className="sr-only" htmlFor={`own-${f.start}`}>Your own rewrite</label>
      <input id={`own-${f.start}`} value={own} onChange={e => setOwn(e.target.value)} placeholder="Or write your own"
        className="flex-1 rounded-md border border-stone-300 bg-transparent px-3 py-2 outline-none focus:border-orange-700 dark:border-zinc-700" />
      <Button onClick={() => own.trim() && apply(f, own)} disabled={!own.trim()} className="rounded-md border border-stone-300 px-3 py-2 hover:border-orange-700 dark:border-zinc-700">Use</Button>
    </div>
  </div>;
}

export function Findings({ shown, pick, apply }: { shown: Found[]; pick: (f: Found) => void; apply: (f: Found, choice: string) => void }) {
  if (!shown.length) return null;
  return <section aria-live="polite" className="flex flex-col gap-2">{shown.map(f => <Finding key={`${f.start}-${f.quote}`} f={f} pick={pick} apply={apply} />)}</section>;
}
