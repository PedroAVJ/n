import { idOk, save } from '@/lib/notion';
export const dynamic = 'force-dynamic';
export async function PUT(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { before, after } = await request.json() as { before?: string; after?: string };
  if (!idOk(id) || typeof before !== 'string' || typeof after !== 'string') return new Response('Saving needs a page, and its Markdown before and after', { status: 400 });
  try { return Response.json({ raw: await save(id, before, after) }); } catch (error) { return new Response((error as Error).message, { status: 502 }); }
}
