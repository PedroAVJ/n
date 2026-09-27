import { nameRule, pageId } from '@/lib/documents';
import { result, start } from '@/lib/checks';
export const dynamic = 'force-dynamic';
type Params = { params: Promise<{ path: string[] }> };
const bad = () => new Response(nameRule, { status: 400 });

// GET: the page's last check. POST: check the saved page in the background.
export async function GET(_: Request, { params }: Params) {
  const id = await pageId(params); if (!id) return bad();
  return Response.json(await result(id));
}
export async function POST(_: Request, { params }: Params) {
  const id = await pageId(params); if (!id) return bad();
  const r = await start(id); return r ? Response.json(r) : new Response('No such page', { status: 404 });
}
