import { idOk, save } from '@/lib/notion';
export const dynamic = 'force-dynamic';
export async function PUT(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { before, text } = await request.json() as { before?: string; text?: string };
  if (!idOk(id) || typeof before !== 'string' || typeof text !== 'string') return new Response('Saving needs a page, its Markdown before, and its text now', { status: 400 });
  try { return Response.json(await save(id, before, text)); } catch (error) { return new Response((error as Error).message, { status: 502 }); }
}
