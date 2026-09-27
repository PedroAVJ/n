import { nameOk } from '@/lib/documents';
import { result, start } from '@/lib/checks';
export const dynamic = 'force-dynamic';
type Params = { params: Promise<{ name: string }> };
const bad = () => new Response("A document's name is letters, digits, - and _", { status: 400 });

// GET: the document's last check. POST: check the saved document in the background.
export async function GET(_: Request, { params }: Params) {
  const { name } = await params; if (!nameOk(name)) return bad();
  return Response.json(await result(name));
}
export async function POST(_: Request, { params }: Params) {
  const { name } = await params; if (!nameOk(name)) return bad();
  const r = await start(name); return r ? Response.json(r) : new Response('No such document', { status: 404 });
}
