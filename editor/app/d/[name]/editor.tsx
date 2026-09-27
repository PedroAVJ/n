'use client';
import Link from 'next/link';
import MarkdownIt from 'markdown-it';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import type { Mark, Review } from '@/lib/n';

const md = new MarkdownIt({ html: false, linkify: true });
const titleOf = (text: string, fallback: string) => text.match(/^#\s+(.+)$/m)?.[1].trim() || fallback;

// One document: its Markdown beside its rendering, saved with the button or ⌘S. Jev screens it when typing
// pauses; N check reads the whole document, and a finding's fix or reading replaces its phrase.
export function Editor({ name, initial }: { name: string; initial: string }) {
  const [text, setText] = useState(initial); const [saved, setSaved] = useState(initial);
  const [review, setReview] = useState<Review | null>(null); const [checked, setChecked] = useState(''); const [status, setStatus] = useState('');
  const [busy, setBusy] = useState(false); const area = useRef<HTMLTextAreaElement>(null);
  const [listening, setListening] = useState(false); const recorder = useRef<MediaRecorder | null>(null);
  const title = titleOf(text, name);
  const html = useMemo(() => md.render(text), [text]);
  useEffect(() => { document.title = `${title} · N`; }, [title]);
  const save = async () => { const v = text; const r = await fetch(`/api/doc/${name}`, { method: 'PUT', body: v }); if (r.ok) setSaved(v); else setStatus(await r.text()); };
  useEffect(() => { const key = (e: KeyboardEvent) => { if ((e.metaKey || e.ctrlKey) && e.key === 's') { e.preventDefault(); void save(); } }; window.addEventListener('keydown', key); return () => window.removeEventListener('keydown', key); });
  // Jev's screen once typing pauses: a hint, replaced by N check's findings when those are for this text.
  useEffect(() => {
    if (!text.trim() || checked === text) return;
    const timer = setTimeout(async () => { try { const r = await fetch('/api/screen', { method: 'POST', body: text }); const v = await r.json() as Review; if (r.ok && v.marks) setReview({ ...v, assessor: 'Jev' }); } catch {} }, 1200);
    return () => clearTimeout(timer);
  }, [text, checked]);
  const check = async () => {
    if (!text.trim()) return; setBusy(true); setStatus('N is checking the whole document…');
    try { const v = text; const r = await fetch('/api/check', { method: 'POST', body: v }); const out = await r.json() as Review & { error?: string };
      if (!r.ok) throw Error(out.error || 'N check failed');
      if (text === v) { setReview(out); setChecked(v); } setStatus(`Checked in ${out.seconds.toFixed(1)}s · ${out.marks.length ? `${out.marks.length} to settle` : 'one reading throughout'}`);
    } catch (e) { setStatus((e as Error).message); } finally { setBusy(false); }
  };
  const apply = (m: Mark, choice: string) => { const next = text.slice(0, m.start) + choice + text.slice(m.end); setText(next); setReview(null); setChecked(''); area.current?.focus(); };
  const edit = (v: string) => { setText(v); if (review && review.assessor !== 'Jev') setReview(null); };
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
  const marks = review?.marks || [];
  return <main className="mx-auto flex max-w-7xl flex-col gap-4 p-4 sm:p-7">
    <div className="flex items-center gap-4 text-sm text-stone-500 dark:text-zinc-400">
      <Link href="/" className="hover:text-orange-700">← Documents</Link>
      <span role="status">{text === saved ? 'Saved' : 'Unsaved'}{status ? ` · ${status}` : ''}</span>
    </div>
    <h1 className="text-3xl font-semibold">{title}</h1>
    <div className="flex flex-col gap-5 lg:flex-row">
      <div className="lg:w-1/2">
        <label htmlFor="document" className="sr-only">Document</label>
        <textarea id="document" ref={area} value={text} onChange={e => edit(e.target.value)} spellCheck
          className="h-[70vh] w-full resize-y rounded-lg border border-stone-200 bg-white p-4 font-mono text-[15px] leading-relaxed outline-none focus:border-orange-700 dark:border-zinc-800 dark:bg-zinc-900" />
      </div>
      <article className="preview lg:w-1/2 lg:max-h-[70vh] lg:overflow-y-auto" dangerouslySetInnerHTML={{ __html: html }} />
    </div>
    <div className="flex gap-2">
      <Button onClick={save} className="rounded-md border border-stone-300 px-4 py-2 hover:border-orange-700 dark:border-zinc-700">Save</Button>
      <Button onClick={check} disabled={busy} className="rounded-md bg-stone-900 px-4 py-2 text-white hover:bg-orange-700 dark:bg-zinc-100 dark:text-zinc-900">N check</Button>
      <Button onClick={dictate} aria-pressed={listening} className={`rounded-md border px-4 py-2 ${listening ? 'border-orange-700 bg-orange-700 text-white' : 'border-stone-300 hover:border-orange-700 dark:border-zinc-700'}`}>{listening ? 'Stop' : 'Dictate'}</Button>
      <Button onClick={() => navigator.clipboard.writeText(text)} className="rounded-md border border-stone-300 px-4 py-2 hover:border-orange-700 dark:border-zinc-700">Copy</Button>
    </div>
    {marks.length > 0 && <section aria-live="polite" className="flex flex-col gap-3">
      {review?.assessor === 'Jev' && <p className="text-sm text-stone-500 dark:text-zinc-400">Jev flagged these; N check gives their readings.</p>}
      {marks.map(m => { const choices = [...new Set([...(m.fixable && m.new ? [m.new] : []), ...(m.options || [])])];
        return <div key={`${m.start}-${m.end}`} className="flex flex-col gap-2 rounded-lg border border-stone-200 p-4 dark:border-zinc-800">
          <p className="font-semibold underline decoration-orange-700 decoration-wavy">{text.slice(m.start, m.end)}</p>
          <p>{m.question || m.why}</p>
          {m.question && <p className="text-sm text-stone-500 dark:text-zinc-400">{m.why}</p>}
          <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap">{choices.map(c => <Button key={c} onClick={() => apply(m, c)} className="rounded-md border border-stone-300 px-3 py-2 text-left hover:border-orange-700 dark:border-zinc-700">{c}</Button>)}</div>
        </div>; })}
    </section>}
  </main>;
}
