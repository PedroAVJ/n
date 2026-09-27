import { execFile } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';
export const dynamic = 'force-dynamic';

// Dictation: the recording goes to ElevenLabs Scribe through its CLI (which reads its key from the Keychain),
// with filler words and sound tags left out, and N's own names as key terms.
const cli = process.env.ELEVENLABS_BIN || join(homedir(), '.local/bin/elevenlabs');
const keyterms = ['V', 'N', 'Bend', 'Jev', 'Near', 'launchd', 'Tailscale', 'nix-darwin'];
const extension = (type: string) => type.includes('mp4') || type.includes('m4a') ? 'm4a' : type.includes('ogg') ? 'ogg' : type.includes('wav') ? 'wav' : 'webm';

export async function POST(request: Request) {
  const audio = Buffer.from(await request.arrayBuffer());
  if (!audio.length) return Response.json({ error: 'No audio' }, { status: 400 });
  const dir = await mkdtemp(join(tmpdir(), 'n-dictation-'));
  const file = join(dir, `dictation.${extension(request.headers.get('content-type') || '')}`);
  try {
    await writeFile(file, audio);
    const args = ['transcribe', file, '--response-format', 'text', '--no-verbatim', '--no-tag-audio-events', '--stdout', '--out-dir', dir, ...keyterms.flatMap(k => ['--keyterm', k])];
    const text = await new Promise<string>((resolve, reject) => execFile(cli, args, { timeout: 120000, maxBuffer: 8 << 20 }, (error, stdout, stderr) => error ? reject(Error(stderr.trim().split('\n').pop() || error.message)) : resolve(stdout.trim())));
    return Response.json({ text });
  } catch (error) { return Response.json({ error: (error as Error).message }, { status: 502 }); }
  finally { await rm(dir, { recursive: true, force: true }); }
}
