'use client';
import { useEffect, useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import { useN, type Found } from './use-n';
import { fixable } from './fixes';
import { Findings, PhaseBadge } from './findings';

// Writing, checked by N when asked: Check makes every fix N is sure of and lists what it cannot fix, whose
// readings replace the phrase when chosen. `commit` saves or sends the text, and a sent text leaves the
// box empty.
type Props = { draft: string; initial: string; commit: (text: string) => Promise<string | void>; label: string; clears?: boolean; rows?: string; onText?: (text: string) => void; placeholder?: string };

export function Writer({ draft, initial, commit, label, clears, rows = 'h-[60vh]', onText, placeholder }: Props) {
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
  const idle = text === (clears ? '' : base);
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

  const { shown, phase, forget, reset, check, busy: checking } = useN(text);
  // Check: N reads the text now; every fix it is sure of is made, from the end back so each phrase is
  // still where N found it, and what it cannot fix is left to choose.
  const autofix = async () => {
    const v = text; const fs = fixable(await check(v));
    if (latest.current !== v) { setStatus('The text changed while N read it: check again'); return; }
    let next = v; for (const f of fs) next = next.slice(0, f.start) + f.new + next.slice(f.end);
    if (fs.length) { setText(next); fs.forEach(forget); }
    setStatus(fs.length ? `Fixed ${fs.length}` : '');
  };
  const edit = (v: string) => { setText(v); setStatus(''); };
  const apply = (f: Found, choice: string) => { const next = text.slice(0, f.start) + choice + text.slice(f.end); setText(next); forget(f); area.current?.focus(); };
  const pick = (f: Found) => { const a = area.current; if (!a) return; a.focus(); a.setSelectionRange(f.start, f.end); };
  const save = async () => {
    const v = text; if (busy || (!clears && v === base) || (clears && !v.trim())) return;
    setBusy(true); setStatus(clears ? 'Sending…' : 'Saving…');
    try { const out = await commit(v);
      if (clears) { setText(t => t === v ? '' : t); reset(); setStatus('Sent'); }
      else { const now = typeof out === 'string' ? out : v; setBase(now); setText(t => t === v ? now : t); setStatus('Saved'); }
    } catch (e) { setStatus((e as Error).message); } finally { setBusy(false); }
  };
  useEffect(() => { const key = (e: KeyboardEvent) => { if ((e.metaKey || e.ctrlKey) && (e.key === 's' || (clears && e.key === 'Enter'))) { e.preventDefault(); void save(); } }; window.addEventListener('keydown', key); return () => window.removeEventListener('keydown', key); });

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
      <textarea id="writer" ref={area} value={text} placeholder={placeholder} spellCheck onChange={e => edit(e.target.value)}
        className={`${box} ${rows} relative block resize-y border-stone-200 bg-transparent outline-none focus:border-orange-700 dark:border-zinc-800`} />
    </div>
    <div className="flex flex-wrap items-center gap-2">
      <Button onClick={save} disabled={busy} className="rounded-md bg-stone-900 px-4 py-2 text-white hover:bg-orange-700 dark:bg-zinc-100 dark:text-zinc-900">{label}</Button>
      <Button onClick={autofix} disabled={checking || !text.trim()} className="rounded-md border border-orange-700 px-4 py-2 text-orange-800 hover:bg-orange-700 hover:text-white dark:text-orange-300">Check</Button>
      <Button onClick={dictate} aria-pressed={listening} className={`rounded-md border px-4 py-2 ${listening ? 'border-orange-700 bg-orange-700 text-white' : 'border-stone-300 hover:border-orange-700 dark:border-zinc-700'}`}>{listening ? 'Stop' : 'Dictate'}</Button>
      <Button onClick={() => navigator.clipboard.writeText(text)} className="rounded-md border border-stone-300 px-4 py-2 hover:border-orange-700 dark:border-zinc-700">Copy</Button>
      <PhaseBadge phase={phase} />
      <span className="text-sm text-stone-500 dark:text-zinc-400">{[!clears && text !== base ? 'Unsaved' : '', status].filter(Boolean).join(' · ')}</span>
    </div>
    <Findings shown={shown} pick={pick} apply={apply} />
  </div>;
}
