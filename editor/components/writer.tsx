'use client';
import { useEffect, useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import type { Mark, Review } from '@/lib/n';

// Writing with N as it is written, like a code editor with its checker: each phrase with more than one
// reading is underlined in the text while you type. Jev screens the text as soon as typing pauses; N check
// reads the whole of it a moment later, and its findings replace Jev's. A finding's fix or reading replaces
// its phrase when chosen. A chat message is read against its chat (`context`). `commit` saves or sends the text, and a sent text leaves the box empty.
type Found = Mark & { quote: string; jev?: boolean };
type Props = { draft: string; context?: string; initial: string; commit: (text: string) => Promise<string | void>; label: string; clears?: boolean; rows?: string; onText?: (text: string) => void; placeholder?: string };

// A finding follows its phrase while the text around it changes, and is dropped once the phrase is gone.
function place(text: string, found: Found[]): Found[] {
  return found.flatMap(f => {
    if (text.slice(f.start, f.end) === f.quote) return [f];
    const near = text.indexOf(f.quote, Math.max(0, f.start - 400));
    const at = near >= 0 ? near : text.indexOf(f.quote);
    return at < 0 || !f.quote ? [] : [{ ...f, start: at, end: at + f.quote.length }];
  }).sort((a, b) => a.start - b.start).filter((f, i, all) => i === 0 || f.start >= all[i - 1].end);
}

const tone = (f: Found) => f.jev ? 'decoration-stone-400' : f.fixable ? 'decoration-sky-600' : f.level === 'error' || f.level === 'high' ? 'decoration-red-600' : 'decoration-orange-600';

export function Writer({ draft, context = '', initial, commit, label, clears, rows = 'h-[60vh]', onText, placeholder }: Props) {
  const [text, setText] = useState(initial); const [base, setBase] = useState(initial);
  const [found, setFound] = useState<Found[]>([]); const [by, setBy] = useState(''); const [checking, setChecking] = useState(false);
  const [status, setStatus] = useState(''); const [busy, setBusy] = useState(false);
  // What N last answered for: the text it read and how many findings it had, or why it failed.
  const [answered, setAnswered] = useState<{ text: string; count: number; error: string }>({ text: '', count: 0, error: '' });
  const [listening, setListening] = useState(false); const recorder = useRef<MediaRecorder | null>(null);
  const area = useRef<HTMLTextAreaElement>(null); const mirror = useRef<HTMLDivElement>(null);
  const latest = useRef(text); latest.current = text;
  useEffect(() => { onText?.(text); }, [text, onText]);
  // An unsent or unsaved draft outlives a reload, in this browser, until it is sent or saved; text typed
  // before the page came alive is kept too.
  const key = `n-draft:${draft}`;
  useEffect(() => {
    let kept: string | null = null;
    try { kept = localStorage.getItem(key); } catch {}
    const typed = area.current?.value ?? '';
    if (typed && typed !== initial) setText(typed); else if (kept !== null && kept !== initial) setText(kept);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  useEffect(() => { try { if (text === (clears ? '' : base)) localStorage.removeItem(key); else localStorage.setItem(key, text); } catch {} }, [text, base, key, clears]);

  const read = (v: string, r: Review, jev = false) => r.marks.map(m => ({ ...m, quote: v.slice(m.start, m.end), jev }));
  const byN = useRef(false);
  const ask = (v: string): RequestInit => context ? { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ text: v, conversation: context }) } : { method: 'POST', body: v };
  // Jev after a short pause, N check after a longer one. Jev's marks join N's earlier findings that still
  // hold; N's answer replaces them all, placed in the text as it is by then.
  useEffect(() => {
    if (!text.trim()) { setFound([]); setBy(''); return; }
    const v = text;
    const jev = setTimeout(async () => {
      try { const r = await fetch('/api/screen', ask(v)); const out = await r.json() as Review;
        if (!r.ok || !out.marks || latest.current !== v) return;
        setFound(fs => { const kept = byN.current ? place(v, fs) : []; const extra = read(v, out, true).filter(j => !kept.some(k => j.start < k.end && k.start < j.end)); return place(v, [...kept, ...extra]); });
        if (!byN.current) setBy('Jev');
      } catch {}
    }, 700);
    const n = setTimeout(async () => {
      setChecking(true);
      try { const r = await fetch('/api/check', ask(v)); const out = await r.json() as Review & { error?: string };
        if (!r.ok) throw Error(out.error || 'N check failed');
        setFound(place(latest.current, read(v, out))); setBy('N'); byN.current = true;
        setAnswered({ text: v, count: out.marks.length, error: '' });
      } catch (e) { setAnswered({ text: v, count: 0, error: (e as Error).message }); } finally { setChecking(false); }
    }, 2500);
    return () => { clearTimeout(jev); clearTimeout(n); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [text]);

  const shown = place(text, found);
  const edit = (v: string) => { setText(v); setStatus(''); };
  const apply = (f: Found, choice: string) => { const next = text.slice(0, f.start) + choice + text.slice(f.end); setText(next); setFound(fs => fs.filter(x => x !== f)); area.current?.focus(); };
  const pick = (f: Found) => { const a = area.current; if (!a) return; a.focus(); a.setSelectionRange(f.start, f.end); };
  const save = async () => {
    const v = text; if (busy || (!clears && v === base) || (clears && !v.trim())) return;
    setBusy(true); setStatus(clears ? 'Sending…' : 'Saving…');
    try { const out = await commit(v);
      if (clears) { setText(t => t === v ? '' : t); setFound([]); setBy(''); byN.current = false; setStatus('Sent'); }
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

  // The underlines: the same text behind the transparent box, each finding's phrase underlined.
  const pieces: React.ReactNode[] = []; let at = 0;
  for (const f of shown) { pieces.push(text.slice(at, f.start)); pieces.push(<mark key={f.start} className={`bg-transparent text-transparent underline decoration-wavy decoration-2 underline-offset-4 ${tone(f)}`}>{text.slice(f.start, f.end)}</mark>); at = f.end; }
  pieces.push(text.slice(at) + '\n');
  const box = 'w-full rounded-lg border p-4 font-mono text-[15px] leading-relaxed whitespace-pre-wrap break-words';
  // N's state for the text as it is now: waiting for a pause, reading, passed, findings to settle, or failed.
  const settle = shown.filter(f => !f.jev).length;
  const phase = !text.trim() ? null
    : checking ? { tone: 'bg-stone-200 text-stone-700 dark:bg-zinc-800 dark:text-zinc-300', label: 'N is reading…', spin: true }
    : answered.text === text && answered.error ? { tone: 'bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300', label: `N failed: ${answered.error}`, spin: false }
    : answered.text === text && !settle ? { tone: 'bg-green-100 text-green-800 dark:bg-green-950 dark:text-green-300', label: '✓ One reading', spin: false }
    : answered.text === text ? { tone: 'bg-orange-100 text-orange-800 dark:bg-orange-950 dark:text-orange-300', label: `${settle} to settle`, spin: false }
    : { tone: 'bg-stone-200 text-stone-700 dark:bg-zinc-800 dark:text-zinc-300', label: shown.some(f => f.jev) ? 'Jev flagged these · N reads when you pause' : 'N reads when you pause', spin: false };

  return <div className="flex flex-col gap-3">
    <div className="relative">
      <div ref={mirror} aria-hidden className={`${box} pointer-events-none absolute inset-0 overflow-hidden border-transparent text-transparent`}>{pieces}</div>
      <label htmlFor="writer" className="sr-only">Text</label>
      <textarea id="writer" ref={area} value={text} placeholder={placeholder} spellCheck onChange={e => edit(e.target.value)}
        onScroll={e => { if (mirror.current) mirror.current.scrollTop = e.currentTarget.scrollTop; }}
        className={`${box} ${rows} relative block resize-y border-stone-200 bg-transparent outline-none focus:border-orange-700 dark:border-zinc-800`} />
    </div>
    <div className="flex flex-wrap items-center gap-2">
      <Button onClick={save} disabled={busy} className="rounded-md bg-stone-900 px-4 py-2 text-white hover:bg-orange-700 dark:bg-zinc-100 dark:text-zinc-900">{label}</Button>
      <Button onClick={dictate} aria-pressed={listening} className={`rounded-md border px-4 py-2 ${listening ? 'border-orange-700 bg-orange-700 text-white' : 'border-stone-300 hover:border-orange-700 dark:border-zinc-700'}`}>{listening ? 'Stop' : 'Dictate'}</Button>
      <Button onClick={() => navigator.clipboard.writeText(text)} className="rounded-md border border-stone-300 px-4 py-2 hover:border-orange-700 dark:border-zinc-700">Copy</Button>
      {phase && <span role="status" aria-live="polite" className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-sm font-medium ${phase.tone}`}>
        {phase.spin && <span aria-hidden className="size-3 animate-spin rounded-full border-2 border-current border-t-transparent" />}{phase.label}</span>}
      <span className="text-sm text-stone-500 dark:text-zinc-400">{[!clears && text !== base ? 'Unsaved' : '', status].filter(Boolean).join(' · ')}</span>
    </div>
    {shown.length > 0 && <section aria-live="polite" className="flex flex-col gap-2">
      {shown.map(f => { const choices = [...new Set([...(f.fixable && f.new ? [f.new] : []), ...(f.options || [])])];
        return <div key={`${f.start}-${f.quote}`} className="flex flex-col gap-2 rounded-lg border border-stone-200 p-3 dark:border-zinc-800">
          <button onClick={() => pick(f)} className={`self-start text-left font-semibold underline decoration-wavy ${tone(f)}`}>{f.quote}</button>
          <p>{f.question || f.why}</p>
          {f.question && <p className="text-sm text-stone-500 dark:text-zinc-400">{f.why}</p>}
          {choices.length > 0 && <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap">{choices.map(c => <Button key={c} onClick={() => apply(f, c)} className="rounded-md border border-stone-300 px-3 py-2 text-left whitespace-normal hover:border-orange-700 dark:border-zinc-700">{c}</Button>)}</div>}
        </div>; })}
    </section>}
  </div>;
}
