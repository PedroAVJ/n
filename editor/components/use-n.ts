'use client';
import { useRef, useState } from 'react';
import type { Mark, Review } from '@/lib/n';

// N when asked: Check has N read the whole text. A finding follows its phrase while the text around it
// changes, and is dropped once the phrase is gone.
export type Found = Mark & { quote: string };
export type Phase = { tone: string; label: string; spin: boolean } | null;

export function place(text: string, found: Found[]): Found[] {
  return found.flatMap(f => {
    if (text.slice(f.start, f.end) === f.quote) return [f];
    const near = text.indexOf(f.quote, Math.max(0, f.start - 400));
    const at = near >= 0 ? near : text.indexOf(f.quote);
    return at < 0 || !f.quote ? [] : [{ ...f, start: at, end: at + f.quote.length }];
  }).sort((a, b) => a.start - b.start).filter((f, i, all) => i === 0 || f.start >= all[i - 1].end);
}

export const tone = (f: Found) => f.fixable ? 'decoration-sky-600' : f.level === 'error' || f.level === 'high' ? 'decoration-red-600' : 'decoration-orange-600';

export function useN(text: string) {
  const [found, setFound] = useState<Found[]>([]); const [checking, setChecking] = useState(false);
  // What N last answered for: the text it read and how many findings it had, or why it failed.
  const [answered, setAnswered] = useState<{ text: string; count: number; error: string }>({ text: '', count: 0, error: '' });
  const latest = useRef(text); latest.current = text;
  const read = (v: string, r: Review) => r.marks.map(m => ({ ...m, quote: v.slice(m.start, m.end) }));

  const shown = place(text, found);
  // N's state: reading, or its answer for the text as it was when Check was pressed.
  const settle = shown.length;
  const phase: Phase = checking ? { tone: 'bg-stone-200 text-stone-700 dark:bg-zinc-800 dark:text-zinc-300', label: 'N is reading…', spin: true }
    : !answered.text ? null
    : answered.error ? { tone: 'bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300', label: `N failed: ${answered.error}`, spin: false }
    : answered.text !== text && !settle ? { tone: 'bg-stone-200 text-stone-700 dark:bg-zinc-800 dark:text-zinc-300', label: 'Changed since the check', spin: false }
    : !settle ? { tone: 'bg-green-100 text-green-800 dark:bg-green-950 dark:text-green-300', label: '✓ One reading', spin: false }
    : { tone: 'bg-orange-100 text-orange-800 dark:bg-orange-950 dark:text-orange-300', label: `${settle} to settle`, spin: false };
  // Check: N reads the text now and answers with its findings.
  const [busy, setBusy] = useState(false);
  const check = async (v: string): Promise<Found[]> => {
    setBusy(true); setChecking(true);
    try { const r = await fetch('/api/check', { method: 'POST', body: v }); const out = await r.json() as Review & { error?: string };
      if (!r.ok) throw Error(out.error || 'N check failed');
      const fs = read(v, out); setFound(place(latest.current, fs));
      setAnswered({ text: v, count: out.marks.length, error: '' });
      return fs;
    } catch (e) { setAnswered({ text: v, count: 0, error: (e as Error).message }); return []; }
    finally { setChecking(false); setBusy(false); }
  };
  const forget = (f: Found) => setFound(fs => fs.filter(x => x.quote !== f.quote || x.start !== f.start));
  return { shown, phase, forget, check, busy };
}
