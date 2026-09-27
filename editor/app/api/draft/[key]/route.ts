import { drop, keyOk, read, save } from '@/lib/drafts';
export const dynamic = 'force-dynamic';
type Params = { params: Promise<{ key: string }> };
const bad = () => new Response("A draft's key is letters, digits and :@.-_", { status: 400 });

export async function GET(_: Request, { params }: Params) {
  const key = decodeURIComponent((await params).key);
  return keyOk(key) ? Response.json({ text: await read(key) }) : bad();
}
// PUT from the page as it is typed; POST from its beacon as it closes.
async function put(request: Request, { params }: Params) {
  const key = decodeURIComponent((await params).key);
  if (!keyOk(key)) return bad();
  await save(key, await request.text());
  return Response.json({ saved: true });
}
export { put as PUT, put as POST };
export async function DELETE(_: Request, { params }: Params) {
  const key = decodeURIComponent((await params).key);
  if (!keyOk(key)) return bad();
  await drop(key);
  return Response.json({ dropped: true });
}
