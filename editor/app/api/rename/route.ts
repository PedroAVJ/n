import { idOk, nameOk, nameRule } from '@/lib/documents';
import { rename } from '@/lib/checks';
import { href } from '@/lib/pages';
export const dynamic = 'force-dynamic';
// {from, to}: give the page whose id is from the name to, with the pages under it, its check, intents and drafts.
export async function POST(request: Request) {
  const { from, to } = await request.json() as { from?: string; to?: string };
  const name = to?.trim() ?? '';
  if (!from || !idOk(from) || !nameOk(name)) return new Response(nameRule, { status: 400 });
  try { return Response.json({ path: href(await rename(from, name)) }); }
  catch (e) { return new Response((e as Error).message, { status: 409 }); }
}
