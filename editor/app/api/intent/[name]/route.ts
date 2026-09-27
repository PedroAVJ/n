import { nameOk } from '@/lib/documents';
import { intend, intents } from '@/lib/checks';
export const dynamic = 'force-dynamic';
// {quote, intent}: what the author means about a finding, for every later check.
export async function POST(request: Request, { params }: { params: Promise<{ name: string }> }) {
  const { name } = await params; if (!nameOk(name)) return new Response("A document's name is letters, digits, - and _", { status: 400 });
  const { quote, intent } = await request.json() as { quote?: string; intent?: string };
  if (!quote) return new Response('An intent is about a phrase', { status: 400 });
  await intend(name, quote, intent ?? ''); return Response.json({ kept: true });
}
export async function GET(_: Request, { params }: { params: Promise<{ name: string }> }) {
  const { name } = await params; if (!nameOk(name)) return new Response("A document's name is letters, digits, - and _", { status: 400 });
  return Response.json(await intents(name));
}
