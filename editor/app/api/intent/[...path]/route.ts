import { nameRule, pageId } from '@/lib/documents';
import { intend, intents } from '@/lib/checks';
export const dynamic = 'force-dynamic';
type Params = { params: Promise<{ path: string[] }> };
// {quote, intent}: what the author means about a finding, for every later check.
export async function POST(request: Request, { params }: Params) {
  const id = await pageId(params); if (!id) return new Response(nameRule, { status: 400 });
  const { quote, intent } = await request.json() as { quote?: string; intent?: string };
  if (!quote) return new Response('An intent is about a phrase', { status: 400 });
  await intend(id, quote, intent ?? ''); return Response.json({ kept: true });
}
export async function GET(_: Request, { params }: Params) {
  const id = await pageId(params); if (!id) return new Response(nameRule, { status: 400 });
  return Response.json(await intents(id));
}
