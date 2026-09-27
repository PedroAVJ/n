'use client';
import Link from 'next/link';
import MarkdownIt from 'markdown-it';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Writer } from '@/components/writer';

const md = new MarkdownIt({ html: false, linkify: true });
const titleOf = (text: string, fallback: string) => text.match(/^#\s+(.+)$/m)?.[1].trim() || fallback;

// One .n document beside its rendering, written and checked by N (see Writer); saved with the button or ⌘S.
export function Editor({ name, initial }: { name: string; initial: string }) {
  const [text, setText] = useState(initial);
  const title = titleOf(text, name);
  const html = useMemo(() => md.render(text), [text]);
  useEffect(() => { document.title = `${title} · N`; }, [title]);
  const commit = useCallback(async (v: string) => { const r = await fetch(`/api/doc/${name}`, { method: 'PUT', body: v }); if (!r.ok) throw Error(await r.text()); }, [name]);
  return <main className="mx-auto flex max-w-7xl flex-col gap-4 p-4 sm:p-7">
    <Link href="/" className="text-sm text-stone-500 hover:text-orange-700 dark:text-zinc-400">← N</Link>
    <h1 className="text-3xl font-semibold">{title}</h1>
    <div className="flex flex-col gap-5 lg:flex-row">
      <div className="lg:w-1/2"><Writer name={name} initial={initial} commit={commit} onText={setText} /></div>
      <article className="preview lg:w-1/2 lg:max-h-[70vh] lg:overflow-y-auto" dangerouslySetInnerHTML={{ __html: html }} />
    </div>
  </main>;
}
