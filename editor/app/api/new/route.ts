import { create, idOk, nameOk, nameRule } from '@/lib/documents';
import { href } from '@/lib/pages';
export const dynamic = 'force-dynamic';
// {parent, name}: a new page, at the top (no parent) or under the page whose id is parent.
export async function POST(request: Request) {
  const { parent, name } = await request.json() as { parent?: string; name?: string };
  const n = name?.trim() ?? '';
  const id = parent ? `${parent}/${n}` : n;
  if (!nameOk(n) || !idOk(id)) return new Response(nameRule, { status: 400 });
  try { await create(id); return Response.json({ path: href(id) }); } catch (e) { return new Response((e as Error).message, { status: 404 }); }
}
