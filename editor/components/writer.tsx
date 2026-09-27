'use client';
import { useEffect, useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import type { Result } from '@/lib/checks';
import { useDictation } from './dictation';
import { place, Squiggles, type Placed } from './findings';

// A .n document, written and checked by N. Check saves the text and has N compile it in the background:
// the type check, lint and format, every fix N is sure of applied, and what is left marked in View mode as
// errors and warnings, each with its suggestions and a box for what the author means. The page can be left
// while N works; its result is there when the page comes back. An unsaved draft is kept on the Mac mini.
type Props = { name: string; initial: string; commit: (text: string) => Promise<void>; onText?: (text: string) => void };

export function Writer({ name, initial, commit, onText }: Props) {
  const [text, setText] = useState(initial); const [base, setBase] = useState(initial);
  const [status, setStatus] = useState(''); const [busy, setBusy] = useState(false);
  const [check, setCheck] = useState<Result | null>(null); const [intents, setIntents] = useState<Record<string, string>>({});
  // Edit: the text box. View: the text with N's errors and warnings under squiggles.
  const [mode, setMode] = useState<'edit' | 'view'>('edit');
  const area = useRef<HTMLTextAreaElement>(null);
  const latest = useRef(text); latest.current = text;
  useEffect(() => { onText?.(text); }, [text, onText]);

  const store = `/api/draft/${encodeURIComponent(`doc:${name}`)}`;
  const loaded = useRef(false);
  useEffect(() => {
    loaded.current = false;
    (async () => {
      let kept: string | null = null;
      try { const r = await fetch(store, { cache: 'no-store' }); if (r.ok) kept = (await r.json() as { text: string | null }).text; } catch {}
      const typed = area.current?.value ?? '';
      if (typed && typed !== initial) setText(typed); else if (kept !== null && kept !== initial) setText(kept);
      loaded.current = true;
    })();
  }, [store, initial]);
  const idle = text === base;
  useEffect(() => {
    if (!loaded.current) return;
    const timer = setTimeout(() => { void fetch(store, idle ? { method: 'DELETE' } : { method: 'PUT', body: text }).catch(() => {}); }, 400);
    return () => clearTimeout(timer);
  }, [text, idle, store]);
  useEffect(() => {
    const leave = () => { if (loaded.current && !idle) navigator.sendBeacon(store, text); };
    window.addEventListener('pagehide', leave);
    return () => window.removeEventListener('pagehide', leave);
  }, [text, idle, store]);

  // The last check, and while one runs, its progress. Once it is done, its fixed text replaces the text if
  // the text is still what N read.
  const applied = useRef(0);
  useEffect(() => {
    let stop = false;
    const look = async () => {
      try {
        const [r, i] = await Promise.all([fetch(`/api/check/${name}`, { cache: 'no-store' }), fetch(`/api/intent/${name}`, { cache: 'no-store' })]);
        const c = await r.json() as Result | null; const is = await i.json() as Array<{ quote: string; intent: string }>;
        if (stop) return;
        setCheck(c); setIntents(Object.fromEntries(is.map(x => [x.quote, x.intent])));
        if (c?.status === 'done' && applied.current !== c.started && latest.current === c.base) { applied.current = c.started; setText(c.text); setBase(c.text); if (c.errors.length || c.warnings.length) setMode('view'); }
        if (c?.status === 'running') setTimeout(look, 3000);
      } catch { if (!stop) setTimeout(look, 5000); }
    };
    void look();
    const back = () => { if (document.visibilityState === 'visible') void look(); };
    document.addEventListener('visibilitychange', back);
    return () => { stop = true; document.removeEventListener('visibilitychange', back); };
  }, [name, check?.status === 'running' ? check.started : 0]);

  const save = async (v = text) => {
    if (busy || v === base) return true;
    setBusy(true); setStatus('Saving…');
    try { await commit(v); setBase(v); setStatus('Saved'); return true; }
    catch (e) { setStatus((e as Error).message); return false; } finally { setBusy(false); }
  };
  const compile = async () => {
    if (!(await save())) return;
    const r = await fetch(`/api/check/${name}`, { method: 'POST' });
    if (!r.ok) { setStatus(await r.text()); return; }
    setCheck(await r.json() as Result); setStatus('');
  };
  useEffect(() => { const key = (e: KeyboardEvent) => { if ((e.metaKey || e.ctrlKey) && e.key === 's') { e.preventDefault(); void save(); } }; window.addEventListener('keydown', key); return () => window.removeEventListener('keydown', key); });

  // Dictation adds what was said to the end of the text.
  const { listening, toggle } = useDictation(said => {
    setText(current => current + (current && !/\s$/.test(current) && said ? ' ' : '') + said);
  }, setStatus);

  const found: Placed[] = check && check.status !== 'running' ? [...check.errors.map(f => ({ ...f, error: true })), ...check.warnings.map(f => ({ ...f, error: false }))] : [];
  const shown = place(text, found);
  const apply = (f: Placed, choice: string) => setText(text.slice(0, f.start) + choice + text.slice(f.end));
  const errors = shown.filter(f => f.error).length, warnings = shown.length - errors;
  const verdict = !check ? null
    : check.status === 'running' ? { tone: 'bg-stone-200 text-stone-700 dark:bg-zinc-800 dark:text-zinc-300', label: 'N is checking in the background: you can leave this page', spin: true }
    : check.status === 'failed' ? { tone: 'bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300', label: `N failed: ${check.error}`, spin: false }
    : !shown.length ? { tone: 'bg-green-100 text-green-800 dark:bg-green-950 dark:text-green-300', label: `✓ Compiles${check.fixed ? ` · fixed ${check.fixed}` : ''}`, spin: false }
    : { tone: errors ? 'bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300' : 'bg-orange-100 text-orange-800 dark:bg-orange-950 dark:text-orange-300', label: `${errors} error${errors === 1 ? '' : 's'}, ${warnings} warning${warnings === 1 ? '' : 's'}${check.fixed ? ` · fixed ${check.fixed}` : ''}`, spin: false };
  const stale = check?.status === 'done' && text !== check.text && text === base ? 'Edited since this check' : '';

  return <div className="flex flex-col gap-3">
    <div role="tablist" aria-label="Mode" className="flex gap-1 self-start rounded-lg border border-stone-200 p-1 dark:border-zinc-800">
      {(['edit', 'view'] as const).map(m => <button key={m} role="tab" aria-selected={mode === m} onClick={() => setMode(m)}
        className={`rounded-md px-3 py-1 text-sm ${mode === m ? 'bg-stone-900 text-white dark:bg-zinc-100 dark:text-zinc-900' : 'text-stone-600 dark:text-zinc-400'}`}>{m === 'edit' ? 'Edit' : 'View'}</button>)}
    </div>
    {mode === 'edit' ? <>
      <label htmlFor="writer" className="sr-only">Text</label>
      <textarea id="writer" ref={area} value={text} spellCheck onChange={e => { setText(e.target.value); setStatus(''); }}
        className="h-[70vh] w-full resize-y rounded-lg border border-stone-200 bg-transparent p-4 font-mono text-[15px] leading-relaxed outline-none focus:border-orange-700 dark:border-zinc-800" />
    </> : <Squiggles text={text} shown={shown} name={name} apply={apply} intents={intents} />}
    <div className="flex flex-wrap items-center gap-2">
      <Button onClick={compile} disabled={busy || check?.status === 'running'} className="rounded-md bg-stone-900 px-4 py-2 text-white hover:bg-orange-700 dark:bg-zinc-100 dark:text-zinc-900">Check</Button>
      <Button onClick={() => save()} disabled={busy} className="rounded-md border border-stone-300 px-4 py-2 hover:border-orange-700 dark:border-zinc-700">Save</Button>
      <Button onClick={toggle} aria-pressed={listening} className={`rounded-md border px-4 py-2 ${listening ? 'border-orange-700 bg-orange-700 text-white' : 'border-stone-300 hover:border-orange-700 dark:border-zinc-700'}`}>{listening ? 'Stop' : 'Dictate'}</Button>
      <Button onClick={() => navigator.clipboard.writeText(text)} className="rounded-md border border-stone-300 px-4 py-2 hover:border-orange-700 dark:border-zinc-700">Copy</Button>
      {verdict && <span role="status" aria-live="polite" className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-sm font-medium ${verdict.tone}`}>
        {verdict.spin && <span aria-hidden className="size-3 animate-spin rounded-full border-2 border-current border-t-transparent" />}{verdict.label}</span>}
      <span className="text-sm text-stone-500 dark:text-zinc-400">{[text !== base ? 'Unsaved' : '', stale, status].filter(Boolean).join(' · ')}</span>
    </div>
  </div>;
}
