import Link from 'next/link';
import { list } from '@/lib/documents';
import { recent } from '@/lib/notion';
import { chats } from '@/lib/whatsapp';
import { NewDocument } from './new-document';
export const dynamic = 'force-dynamic';

const when = (at: string) => { const d = new Date(at); return isNaN(+d) ? '' : d.toDateString() === new Date().toDateString() ? d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' }) : d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }); };
const row = 'flex flex-col gap-0.5 rounded-lg border border-stone-200 p-3 hover:border-orange-700 dark:border-zinc-800 dark:hover:border-orange-500';
const quiet = 'text-sm text-stone-500 dark:text-zinc-400';

function Failed({ what, error }: { what: string; error: unknown }) {
  return <p className={quiet}>{what} is unreachable: {(error as Error).message}</p>;
}

// Everything N writes: WhatsApp replies, Notion pages and .n documents, each checked as it is written.
export default async function Home() {
  const [docs, ws, ps] = await Promise.allSettled([list(), chats(20), recent(20)]);
  return <main className="mx-auto flex max-w-2xl flex-col gap-8 p-5 sm:p-8">
    <header className="flex flex-col gap-1">
      <h1 className="text-3xl font-semibold">N</h1>
      <p className={quiet}>Write it so it says exactly one thing.</p>
    </header>
    <section className="flex flex-col gap-2">
      <h2 className="text-lg font-semibold">WhatsApp</h2>
      {ws.status === 'rejected' ? <Failed what="WhatsApp" error={ws.reason} /> : ws.value.map(c =>
        <Link key={c.jid} href={`/w/${encodeURIComponent(c.jid)}`} className={row}>
          <span className="flex justify-between gap-3"><span className="font-semibold">{c.name}</span><span className={quiet}>{when(c.at)}</span></span>
          <span className={`${quiet} truncate`}>{c.last}</span>
        </Link>)}
    </section>
    <section className="flex flex-col gap-2">
      <h2 className="text-lg font-semibold">Notion</h2>
      {ps.status === 'rejected' ? <Failed what="Notion" error={ps.reason} /> : ps.value.map(p =>
        <Link key={p.id} href={`/p/${p.id}`} className={row}>
          <span className="flex justify-between gap-3"><span className="font-semibold">{p.title}</span><span className={quiet}>{when(p.edited)}</span></span>
        </Link>)}
    </section>
    <section className="flex flex-col gap-2">
      <h2 className="text-lg font-semibold">Documents</h2>
      <NewDocument />
      {docs.status === 'rejected' ? <Failed what="Documents" error={docs.reason} /> : docs.value.map(d =>
        <Link key={d.name} href={`/d/${d.name}`} className={row}>
          <span className="font-semibold">{d.title}</span><span className={quiet}>{d.name}.n</span>
        </Link>)}
    </section>
  </main>;
}
