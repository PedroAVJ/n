'use client';
import { useEffect, useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import { names, useN, type Found, type Which } from './use-n';
import { fixable } from './fixes';
import { Checks, Findings } from './findings';

// Writing, checked by N when asked: Check makes every fix N is sure of and lists what it cannot fix, whose
// readings replace the phrase when chosen. `commit` saves the text.
type Props = { draft: string; initial: string; commit: (text: string) => Promise<string | void>; label: string; rows?: string; onText?: (text: string) => void };

export function Writer({ draft, initial, commit, label, rows = 'h-[60vh]', onText }: Props) {
  const [text, setText] = useState(initial); const [base, setBase] = useState(initial);
  const [status, setStatus] = useState(''); const [busy, setBusy] = useState(false);
  const [listening, setListening] = useState(false); const recorder = useRef<MediaRecorder | null>(null);
  const area = useRef<HTMLTextAreaElement>(null);
  const latest = useRef(text); latest.current = text;
  useEffect(() => { onText?.(text); }, [text, onText]);
  // An unsent or unsaved draft is kept on the Mac mini until it is sent or saved, so it outlives a reload
  // and is the same in Safari and the Home Screen app. Text typed before the page came alive is kept too.
  const store = `/api/draft/${encodeURIComponent(draft)}`;
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
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [store]);
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

  const { shown, running, error, done, unlocked, pass, keep, run, forget, current } = useN(text);
  // One of N's checks: it makes every fix it is sure of, from the end back so each phrase is still where N
  // found it; with nothing left to choose, the check passes and the next one unlocks.
  const check = async (w: Which) => {
    const v = text; const fs = await run(w, v); if (!fs) return;
    if (latest.current !== v) { setStatus('The text changed while N read it: run it again'); return; }
    const fix = fixable(fs); let next = v;
    for (const f of fix) next = next.slice(0, f.start) + f.new + next.slice(f.end);
    if (fix.length) { setText(next); fix.forEach(forget); }
    const left = fs.length - fix.length;
    if (!left) pass(w, next);
    setStatus(`${names[w]}: ${fix.length ? `fixed ${fix.length}` : 'nothing to fix'}${left ? `, ${left} to choose` : ', passed'}`);
  };
  const edit = (v: string) => { setText(v); setStatus(''); };
  // A reading or the writer's own rewrite replaces the phrase; the last one chosen passes the check.
  const apply = (f: Found, choice: string) => {
    const next = text.slice(0, f.start) + choice + text.slice(f.end); setText(next); forget(f);
    if (current && shown.length === 1) { pass(current, next); setStatus(`${names[current]}: passed`); } else keep(text, next);
    area.current?.focus();
  };
  const pick = (f: Found) => { const a = area.current; if (!a) return; a.focus(); a.setSelectionRange(f.start, f.end); };
  const save = async () => {
    const v = text; if (busy || v === base) return;
    setBusy(true); setStatus('Saving…');
    try { const out = await commit(v); const now = typeof out === 'string' ? out : v; setBase(now); setText(t => t === v ? now : t); setStatus('Saved'); }
    catch (e) { setStatus((e as Error).message); } finally { setBusy(false); }
  };
  useEffect(() => { const key = (e: KeyboardEvent) => { if ((e.metaKey || e.ctrlKey) && e.key === 's') { e.preventDefault(); void save(); } }; window.addEventListener('keydown', key); return () => window.removeEventListener('keydown', key); });

  // Dictation: record until pressed again, then ElevenLabs Scribe's text replaces the selection (or goes in at the cursor).
  const dictate = async () => {
    if (recorder.current) { recorder.current.stop(); return; }
    let stream: MediaStream;
    try { stream = await navigator.mediaDevices.getUserMedia({ audio: true }); } catch { setStatus('No microphone access'); return; }
    const chunks: Blob[] = []; const rec = new MediaRecorder(stream); recorder.current = rec;
    const at = { start: area.current?.selectionStart ?? text.length, end: area.current?.selectionEnd ?? text.length };
    rec.ondataavailable = e => { if (e.data.size) chunks.push(e.data); };
    rec.onstop = async () => {
      stream.getTracks().forEach(t => t.stop()); recorder.current = null; setListening(false); setStatus('Transcribing…');
      try {
        const blob = new Blob(chunks, { type: rec.mimeType || 'audio/webm' });
        const r = await fetch('/api/dictate', { method: 'POST', headers: { 'content-type': blob.type }, body: blob });
        const out = await r.json() as { text?: string; error?: string };
        if (!r.ok || out.text === undefined) throw Error(out.error || 'Dictation failed');
        const said = out.text;
        setText(current => { const before = current.slice(0, at.start), after = current.slice(at.end); const space = before && !/\s$/.test(before) && said ? ' ' : ''; return before + space + said + after; });
        setStatus('Dictated');
      } catch (e) { setStatus((e as Error).message); }
    };
    rec.start(); setListening(true); setStatus('Listening… press Dictate again to stop');
  };

  const box = 'w-full rounded-lg border p-4 font-mono text-[15px] leading-relaxed whitespace-pre-wrap break-words';
  return <div className="flex flex-col gap-3">
    <div>
      <label htmlFor="writer" className="sr-only">Text</label>
      <textarea id="writer" ref={area} value={text} spellCheck onChange={e => edit(e.target.value)}
        className={`${box} ${rows} relative block resize-y border-stone-200 bg-transparent outline-none focus:border-orange-700 dark:border-zinc-800`} />
    </div>
    <Checks done={done} unlocked={unlocked} running={running} run={check} />
    {error && <p role="alert" className="text-sm text-red-700 dark:text-red-400">{error}</p>}
    <div className="flex flex-wrap items-center gap-2">
      <Button onClick={save} disabled={busy} className="rounded-md bg-stone-900 px-4 py-2 text-white hover:bg-orange-700 dark:bg-zinc-100 dark:text-zinc-900">{label}</Button>
      <Button onClick={dictate} aria-pressed={listening} className={`rounded-md border px-4 py-2 ${listening ? 'border-orange-700 bg-orange-700 text-white' : 'border-stone-300 hover:border-orange-700 dark:border-zinc-700'}`}>{listening ? 'Stop' : 'Dictate'}</Button>
      <Button onClick={() => navigator.clipboard.writeText(text)} className="rounded-md border border-stone-300 px-4 py-2 hover:border-orange-700 dark:border-zinc-700">Copy</Button>
      <span className="text-sm text-stone-500 dark:text-zinc-400">{[text !== base ? 'Unsaved' : '', status].filter(Boolean).join(' · ')}</span>
    </div>
    <Findings shown={shown} pick={pick} apply={apply} />
  </div>;
}
