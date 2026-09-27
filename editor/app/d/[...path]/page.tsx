import { notFound } from 'next/navigation';
import { list, pageId, read } from '@/lib/documents';
import { Editor } from './editor';
export const dynamic = 'force-dynamic';

export default async function Page({ params }: { params: Promise<{ path: string[] }> }) {
  const id = await pageId(params);
  const text = id ? await read(id) : null;
  if (!id || text === null) notFound();
  return <Editor id={id} initial={text} pages={await list(id)} />;
}
