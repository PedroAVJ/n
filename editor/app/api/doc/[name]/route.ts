import { named, nameRule, save } from '@/lib/documents';
export const dynamic = 'force-dynamic';
export async function PUT(request: Request, { params }: { params: Promise<{ name: string }> }) {
  const name = await named(params);
  if (!name) return new Response(nameRule, { status: 400 });
  await save(name, await request.text());
  return Response.json({ saved: true });
}
