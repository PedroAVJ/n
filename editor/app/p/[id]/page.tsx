import Link from 'next/link';
import { notFound } from 'next/navigation';
import { idOk, read } from '@/lib/notion';
import { NotionPage } from './notion-page';
export const dynamic = 'force-dynamic';

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!idOk(id)) notFound();
  const { page, raw, text, pending } = await read(id).catch(() => notFound());
  return <main className="mx-auto flex max-w-3xl flex-col gap-4 p-4 sm:p-7">
    <div className="flex items-center gap-4 text-sm text-stone-500 dark:text-zinc-400">
      <Link href="/" className="hover:text-orange-700">← N</Link>
      <a href={page.url} className="hover:text-orange-700">Open in Notion</a>
    </div>
    <h1 className="text-2xl font-semibold">{page.title}</h1>
    {pending
      ? <p className="rounded-lg border border-orange-700 p-4">This page has suggested edits waiting in Notion. Accept or reject them there, then come back to edit it here: until then, saving could write them in.</p>
      : <NotionPage id={page.id} title={page.title} raw={raw} initial={text} />}
  </main>;
}
