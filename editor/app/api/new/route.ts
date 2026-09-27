import { create, nameOk } from '@/lib/documents';
export const dynamic = 'force-dynamic';
export async function POST(request: Request) {
  const name = (await request.text()).trim();
  if (!nameOk(name)) return new Response("A document's name is letters, digits, - and _", { status: 400 });
  await create(name);
  return Response.json({ path: `/d/${name}` });
}
