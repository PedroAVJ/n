import 'server-only';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { run } from './cli';

// WhatsApp, through the whatsapp CLI and its local bridge: chats, their messages, and sending.
export type Chat = { jid: string; name: string; group: boolean; last: string; at: string };
export type Message = { id: string; mine: boolean; text: string; media: string; at: string };

const whatsapp = process.env.WHATSAPP_BIN || join(homedir(), '.local/bin/whatsapp');
async function cli(args: string[], input?: string): Promise<any> {
  const r = JSON.parse(await run(whatsapp, ['--json', ...args], input));
  if (!r.ok) throw Error(r.error?.message || r.error || 'WhatsApp failed');
  return r.data;
}

export async function chats(limit = 30): Promise<Chat[]> {
  const d = await cli(['chats', 'list', '--sort-by', 'last_active', '--limit', String(limit)]);
  return (d.chats ?? []).filter((c: any) => c.jid !== 'status@broadcast' && !String(c.jid).endsWith('@newsletter'))
    .map((c: any) => ({ jid: c.jid, name: c.display_name || c.name || c.jid, group: c.chat_type === 'group' || String(c.jid).endsWith('@g.us'), last: c.last_message || '', at: c.last_message_time || '' }));
}

export async function chat(jid: string): Promise<Chat | null> {
  const d = await cli(['chats', 'get', jid]).catch(() => null);
  const c = d?.chat ?? d;
  if (!c?.jid) return null;
  return { jid: c.jid, name: c.display_name || c.name || c.jid, group: String(c.jid).endsWith('@g.us'), last: c.last_message || '', at: c.last_message_time || '' };
}

// The newest messages, oldest first.
export async function messages(jid: string, limit = 60): Promise<Message[]> {
  const d = await cli(['messages', 'list', '--chat-jid', jid, '--limit', String(limit)]);
  return (d.formatted ?? []).map((m: any) => ({ id: m.id, mine: !!m.is_from_me, text: m.content || '', media: m.media_type || '', at: m.timestamp })).reverse();
}

export async function send(jid: string, text: string): Promise<void> {
  await cli(['messages', 'send', '--chat-jid', jid, '--text-stdin', '--confirm'], text);
}
