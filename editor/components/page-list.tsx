import Link from 'next/link';
import { href } from '@/lib/pages';
import { PageIcon } from './icons';

type Row = { id: string; name: string; title: string };
type Node = Row & { pages: Node[] };

// Pages as rows, the way a notebook lists them: an icon, the title, and the pages under each, indented.
export function PageTree({ pages, depth = 0 }: { pages: Node[]; depth?: number }) {
  if (!pages.length) return null;
  return <ul className={depth ? 'ml-4 border-l border-line pl-2' : ''}>
    {pages.map(p => <li key={p.id}>
      <PageRow page={p} />
      <PageTree pages={p.pages} depth={depth + 1} />
    </li>)}
  </ul>;
}

export function PageRows({ pages }: { pages: Row[] }) {
  if (!pages.length) return null;
  return <ul>{pages.map(p => <li key={p.id}><PageRow page={p} /></li>)}</ul>;
}

function PageRow({ page }: { page: Row }) {
  return <Link href={href(page.id)} className="group flex items-center gap-2.5 rounded-lg px-2 py-1.5 text-[15px] text-ink hover:bg-hover">
    <PageIcon className="size-[18px] shrink-0 text-faint group-hover:text-muted" />
    <span className="truncate">{page.title}</span>
  </Link>;
}
