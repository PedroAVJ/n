'use client';
import Link from 'next/link';
import { useCallback, useEffect, useState } from 'react';
import { Writer } from '@/components/writer';

const titleOf = (text: string, fallback: string) => text.match(/^#\s+(.+)$/m)?.[1].trim() || fallback;

// One .n document, written and checked by N (see Writer); saved with the button or ⌘S.
export function Editor({ name, initial }: { name: string; initial: string }) {
  const [text, setText] = useState(initial);
  const title = titleOf(text, name);
  useEffect(() => { document.title = `${title} · N`; }, [title]);
  const commit = useCallback(async (v: string) => { const r = await fetch(`/api/doc/${name}`, { method: 'PUT', body: v }); if (!r.ok) throw Error(await r.text()); }, [name]);
  return <main className="mx-auto flex max-w-3xl flex-col gap-4 p-4 sm:p-7">
    <Link href="/" className="text-sm text-stone-500 hover:text-orange-700 dark:text-zinc-400">← N</Link>
    <h1 className="text-3xl font-semibold">{title}</h1>
    <Writer name={name} initial={initial} commit={commit} onText={setText} />
  </main>;
}
