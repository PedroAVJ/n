import Link from 'next/link';
import { notFound } from 'next/navigation';
import { chat, messages } from '@/lib/whatsapp';
import { Conversation } from './conversation';
export const dynamic = 'force-dynamic';

export default async function Chat({ params }: { params: Promise<{ jid: string }> }) {
  const jid = decodeURIComponent((await params).jid);
  if (!/^[\w.-]+@[\w.]+$/.test(jid)) notFound();
  const [c, ms] = await Promise.all([chat(jid), messages(jid)]);
  if (!c) notFound();
  return <main className="mx-auto flex max-w-3xl flex-col gap-4 p-4 sm:p-7">
    <Link href="/" className="text-sm text-stone-500 hover:text-orange-700 dark:text-zinc-400">← N</Link>
    <h1 className="text-2xl font-semibold">{c.name}</h1>
    <Conversation jid={jid} name={c.name} group={c.group} initial={ms} />
  </main>;
}
