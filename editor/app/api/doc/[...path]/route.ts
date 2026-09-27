import { nameRule, pageId, save } from '@/lib/documents';
export const dynamic = 'force-dynamic';
export async function PUT(request: Request, { params }: { params: Promise<{ path: string[] }> }) {
  const id = await pageId(params);
  if (!id) return new Response(nameRule, { status: 400 });
  await save(id, await request.text());
  return Response.json({ saved: true });
}
