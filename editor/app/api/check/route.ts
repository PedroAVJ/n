import { check, type Which } from '@/lib/n';
export const dynamic = 'force-dynamic';
const checks = ['type', 'lint', 'format'];
// {text, check}: which of N's checks to run on the text.
export async function POST(request: Request) {
  const { text, check: which } = await request.json() as { text?: string; check?: string };
  if (!text?.trim()) return Response.json({ marks: [], assessor: '', seconds: 0 });
  if (!which || !checks.includes(which)) return Response.json({ error: 'check is type, lint or format' }, { status: 400 });
  try { return Response.json(await check(text, which as Which)); } catch (error) { return Response.json({ error: (error as Error).message }, { status: 502 }); }
}
