'use client';
import { useCallback, useEffect, useRef } from 'react';
import { Writer } from '@/components/writer';

// A Notion page's content as Markdown, checked as it is written; saving sends Notion only what changed.
export function NotionPage({ id, title, raw, initial }: { id: string; title: string; raw: string; initial: string }) {
  const base = useRef(raw);
  useEffect(() => { document.title = `${title} · N`; }, [title]);
  const commit = useCallback(async (text: string) => {
    const r = await fetch(`/api/notion/${id}`, { method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ before: base.current, text }) });
    if (!r.ok) throw Error(await r.text());
    const out = await r.json() as { raw: string; text: string };
    base.current = out.raw; return out.text;
  }, [id]);
  return <Writer draft={`notion:${id}`} initial={initial} commit={commit} label="Save" rows="h-[65vh]" />;
}
