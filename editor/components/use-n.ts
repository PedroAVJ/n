'use client';
import { useRef, useState } from 'react';
import type { Mark, Review, Which } from '@/lib/n';

// N's three checks, one at a time and in N.n's order: the type check, then lint, then format. A check
// unlocks once the one before it passes for the text as it is; editing the text by hand starts again
// from the type check, while choosing a check's reading does not. A finding follows its phrase while the text around it changes.
export type Found = Mark & { quote: string };
export type { Which };
export const order: Which[] = ['type', 'lint', 'format'];
export const names: Record<Which, string> = { type: 'Type check', lint: 'Lint', format: 'Format' };

export function place(text: string, found: Found[]): Found[] {
  return found.flatMap(f => {
    if (text.slice(f.start, f.end) === f.quote) return [f];
    const near = text.indexOf(f.quote, Math.max(0, f.start - 400));
    const at = near >= 0 ? near : text.indexOf(f.quote);
    return at < 0 || !f.quote ? [] : [{ ...f, start: at, end: at + f.quote.length }];
  }).sort((a, b) => a.start - b.start).filter((f, i, all) => i === 0 || f.start >= all[i - 1].end);
}

export const tone = (f: Found) => f.level === 'format' ? 'decoration-sky-600' : f.level === 'error' ? 'decoration-red-600' : 'decoration-orange-600';

export function useN(text: string) {
  const [found, setFound] = useState<Found[]>([]);
  const [running, setRunning] = useState<Which | null>(null);
  const [error, setError] = useState('');
  // How far the text has got: the checks it has passed (0 to 3), for the text as it was then.
  const [passed, setPassed] = useState({ count: 0, text: '' });
  const [current, setCurrent] = useState<Which | null>(null);
  const latest = useRef(text); latest.current = text;
  const read = (v: string, r: Review) => r.marks.map(m => ({ ...m, quote: v.slice(m.start, m.end) }));

  const shown = place(text, found);
  const done = passed.text === text ? passed.count : 0;
  const unlocked = (w: Which) => order.indexOf(w) <= done;
  const pass = (w: Which, v: string) => { setPassed({ count: order.indexOf(w) + 1, text: v }); setCurrent(null); };
  // A reading chosen from a check is not an edit by hand: the checks already passed still hold.
  const keep = (from: string, v: string) => setPassed(p => p.text === from ? { ...p, text: v } : p);

  // Runs one check on the text now and answers with its findings.
  const run = async (w: Which, v: string): Promise<Found[] | null> => {
    setRunning(w); setError(''); setCurrent(w);
    try {
      const r = await fetch('/api/check', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ text: v, check: w }) });
      const out = await r.json() as Review & { error?: string };
      if (!r.ok) throw Error(out.error || `${names[w]} failed`);
      const fs = read(v, out); setFound(place(latest.current, fs)); return fs;
    } catch (e) { setError((e as Error).message); return null; }
    finally { setRunning(null); }
  };
  const forget = (f: Found) => setFound(fs => fs.filter(x => x.quote !== f.quote || x.start !== f.start));
  return { shown, running, error, done, unlocked, pass, keep, run, forget, current };
}
