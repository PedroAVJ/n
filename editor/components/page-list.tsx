import Link from 'next/link';
import { href } from '@/lib/pages';

// Pages as links: each one's title, name, and how many pages are under it.
export function PageList({ pages }: { pages: Array<{ id: string; name: string; title: string; pages: number }> }) {
  if (!pages.length) return null;
  return <div className="flex flex-col gap-2">
    {pages.map(p => <Link key={p.id} href={href(p.id)} className="flex items-baseline justify-between gap-3 rounded-lg border border-stone-200 p-3 hover:border-orange-700 dark:border-zinc-800 dark:hover:border-orange-500">
      <span className="flex flex-col gap-0.5"><span className="font-semibold">{p.title}</span><span className="text-sm text-stone-500 dark:text-zinc-400">{p.name}.n</span></span>
      {p.pages > 0 && <span className="text-sm text-stone-500 dark:text-zinc-400">{p.pages} page{p.pages === 1 ? '' : 's'}</span>}
    </Link>)}
  </div>;
}
