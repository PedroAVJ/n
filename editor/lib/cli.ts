import 'server-only';
import { spawn } from 'node:child_process';

// A command's standard output, with `input` on its standard input (none when undefined).
export function run(command: string, args: string[], input?: string, env: Record<string, string> = {}): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: [input === undefined ? 'ignore' : 'pipe', 'pipe', 'pipe'], timeout: 60000, env: { ...process.env, ...env } });
    let out = '', err = '';
    child.stdout?.on('data', d => { out += d; });
    child.stderr?.on('data', d => { err += d; });
    child.on('error', reject);
    child.on('close', code => code === 0 ? resolve(out) : reject(Error(err.trim() || `${command} exited ${code}`)));
    if (input !== undefined) child.stdin?.end(input);
  });
}
