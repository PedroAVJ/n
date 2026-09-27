'use client';
import { useEffect, useRef, useState } from 'react';
import type { Mark, Review } from '@/lib/n';

// N as you write, like a code editor's checker: Jev screens the text as soon as typing pauses; N check reads
// the whole of it a moment later, and its findings replace Jev's. A finding follows its phrase while the
// text around it changes, and is dropped once the phrase is gone.
export type Found = Mark & { quote: string; jev?: boolean };
export type Phase = { tone: string; label: string; spin: boolean } | null;

export function place(text: string, found: Found[]): Found[] {
  return found.flatMap(f => {
    if (text.slice(f.start, f.end) === f.quote) return [f];
    const near = text.indexOf(f.quote, Math.max(0, f.start - 400));
    const at = near >= 0 ? near : text.indexOf(f.quote);
    return at < 0 || !f.quote ? [] : [{ ...f, start: at, end: at + f.quote.length }];
  }).sort((a, b) => a.start - b.start).filter((f, i, all) => i === 0 || f.start >= all[i - 1].end);
}

export const tone = (f: Found) => f.jev ? 'decoration-stone-400' : f.fixable ? 'decoration-sky-600' : f.level === 'error' || f.level === 'high' ? 'decoration-red-600' : 'decoration-orange-600';
export const highlight = (f: Found) => f.jev ? 'n-jev' : f.fixable ? 'n-fix' : f.level === 'error' || f.level === 'high' ? 'n-error' : 'n-ambiguous';

export function useN(text: string) {
  const [found, setFound] = useState<Found[]>([]); const [checking, setChecking] = useState(false);
  // What N last answered for: the text it read and how many findings it had, or why it failed.
  const [answered, setAnswered] = useState<{ text: string; count: number; error: string }>({ text: '', count: 0, error: '' });
  const latest = useRef(text); latest.current = text;
  const byN = useRef(false);
  const read = (v: string, r: Review, jev = false) => r.marks.map(m => ({ ...m, quote: v.slice(m.start, m.end), jev }));
  useEffect(() => {
    if (!text.trim()) { setFound([]); return; }
    const v = text;
    const jev = setTimeout(async () => {
      try { const r = await fetch('/api/screen', { method: 'POST', body: v }); const out = await r.json() as Review;
        if (!r.ok || !out.marks || latest.current !== v) return;
        setFound(fs => { const kept = byN.current ? place(v, fs) : []; const extra = read(v, out, true).filter(j => !kept.some(k => j.start < k.end && k.start < j.end)); return place(v, [...kept, ...extra]); });
      } catch {}
    }, 700);
    const n = setTimeout(async () => {
      setChecking(true);
      try { const r = await fetch('/api/check', { method: 'POST', body: v }); const out = await r.json() as Review & { error?: string };
        if (!r.ok) throw Error(out.error || 'N check failed');
        setFound(place(latest.current, read(v, out))); byN.current = true;
        setAnswered({ text: v, count: out.marks.length, error: '' });
      } catch (e) { setAnswered({ text: v, count: 0, error: (e as Error).message }); } finally { setChecking(false); }
    }, 2500);
    return () => { clearTimeout(jev); clearTimeout(n); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [text]);

  const shown = place(text, found);
  // N's state for the text as it is now: waiting for a pause, reading, passed, findings to settle, or failed.
  const settle = shown.filter(f => !f.jev).length;
  const phase: Phase = !text.trim() ? null
    : checking ? { tone: 'bg-stone-200 text-stone-700 dark:bg-zinc-800 dark:text-zinc-300', label: 'N is reading…', spin: true }
    : answered.text === text && answered.error ? { tone: 'bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300', label: `N failed: ${answered.error}`, spin: false }
    : answered.text === text && !settle ? { tone: 'bg-green-100 text-green-800 dark:bg-green-950 dark:text-green-300', label: '✓ One reading', spin: false }
    : answered.text === text ? { tone: 'bg-orange-100 text-orange-800 dark:bg-orange-950 dark:text-orange-300', label: `${settle} to settle`, spin: false }
    : { tone: 'bg-stone-200 text-stone-700 dark:bg-zinc-800 dark:text-zinc-300', label: shown.some(f => f.jev) ? 'Jev flagged these · N reads when you pause' : 'N reads when you pause', spin: false };
  const forget = (f: Found) => setFound(fs => fs.filter(x => x.quote !== f.quote || x.start !== f.start));
  const reset = () => { setFound([]); byN.current = false; };
  return { shown, phase, forget, reset };
}
