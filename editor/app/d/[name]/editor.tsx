'use client';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Writer } from '@/components/writer';

const titleOf = (text: string, fallback: string) => text.match(/^#\s+(.+)$/m)?.[1].trim() || fallback;

// One .n document, written and checked by N (see Writer); saved with the button or ⌘S, and renamed here.
export function Editor({ name, initial }: { name: string; initial: string }) {
  const router = useRouter();
  const [text, setText] = useState(initial);
  const [renaming, setRenaming] = useState(false); const [to, setTo] = useState(name); const [problem, setProblem] = useState('');
  const title = titleOf(text, name);
  useEffect(() => { document.title = `${title} · N`; }, [title]);
  const commit = useCallback(async (v: string) => { const r = await fetch(`/api/doc/${encodeURIComponent(name)}`, { method: 'PUT', body: v }); if (!r.ok) throw Error(await r.text()); }, [name]);
  // The draft being typed reaches the Mac mini before the file moves, so it moves with it.
  const rename = async () => {
    if (to.trim() === name) { setRenaming(false); return; }
    await new Promise(r => setTimeout(r, 500));
    const r = await fetch('/api/rename', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ from: name, to: to.trim() }) });
    if (!r.ok) { setProblem(await r.text()); return; }
    router.replace((await r.json() as { path: string }).path);
  };
  return <main className="mx-auto flex max-w-3xl flex-col gap-4 p-4 sm:p-7">
    <Link href="/" className="text-sm text-stone-500 hover:text-orange-700 dark:text-zinc-400">← N</Link>
    <div className="flex flex-col gap-1">
      <h1 className="text-3xl font-semibold">{title}</h1>
      {renaming ? <div className="flex flex-wrap items-center gap-2">
        <label htmlFor="rename" className="sr-only">Name</label>
        <input id="rename" autoFocus value={to} onChange={e => { setTo(e.target.value); setProblem(''); }} onKeyDown={e => { if (e.key === 'Enter') void rename(); if (e.key === 'Escape') setRenaming(false); }}
          className="rounded-md border border-stone-300 bg-transparent px-3 py-1.5 outline-none focus:border-orange-700 dark:border-zinc-700" />
        <span className="text-sm text-stone-500 dark:text-zinc-400">.n</span>
        <Button onClick={rename} className="rounded-md bg-stone-900 px-3 py-1.5 text-sm text-white hover:bg-orange-700 dark:bg-zinc-100 dark:text-zinc-900">Rename</Button>
        <Button onClick={() => { setRenaming(false); setTo(name); setProblem(''); }} className="rounded-md border border-stone-300 px-3 py-1.5 text-sm dark:border-zinc-700">Cancel</Button>
        {problem && <p role="alert" className="w-full text-sm text-red-700 dark:text-red-400">{problem}</p>}
      </div> : <button onClick={() => setRenaming(true)} className="self-start text-sm text-stone-500 hover:text-orange-700 dark:text-zinc-400">{name}.n · Rename</button>}
    </div>
    <Writer name={name} initial={initial} commit={commit} onText={setText} />
  </main>;
}
