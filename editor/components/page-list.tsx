'use client';
import Link from 'next/link';
import { useState } from 'react';
import { href } from '@/lib/pages';
import { DownIcon, PageIcon, UpIcon } from './icons';

type Row = { id: string; name: string; title: string };
type Node = Row & { pages?: Node[] };

// Pages as rows, the way a notebook lists them: an icon, the title, and (in a tree) the pages under each,
// indented.
export function PageTree({ pages, depth = 0 }: { pages: Node[]; depth?: number }) {
  if (!pages.length) return null;
  return <ul className={depth ? 'ml-4 border-l border-line pl-2' : ''}>
    {pages.map(p => <li key={p.id}><PageRow page={p} /><PageTree pages={p.pages ?? []} depth={depth + 1} /></li>)}
  </ul>;
}

function PageRow({ page }: { page: Row }) {
  return <Link href={href(page.id)} className="group flex min-w-0 flex-1 items-center gap-2.5 rounded-lg px-2 py-1.5 text-[15px] text-ink hover:bg-hover">
    <PageIcon className="size-[18px] shrink-0 text-faint group-hover:text-muted" />
    <span className="truncate">{page.title}</span>
  </Link>;
}

// The pages under one page (or the top pages), in the author's order: Reorder shows each row's up and down
// arrows, and every move is saved. The pages under each, if given, show beneath it.
export function Pages({ parent, pages, footer }: { parent: string; pages: Node[]; footer?: React.ReactNode }) {
  const [rows, setRows] = useState(pages); const [ordering, setOrdering] = useState(false); const [problem, setProblem] = useState('');
  const move = async (i: number, by: number) => {
    const j = i + by; if (j < 0 || j >= rows.length) return;
    const next = [...rows]; [next[i], next[j]] = [next[j], next[i]]; setRows(next);
    const r = await fetch('/api/order', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ parent, names: next.map(p => p.name) }) });
    setProblem(r.ok ? '' : await r.text());
  };
  return <div className="flex flex-col">
    <ul>
      {rows.map((p, i) => <li key={p.id}>
        <div className="flex items-center gap-1">
          <PageRow page={p} />
          {ordering && <span className="flex shrink-0 gap-0.5">
            <button onClick={() => move(i, -1)} disabled={i === 0} aria-label={`Move ${p.title} up`} className="grid size-8 place-items-center rounded-full text-muted hover:bg-hover disabled:opacity-30"><UpIcon className="size-4" /></button>
            <button onClick={() => move(i, 1)} disabled={i === rows.length - 1} aria-label={`Move ${p.title} down`} className="grid size-8 place-items-center rounded-full text-muted hover:bg-hover disabled:opacity-30"><DownIcon className="size-4" /></button>
          </span>}
        </div>
        {!ordering && <PageTree pages={p.pages ?? []} depth={1} />}
      </li>)}
    </ul>
    <div className="flex items-center gap-1">
      <div className="min-w-0 flex-1">{footer}</div>
      {rows.length > 1 && <button onClick={() => setOrdering(o => !o)} className="shrink-0 rounded-lg px-2 py-1.5 text-sm text-muted hover:bg-hover hover:text-ink">{ordering ? 'Done' : 'Reorder'}</button>}
    </div>
    {problem && <p role="alert" className="px-2 text-sm text-error">{problem}</p>}
  </div>;
}
