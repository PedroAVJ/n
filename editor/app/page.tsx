import Link from 'next/link';
import { list } from '@/lib/documents';
import { NewDocument } from './new-document';
export const dynamic = 'force-dynamic';

export default async function Documents() {
  const docs = await list();
  return <main className="mx-auto flex max-w-2xl flex-col gap-4 p-6 sm:p-8">
    <h1 className="text-3xl font-semibold">N</h1>
    <p className="text-sm text-stone-500 dark:text-zinc-400">Documents that say exactly one thing. Each is a .n file.</p>
    <NewDocument />
    <div className="flex flex-col gap-2">
      {docs.map(d => <Link key={d.name} href={`/d/${d.name}`} className="flex flex-col gap-1 rounded-lg border border-stone-200 p-3 hover:border-orange-700 dark:border-zinc-800 dark:hover:border-orange-500">
        <span className="text-lg font-semibold">{d.title}</span><span className="text-sm text-stone-500 dark:text-zinc-400">{d.name}.n</span>
      </Link>)}
    </div>
  </main>;
}
