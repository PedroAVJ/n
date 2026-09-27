import { body, screen } from '@/lib/n';
export const dynamic = 'force-dynamic';
export async function POST(request: Request) {
  const { text, conversation } = await body(request);
  if (!text.trim() || text.length > 8000) return Response.json({ marks: [], assessor: '', seconds: 0 });
  try { return Response.json(await screen(text, conversation)); } catch (error) { return Response.json({ error: (error as Error).message }, { status: 502 }); }
}
