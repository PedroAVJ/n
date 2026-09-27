import { idOk, list, nameRule, setOrder } from '@/lib/documents';
export const dynamic = 'force-dynamic';
// {parent, names}: the order of the pages under parent (none: the top pages); names are those pages, each once.
export async function POST(request: Request) {
  const { parent, names } = await request.json() as { parent?: string; names?: unknown };
  if ((parent && !idOk(parent)) || !Array.isArray(names)) return new Response(nameRule, { status: 400 });
  const there = (await list(parent ?? '')).map(p => p.name);
  if (names.length !== there.length || new Set(names).size !== names.length || !names.every(n => typeof n === 'string' && there.includes(n))) return new Response('The order must name each page here once', { status: 400 });
  await setOrder(parent ?? '', names as string[]);
  return Response.json({ ordered: true });
}
