import { notFound } from 'next/navigation';
import { nameOk, read } from '@/lib/documents';
import { Editor } from './editor';
export const dynamic = 'force-dynamic';

export default async function Document({ params }: { params: Promise<{ name: string }> }) {
  const { name } = await params;
  const text = nameOk(name) ? await read(name) : null;
  if (text === null) notFound();
  return <Editor name={name} initial={text} />;
}
