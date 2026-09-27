import { send } from '@/lib/whatsapp';
export const dynamic = 'force-dynamic';
export async function POST(request: Request) {
  const { jid, text } = await request.json() as { jid?: string; text?: string };
  if (!jid || !/^[\w.-]+@[\w.]+$/.test(jid) || !text?.trim()) return new Response('A message needs a chat and text', { status: 400 });
  try { await send(jid, text); return Response.json({ sent: true }); } catch (error) { return new Response((error as Error).message, { status: 502 }); }
}
