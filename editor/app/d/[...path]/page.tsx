import { notFound } from 'next/navigation';
import { list, pageId, read, tree, type Node } from '@/lib/documents';
import { Editor } from './editor';
export const dynamic = 'force-dynamic';

const count = (pages: Node[]): number => pages.reduce((n, p) => n + 1 + count(p.pages), 0);

export default async function Page({ params }: { params: Promise<{ path: string[] }> }) {
  const id = await pageId(params);
  const text = id ? await read(id) : null;
  if (!id || text === null) notFound();
  const [pages, all] = await Promise.all([list(id), tree(id)]);
  return <Editor id={id} initial={text} pages={pages} under={count(all)} />;
}
