'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { PlusIcon } from '@/components/icons';

// A new page: at the top, or under the page whose id is parent. A row that becomes a name field.
export function NewDocument({ parent = '' }: { parent?: string }) {
  const router = useRouter(); const [open, setOpen] = useState(false); const [name, setName] = useState(''); const [status, setStatus] = useState('');
  const create = async () => {
    if (!name.trim()) { setOpen(false); return; }
    const r = await fetch('/api/new', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ parent, name: name.trim() }) });
    if (!r.ok) { setStatus(await r.text()); return; }
    router.push((await r.json()).path);
  };
  if (!open) return <button onClick={() => setOpen(true)} className="flex w-full items-center gap-2.5 rounded-lg px-2 py-1.5 text-[15px] text-muted hover:bg-hover hover:text-ink">
    <PlusIcon className="size-[18px]" />{parent ? 'Add a page' : 'New page'}
  </button>;
  return <div className="flex flex-col gap-1 px-2 py-1">
    <div className="flex items-center gap-2.5">
      <PlusIcon className="size-[18px] shrink-0 text-faint" />
      <label htmlFor={`name-${parent}`} className="sr-only">Name of the new page</label>
      <input id={`name-${parent}`} autoFocus value={name} onChange={e => { setName(e.target.value); setStatus(''); }} onBlur={() => { if (!name.trim()) setOpen(false); }}
        onKeyDown={e => { if (e.key === 'Enter') void create(); if (e.key === 'Escape') setOpen(false); }} placeholder="Name, then Enter"
        className="min-w-0 flex-1 bg-transparent py-0.5 text-[15px] outline-none placeholder:text-faint" />
    </div>
    {status && <p role="status" className="pl-7 text-sm text-error">{status}</p>}
  </div>;
}
