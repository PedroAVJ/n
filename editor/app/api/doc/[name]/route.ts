import { nameOk, save } from '@/lib/documents';
export const dynamic = 'force-dynamic';
export async function PUT(request: Request, { params }: { params: Promise<{ name: string }> }) {
  const { name } = await params;
  if (!nameOk(name)) return new Response("A document's name is letters, digits, - and _", { status: 400 });
  await save(name, await request.text());
  return Response.json({ saved: true });
}
