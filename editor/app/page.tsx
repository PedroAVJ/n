import { list } from '@/lib/documents';
import { PageList } from '@/components/page-list';
import { NewDocument } from './new-document';
export const dynamic = 'force-dynamic';

// The top pages. Each is a .n file; pages can hold pages.
export default async function Documents() {
  const pages = await list();
  return <main className="mx-auto flex max-w-2xl flex-col gap-4 p-6 sm:p-8">
    <h1 className="text-3xl font-semibold">N</h1>
    <p className="text-sm text-stone-500 dark:text-zinc-400">Pages that say exactly one thing. Each is a .n file; pages can hold pages.</p>
    <NewDocument />
    <PageList pages={pages} />
  </main>;
}
