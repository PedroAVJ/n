import { check } from '@/lib/n';
export const dynamic = 'force-dynamic';
export async function POST(request: Request) {
  const text = await request.text();
  if (!text.trim()) return Response.json({ marks: [], assessor: '', seconds: 0 });
  try { return Response.json(await check(text)); } catch (error) { return Response.json({ error: (error as Error).message }, { status: 502 }); }
}
