'use client';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { Spinner, TrashIcon } from '@/components/icons';
import { Button } from '@/components/ui/button';
import { href, parentOf, segments } from '@/lib/pages';

// Deleting the page: the bin asks first, saying how many pages under it go with it; then the page above it
// (or the list of pages) shows.
export function DeletePage({ id, title, under }: { id: string; title: string; under: number }) {
  const router = useRouter();
  const [asking, setAsking] = useState(false); const [busy, setBusy] = useState(false); const [problem, setProblem] = useState('');
  const box = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!asking) return;
    const away = (e: PointerEvent) => { if (!box.current?.contains(e.target as Node)) setAsking(false); };
    const escape = (e: KeyboardEvent) => { if (e.key === 'Escape') setAsking(false); };
    document.addEventListener('pointerdown', away); document.addEventListener('keydown', escape);
    return () => { document.removeEventListener('pointerdown', away); document.removeEventListener('keydown', escape); };
  }, [asking]);
  // A draft still on its way to the Mac mini lands first, so it goes with the page.
  const remove = async () => {
    setBusy(true); setProblem('');
    await new Promise(r => setTimeout(r, 500));
    const r = await fetch(`/api/doc/${segments(id)}`, { method: 'DELETE' });
    if (!r.ok) { setProblem(await r.text()); setBusy(false); return; }
    router.replace(parentOf(id) ? href(parentOf(id)) : '/');
  };
  return <div ref={box} className="relative shrink-0">
    <button onClick={() => { setAsking(a => !a); setProblem(''); }} aria-label="Delete this page" aria-expanded={asking}
      className="grid size-9 place-items-center rounded-full text-faint hover:bg-hover hover:text-error"><TrashIcon className="size-[18px]" /></button>
    {asking && <div role="dialog" aria-label="Delete this page" className="absolute right-0 top-11 z-30 flex w-72 flex-col gap-3 rounded-2xl border border-line bg-surface p-4 shadow-lg">
      <p className="text-[15px] leading-snug">Delete <span className="font-medium">{title}</span>{under ? ` and the ${under} page${under === 1 ? '' : 's'} under it` : ''}?</p>
      {problem && <p role="alert" className="text-sm text-error">{problem}</p>}
      <div className="flex justify-end gap-2">
        <Button variant="quiet" size="small" onClick={() => setAsking(false)} disabled={busy}>Cancel</Button>
        <Button variant="danger" size="small" onClick={remove} disabled={busy}>{busy ? <Spinner className="size-3.5" /> : null}Delete</Button>
      </div>
    </div>}
  </div>;
}
