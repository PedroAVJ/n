import { nameRule, pageId, read, save } from '@/lib/documents';
import { remove } from '@/lib/checks';
export const dynamic = 'force-dynamic';
type Params = { params: Promise<{ path: string[] }> };

// PUT: the page's text, saved. Only a page that is there: one renamed or deleted is not written back.
export async function PUT(request: Request, { params }: Params) {
  const id = await pageId(params);
  if (!id) return new Response(nameRule, { status: 400 });
  if ((await read(id)) === null) return new Response('This page is gone: it was renamed or deleted', { status: 404 });
  await save(id, await request.text());
  return Response.json({ saved: true });
}
// DELETE: the page and the pages under it, to N/trash.
export async function DELETE(_: Request, { params }: Params) {
  const id = await pageId(params);
  if (!id) return new Response(nameRule, { status: 400 });
  try { await remove(id); return Response.json({ deleted: true }); }
  catch (e) { return new Response((e as Error).message, { status: 409 }); }
}
