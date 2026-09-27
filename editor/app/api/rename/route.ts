import { nameOk, nameRule } from '@/lib/documents';
import { rename } from '@/lib/checks';
export const dynamic = 'force-dynamic';
// {from, to}: rename a document, with its check, intents and draft.
export async function POST(request: Request) {
  const { from, to } = await request.json() as { from?: string; to?: string };
  const target = to?.trim() ?? '';
  if (!from || !nameOk(from) || !nameOk(target)) return new Response(nameRule, { status: 400 });
  try { await rename(from, target); return Response.json({ path: `/d/${encodeURIComponent(target)}` }); }
  catch (e) { return new Response((e as Error).message, { status: 409 }); }
}
