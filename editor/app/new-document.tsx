'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';

export function NewDocument() {
  const router = useRouter(); const [name, setName] = useState(''); const [status, setStatus] = useState('');
  const create = async () => { const r = await fetch('/api/new', { method: 'POST', body: name.trim() }); if (!r.ok) { setStatus(await r.text()); return; } router.push((await r.json()).path); };
  return <div className="flex flex-col gap-2">
    <div className="flex gap-2">
      <label htmlFor="name" className="sr-only">New document's name</label>
      <input id="name" value={name} onChange={e => setName(e.target.value)} onKeyDown={e => { if (e.key === 'Enter') create(); }} placeholder="Name (letters, digits, spaces, &, - and _)"
        className="flex-1 rounded-md border border-stone-300 bg-white px-3 py-2 text-[15px] outline-none focus:border-orange-700 dark:border-zinc-700 dark:bg-zinc-900" />
      <Button onClick={create} className="rounded-md bg-stone-900 px-4 py-2 text-white hover:bg-orange-700 dark:bg-zinc-100 dark:text-zinc-900">New</Button>
    </div>
    {status && <p role="status" className="text-sm text-stone-500">{status}</p>}
  </div>;
}
