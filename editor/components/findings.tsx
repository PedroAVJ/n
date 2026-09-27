'use client';
import { Button } from '@/components/ui/button';
import { tone, type Found, type Phase } from './use-n';

export function PhaseBadge({ phase }: { phase: Phase }) {
  if (!phase) return null;
  return <span role="status" aria-live="polite" className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-sm font-medium ${phase.tone}`}>
    {phase.spin && <span aria-hidden className="size-3 animate-spin rounded-full border-2 border-current border-t-transparent" />}{phase.label}</span>;
}

// Each finding: its phrase (chosen, it is selected in the text), N's question and reason, and its fix or
// readings, any of which replaces the phrase.
export function Findings({ shown, pick, apply }: { shown: Found[]; pick: (f: Found) => void; apply: (f: Found, choice: string) => void }) {
  if (!shown.length) return null;
  return <section aria-live="polite" className="flex flex-col gap-2">
    {shown.map(f => { const choices = [...new Set([...(f.fixable && f.new ? [f.new] : []), ...(f.options || [])])];
      return <div key={`${f.start}-${f.quote}`} className="flex flex-col gap-2 rounded-lg border border-stone-200 p-3 dark:border-zinc-800">
        <button onClick={() => pick(f)} className={`self-start text-left font-semibold underline decoration-wavy ${tone(f)}`}>{f.quote}</button>
        <p>{f.question || f.why}</p>
        {f.question && <p className="text-sm text-stone-500 dark:text-zinc-400">{f.why}</p>}
        {choices.length > 0 && <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap">{choices.map(c => <Button key={c} onClick={() => apply(f, c)} className="rounded-md border border-stone-300 px-3 py-2 text-left whitespace-normal hover:border-orange-700 dark:border-zinc-700">{c}</Button>)}</div>}
      </div>; })}
  </section>;
}
