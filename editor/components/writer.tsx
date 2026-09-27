'use client';
import { useEffect, useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import { CopyIcon, MicIcon, Spinner, TickIcon } from './icons';
import type { Result } from '@/lib/checks';
import { segments } from '@/lib/pages';
import { useDictation } from './dictation';
import { FindingSheet, keyOf, place, Squiggles, type Placed } from './findings';

// A .n document, written and checked by N. Check saves the text and has N compile it in the background:
// the type check, lint and format, every fix N is sure of applied, and what is left marked in View mode as
// errors and warnings, each with its suggestions and a box for what the author means. The page can be left
// while N works; its result is there when the page comes back. An unsaved draft is kept on the Mac mini.
type Props = { id: string; initial: string; commit: (text: string) => Promise<void>; onText?: (text: string) => void };

export function Writer({ id, initial, commit, onText }: Props) {
  const [text, setText] = useState(initial); const [base, setBase] = useState(initial);
  const [status, setStatus] = useState(''); const [busy, setBusy] = useState(false);
  const [check, setCheck] = useState<Result | null>(null); const [intents, setIntents] = useState<Record<string, string>>({});
  // Edit: the text box. View: the text with N's errors and warnings under squiggles.
  const [mode, setMode] = useState<'edit' | 'view'>('edit');
  const area = useRef<HTMLTextAreaElement>(null);
  const latest = useRef(text); latest.current = text;
  useEffect(() => { onText?.(text); }, [text, onText]);

  const store = `/api/draft/${encodeURIComponent(`doc:${id}`)}`;
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
        const [r, i] = await Promise.all([fetch(`/api/check/${segments(id)}`, { cache: 'no-store' }), fetch(`/api/intent/${segments(id)}`, { cache: 'no-store' })]);
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
  }, [id, check?.status === 'running' ? check.started : 0]);

  const save = async (v = text) => {
    if (busy || v === base) return true;
    setBusy(true); setStatus('Saving…');
    try { await commit(v); setBase(v); setStatus('Saved'); return true; }
    catch (e) { setStatus((e as Error).message); return false; } finally { setBusy(false); }
  };
  const compile = async () => {
    if (!(await save())) return;
    const r = await fetch(`/api/check/${segments(id)}`, { method: 'POST' });
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
  const [open, setOpen] = useState<string | null>(null);
  const chosen = shown.find(f => keyOf(f) === open);
  const [copied, setCopied] = useState(false);
  const copy = async () => { await navigator.clipboard.writeText(text); setCopied(true); setTimeout(() => setCopied(false), 1500); };
  // The text box grows with the text, so the page scrolls instead of the box.
  useEffect(() => { const a = area.current; if (!a) return; a.style.height = 'auto'; a.style.height = `${a.scrollHeight}px`; }, [text, mode]);

  // Where N stands: checking, failed, passing, or how many errors and warnings are left.
  const verdict = !check ? null
    : check.status === 'running' ? <span className="flex items-center gap-2 text-muted"><Spinner className="size-3.5" />Checking in the background: you can leave</span>
    : check.status === 'failed' ? <span className="truncate text-error">N failed: {check.error}</span>
    : !shown.length ? <span className="flex items-center gap-1.5 text-ok"><TickIcon className="size-4" />Compiles{check.fixed ? <span className="text-muted"> · {check.fixed} fixed</span> : null}</span>
    : <button onClick={() => { setMode('view'); setOpen(keyOf(shown[0])); }} className="flex items-center gap-3">
        {errors > 0 && <span className="flex items-center gap-1.5 text-error"><span className="size-2 rounded-full bg-current" />{errors} error{errors === 1 ? '' : 's'}</span>}
        {warnings > 0 && <span className="flex items-center gap-1.5 text-warning"><span className="size-2 rounded-full bg-current" />{warnings} warning{warnings === 1 ? '' : 's'}</span>}
        {check.fixed ? <span className="text-muted">{check.fixed} fixed</span> : null}
      </button>;
  const stale = check?.status === 'done' && text !== check.text && text === base ? 'Edited since this check' : '';
  const note = [status, stale].filter(Boolean).join(' · ');
  const prose = 'font-serif text-[18px] leading-[1.75] sm:text-[19px]';

  return <div className="flex flex-col">
    {mode === 'edit' ? <>
      <label htmlFor="writer" className="sr-only">Text</label>
      <textarea id="writer" ref={area} value={text} spellCheck placeholder="Start writing, or dictate…" onChange={e => { setText(e.target.value); setStatus(''); }}
        className={`${prose} min-h-[40dvh] w-full resize-none overflow-hidden bg-transparent outline-none placeholder:text-faint`} />
    </> : <Squiggles text={text} shown={shown} open={open} choose={setOpen} className={`${prose} min-h-[40dvh]`} />}

    <div className="pointer-events-none fixed inset-x-0 bottom-0 z-20 flex flex-col gap-2 pb-[max(0.75rem,env(safe-area-inset-bottom))]">
      {chosen ? <FindingSheet key={open ?? ''} f={chosen} text={text} id={id} apply={(f, c) => { apply(f, c); setOpen(null); }} kept={intents[chosen.quote]} close={() => setOpen(null)} />
      : <div className="pointer-events-auto mx-3 flex flex-col gap-1.5 rounded-2xl border border-line bg-surface/90 p-2 shadow-lg backdrop-blur-md sm:mx-auto sm:w-full sm:max-w-[680px]">
        {(verdict || note || text !== base) && <div role="status" aria-live="polite" className="flex min-h-6 items-center justify-between gap-3 px-2 text-sm">
          <span className="min-w-0 truncate">{verdict}</span>
          <span className="shrink-0 text-faint">{note || (text !== base ? 'Unsaved' : '')}</span>
        </div>}
        <div className="flex items-center gap-1.5">
          <div role="tablist" aria-label="Mode" className="flex rounded-full bg-hover p-0.5">
            {(['edit', 'view'] as const).map(m => <button key={m} role="tab" aria-selected={mode === m} onClick={() => { setMode(m); setOpen(null); }}
              className={`h-9 rounded-full px-3.5 text-sm font-medium transition-colors ${mode === m ? 'bg-surface text-ink shadow-sm' : 'text-muted'}`}>{m === 'edit' ? 'Edit' : 'View'}</button>)}
          </div>
          <div className="flex-1" />
          {text !== base && <Button variant="quiet" size="small" onClick={() => save()} disabled={busy}>Save</Button>}
          <Button variant="quiet" size="icon" onClick={toggle} aria-pressed={listening} aria-label={listening ? 'Stop dictating' : 'Dictate'} className={listening ? 'bg-error text-white hover:bg-error' : 'text-muted'}><MicIcon /></Button>
          <Button variant="quiet" size="icon" onClick={copy} aria-label="Copy the text" className="text-muted">{copied ? <TickIcon /> : <CopyIcon />}</Button>
          <Button onClick={compile} disabled={busy || check?.status === 'running'}>{check?.status === 'running' ? <Spinner /> : null}Check</Button>
        </div>
      </div>}
    </div>
  </div>;
}
