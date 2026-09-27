import { notFound } from 'next/navigation';
import { named, read } from '@/lib/documents';
import { Editor } from './editor';
export const dynamic = 'force-dynamic';

export default async function Document({ params }: { params: Promise<{ name: string }> }) {
  const name = await named(params);
  const text = name ? await read(name) : null;
  if (!name || text === null) notFound();
  return <Editor name={name} initial={text} />;
}
