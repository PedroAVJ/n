import { create, nameOk, nameRule } from '@/lib/documents';
export const dynamic = 'force-dynamic';
export async function POST(request: Request) {
  const name = (await request.text()).trim();
  if (!nameOk(name)) return new Response(nameRule, { status: 400 });
  await create(name);
  return Response.json({ path: `/d/${encodeURIComponent(name)}` });
}
