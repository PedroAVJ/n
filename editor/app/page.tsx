import { tree } from '@/lib/documents';
import { PageTree } from '@/components/page-list';
import { NewDocument } from './new-document';
export const dynamic = 'force-dynamic';

// Every page, as a tree. Each is a .n file; pages hold pages.
export default async function Documents() {
  const pages = await tree();
  return <main className="mx-auto flex max-w-[680px] flex-col gap-8 px-4 pb-24 pt-[max(3rem,env(safe-area-inset-top))] sm:px-6">
    <header className="flex items-center gap-3">
      <span className="grid size-10 place-items-center rounded-xl bg-ink font-serif text-2xl font-semibold text-paper">N</span>
      <div>
        <h1 className="font-serif text-2xl font-semibold leading-tight">N</h1>
        <p className="text-sm text-muted">Write it so it says exactly one thing.</p>
      </div>
    </header>
    <nav aria-label="Pages" className="flex flex-col">
      <PageTree pages={pages} />
      <NewDocument />
    </nav>
  </main>;
}
