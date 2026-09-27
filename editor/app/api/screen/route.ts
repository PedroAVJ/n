import { screen } from '@/lib/n';
export const dynamic = 'force-dynamic';
export async function POST(request: Request) {
  const text = await request.text();
  if (!text.trim() || text.length > 8000) return Response.json({ marks: [], assessor: '', seconds: 0 });
  try { return Response.json(await screen(text)); } catch (error) { return Response.json({ error: (error as Error).message }, { status: 502 }); }
}
