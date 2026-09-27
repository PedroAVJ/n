'use client';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import { ChevronIcon } from '@/components/icons';
import { Pages } from '@/components/page-list';
import { Writer } from '@/components/writer';
import { ancestors, href, nameOf, segments } from '@/lib/pages';
import { NewDocument } from '../../new-document';

const titleOf = (text: string, fallback: string) => text.match(/^#\s+(.+)$/m)?.[1].trim() || fallback;
type Sub = { id: string; name: string; title: string; pages: number };

// One page: the pages above it, its title and name (renamed here), its text, written and checked by N (see
// Writer), and after it the pages under it, in the author's order, and a new one.
export function Editor({ id, initial, pages }: { id: string; initial: string; pages: Sub[] }) {
  const router = useRouter(); const name = nameOf(id);
  const [text, setText] = useState(initial);
  const [renaming, setRenaming] = useState(false); const [to, setTo] = useState(name); const [problem, setProblem] = useState('');
  const title = titleOf(text, name);
  useEffect(() => { document.title = `${title} · N`; }, [title]);
  const commit = useCallback(async (v: string) => { const r = await fetch(`/api/doc/${segments(id)}`, { method: 'PUT', body: v }); if (!r.ok) throw Error(await r.text()); }, [id]);
  // The draft being typed reaches the Mac mini before the page moves, so it moves with it.
  const rename = async () => {
    if (!to.trim() || to.trim() === name) { setRenaming(false); setTo(name); return; }
    await new Promise(r => setTimeout(r, 500));
    const r = await fetch('/api/rename', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ from: id, to: to.trim() }) });
    if (!r.ok) { setProblem(await r.text()); return; }
    router.replace((await r.json() as { path: string }).path);
  };
  return <main className="mx-auto flex max-w-[680px] flex-col px-4 pb-44 pt-[max(1rem,env(safe-area-inset-top))] sm:px-6">
    <nav aria-label="Pages above" className="flex h-10 items-center gap-0.5 overflow-x-auto text-sm text-muted">
      <Link href="/" className="shrink-0 rounded-md px-1.5 py-1 font-serif font-semibold text-ink hover:bg-hover">N</Link>
      {ancestors(id).map(([aid, aname]) => <span key={aid} className="flex shrink-0 items-center gap-0.5"><ChevronIcon className="size-3.5 text-faint" /><Link href={href(aid)} className="rounded-md px-1.5 py-1 hover:bg-hover hover:text-ink">{aname}</Link></span>)}
    </nav>
    <header className="mt-8 flex flex-col gap-1.5">
      <h1 className="font-serif text-[34px] font-semibold leading-[1.15] tracking-[-0.01em] sm:text-[40px]">{title}</h1>
      {renaming ? <div className="flex flex-wrap items-center gap-2">
        <label htmlFor="rename" className="sr-only">Name</label>
        <input id="rename" autoFocus value={to} onChange={e => { setTo(e.target.value); setProblem(''); }} onBlur={() => void rename()} onKeyDown={e => { if (e.key === 'Enter') void rename(); if (e.key === 'Escape') { setRenaming(false); setTo(name); } }}
          className="min-w-0 rounded-md border border-line bg-surface px-2 py-1 text-sm outline-none focus:border-accent" />
        <span className="text-sm text-faint">.n · Enter to rename</span>
        {problem && <p role="alert" className="w-full text-sm text-error">{problem}</p>}
      </div> : <button onClick={() => setRenaming(true)} className="self-start rounded-md text-sm text-faint hover:text-muted">{name}.n</button>}
    </header>
    <div className="mt-8"><Writer id={id} initial={initial} commit={commit} onText={setText} /></div>
    <section aria-label="Pages under this one" className="mt-10 flex flex-col border-t border-line pt-4">
      <Pages parent={id} pages={pages.map(({ id, name, title }) => ({ id, name, title }))} footer={<NewDocument parent={id} />} />
    </section>
  </main>;
}
