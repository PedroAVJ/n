'use client';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Findings, PhaseBadge } from '@/components/findings';
import { useN, type Found } from '@/components/use-n';
import { fixable } from '@/components/fixes';
import { inlineMd, pageHtml, pageMd, parse, rangeAt, textOf, type Block } from '@/lib/notion-md';

// A Notion page as Notion shows it, written in place: headings, lists, to-dos, bold, italics, links and
// commented phrases as they are, child pages and anything else shown and kept as they are. Check has N read
// it. Saving sends Notion only what changed.
export function NotionPage({ id, title, raw }: { id: string; title: string; raw: string }) {
  const root = useRef<HTMLDivElement>(null);
  const base = useRef(raw); // the page as Notion last gave it
  const shape = useRef<{ blocks: Block[]; canon: string[] }>({ blocks: [], canon: [] });
  const [text, setText] = useState(''); const [md, setMd] = useState(raw);
  const [status, setStatus] = useState(''); const [busy, setBusy] = useState(false);
  const loaded = useRef(false);
  const store = `/api/draft/${encodeURIComponent(`notion:${id}`)}`;
  const { shown, phase, forget, check, busy: checking } = useN(text);
  useEffect(() => { document.title = `${title} · N`; }, [title]);

  const render = useCallback((markdown: string) => {
    const el = root.current; if (!el) return;
    const blocks = parse(markdown);
    el.innerHTML = pageHtml(blocks);
    const canon = Array.from(el.children).map(c => inlineMd(c));
    shape.current = { blocks, canon };
  }, []);
  const sync = useCallback(() => {
    const el = root.current; if (!el) return;
    // A numbered list counts its items in a row.
    let n = 0; for (const c of Array.from(el.children)) { if (c.getAttribute('data-kind') === 'ol') c.setAttribute('data-n', String(++n)); else n = 0; }
    setText(textOf(el).text); setMd(pageMd(el, shape.current.blocks, shape.current.canon));
  }, []);

  // The page, or its unsaved draft, which is kept on the Mac mini until it is saved.
  useEffect(() => {
    (async () => {
      let kept: string | null = null;
      try { const r = await fetch(store, { cache: 'no-store' }); if (r.ok) kept = (await r.json() as { text: string | null }).text; } catch {}
      render(kept ?? raw); sync(); loaded.current = true;
    })();
  }, [raw, store, render, sync]);
  const idle = md === base.current;
  useEffect(() => {
    if (!loaded.current) return;
    const timer = setTimeout(() => { void fetch(store, idle ? { method: 'DELETE' } : { method: 'PUT', body: md }).catch(() => {}); }, 400);
    return () => clearTimeout(timer);
  }, [md, idle, store]);
  useEffect(() => {
    const leave = () => { if (loaded.current && !idle) navigator.sendBeacon(store, md); };
    window.addEventListener('pagehide', leave);
    return () => window.removeEventListener('pagehide', leave);
  }, [md, idle, store]);

  const select = (f: Found) => { const el = root.current; if (!el) return null; return rangeAt(textOf(el).nodes, f.start, f.end); };
  const pick = (f: Found) => { const r = select(f); if (!r) return; root.current?.focus(); const s = getSelection(); s?.removeAllRanges(); s?.addRange(r); };
  // A fix replaces only the characters that differ, so the formatting around and inside the phrase stays.
  const apply = (f: Found, choice: string) => {
    let p = 0, e = 0; const q = f.quote;
    while (p < q.length && p < choice.length && q[p] === choice[p]) p++;
    while (e < q.length - p && e < choice.length - p && q[q.length - 1 - e] === choice[choice.length - 1 - e]) e++;
    const el = root.current; const r = el && rangeAt(textOf(el).nodes, f.start + p, f.end - e); if (!r) return;
    const put = choice.slice(p, choice.length - e);
    el.focus(); const s = getSelection(); s?.removeAllRanges(); s?.addRange(r);
    if (!document.execCommand(put ? 'insertText' : 'delete', false, put)) { r.deleteContents(); if (put) r.insertNode(document.createTextNode(put)); }
    forget(f); sync();
  };

  // Check: N reads the page now; every fix it is sure of is made, from the end back so each phrase is still
  // where N found it, and what it cannot fix is left to choose.
  const autofix = async () => {
    const el = root.current; if (!el) return;
    const v = textOf(el).text; const fs = fixable(await check(v));
    if (textOf(el).text !== v) { setStatus('The page changed while N read it: check again'); return; }
    for (const f of fs) apply(f, f.new);
    setStatus(fs.length ? `Fixed ${fs.length}` : '');
  };

  const save = async () => {
    const after = md; if (busy || after === base.current) return;
    setBusy(true); setStatus('Saving…');
    try {
      const r = await fetch(`/api/notion/${id}`, { method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ before: base.current, after }) });
      if (!r.ok) throw Error(await r.text());
      base.current = (await r.json() as { raw: string }).raw;
      render(base.current); sync(); setStatus('Saved');
    } catch (e) { setStatus((e as Error).message); } finally { setBusy(false); }
  };
  useEffect(() => { const key = (e: KeyboardEvent) => { if ((e.metaKey || e.ctrlKey) && e.key === 's') { e.preventDefault(); void save(); } }; window.addEventListener('keydown', key); return () => window.removeEventListener('keydown', key); });

  // Dictation: record until pressed again, then ElevenLabs Scribe's text goes in where the cursor was.
  const [listening, setListening] = useState(false); const recorder = useRef<MediaRecorder | null>(null);
  const dictate = async () => {
    if (recorder.current) { recorder.current.stop(); return; }
    const sel = getSelection(); const at = sel && sel.rangeCount && root.current?.contains(sel.anchorNode) ? sel.getRangeAt(0).cloneRange() : null;
    let stream: MediaStream;
    try { stream = await navigator.mediaDevices.getUserMedia({ audio: true }); } catch { setStatus('No microphone access'); return; }
    const chunks: Blob[] = []; const rec = new MediaRecorder(stream); recorder.current = rec;
    rec.ondataavailable = e => { if (e.data.size) chunks.push(e.data); };
    rec.onstop = async () => {
      stream.getTracks().forEach(t => t.stop()); recorder.current = null; setListening(false); setStatus('Transcribing…');
      try {
        const blob = new Blob(chunks, { type: rec.mimeType || 'audio/webm' });
        const r = await fetch('/api/dictate', { method: 'POST', headers: { 'content-type': blob.type }, body: blob });
        const out = await r.json() as { text?: string; error?: string };
        if (!r.ok || out.text === undefined) throw Error(out.error || 'Dictation failed');
        root.current?.focus(); const s = getSelection();
        if (at) { s?.removeAllRanges(); s?.addRange(at); }
        document.execCommand('insertText', false, out.text); sync(); setStatus('Dictated');
      } catch (e) { setStatus((e as Error).message); }
    };
    rec.start(); setListening(true); setStatus('Listening… press Dictate again to stop');
  };

  // A to-do's box ticks when tapped.
  const tick = (e: React.MouseEvent) => {
    const t = e.target as HTMLElement; const kind = t.getAttribute?.('data-kind');
    if ((kind === 'todo' || kind === 'done') && e.nativeEvent.offsetX < 0) { t.setAttribute('data-kind', kind === 'todo' ? 'done' : 'todo'); sync(); }
  };

  return <div className="flex flex-col gap-3">
    <div ref={root} contentEditable suppressContentEditableWarning spellCheck role="textbox" aria-multiline aria-label="Page"
      onInput={sync} onClick={tick}
      className="notion min-h-[50vh] rounded-lg border border-stone-200 p-4 text-[16px] leading-relaxed outline-none focus:border-orange-700 dark:border-zinc-800" />
    <div className="flex flex-wrap items-center gap-2">
      <Button onClick={save} disabled={busy} className="rounded-md bg-stone-900 px-4 py-2 text-white hover:bg-orange-700 dark:bg-zinc-100 dark:text-zinc-900">Save</Button>
      <Button onClick={autofix} disabled={checking || !text.trim()} className="rounded-md border border-orange-700 px-4 py-2 text-orange-800 hover:bg-orange-700 hover:text-white dark:text-orange-300">Check</Button>
      <Button onClick={dictate} aria-pressed={listening} className={`rounded-md border px-4 py-2 ${listening ? 'border-orange-700 bg-orange-700 text-white' : 'border-stone-300 hover:border-orange-700 dark:border-zinc-700'}`}>{listening ? 'Stop' : 'Dictate'}</Button>
      <Button onClick={() => navigator.clipboard.writeText(text)} className="rounded-md border border-stone-300 px-4 py-2 hover:border-orange-700 dark:border-zinc-700">Copy</Button>
      <PhaseBadge phase={phase} />
      <span className="text-sm text-stone-500 dark:text-zinc-400">{[md !== base.current ? 'Unsaved' : '', status].filter(Boolean).join(' · ')}</span>
    </div>
    <Findings shown={shown} pick={pick} apply={apply} />
  </div>;
}
