'use client';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Writer } from '@/components/writer';
import type { Message } from '@/lib/whatsapp';

const day = (at: string) => new Date(at).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' });
const time = (at: string) => new Date(at).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });

// A WhatsApp chat: its newest messages, and a reply checked as it is written; sent with the button or ⌘↩.
export function Conversation({ jid, name, group, initial }: { jid: string; name: string; group: boolean; initial: Message[] }) {
  const [ms, setMs] = useState(initial); const end = useRef<HTMLDivElement>(null);
  useEffect(() => { end.current?.scrollIntoView({ block: 'end' }); }, [ms.length]);
  useEffect(() => { document.title = `${name} · N`; }, [name]);
  const commit = useCallback(async (text: string) => {
    const r = await fetch('/api/whatsapp/send', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ jid, text }) });
    if (!r.ok) throw Error(await r.text());
    setMs(m => [...m, { id: `sent-${Date.now()}`, mine: true, text, media: '', at: new Date().toISOString() }]);
  }, [jid]);
  let last = '';
  return <div className="flex flex-col gap-4">
    <div className="flex max-h-[50vh] flex-col gap-1.5 overflow-y-auto rounded-lg border border-stone-200 p-3 dark:border-zinc-800">
      {ms.map(m => { const d = day(m.at), heading = d !== last ? d : ''; last = d;
        return <div key={m.id} className="flex flex-col">
          {heading && <p className="my-2 text-center text-xs text-stone-500 dark:text-zinc-400">{heading}</p>}
          <div className={`max-w-[85%] rounded-lg px-3 py-1.5 ${m.mine ? 'self-end bg-orange-100 dark:bg-orange-950' : 'self-start bg-stone-100 dark:bg-zinc-900'}`}>
            {group && !m.mine && <span className="sr-only">Them: </span>}
            <p className="whitespace-pre-wrap break-words">{m.text || (m.media ? `(${m.media})` : '')}</p>
            <p className="text-right text-[11px] text-stone-500 dark:text-zinc-400">{time(m.at)}</p>
          </div>
        </div>; })}
      <div ref={end} />
    </div>
    <Writer draft={`whatsapp:${jid}`} initial="" commit={commit} label="Send" clears rows="h-36" placeholder={`Message ${name}`} />
  </div>;
}
