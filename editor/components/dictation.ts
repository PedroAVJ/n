'use client';
import { useRef, useState } from 'react';

// Dictation: record until pressed again, then ElevenLabs Scribe's text goes to `said`.
export function useDictation(said: (text: string) => void, status: (s: string) => void) {
  const [listening, setListening] = useState(false); const recorder = useRef<MediaRecorder | null>(null);
  const toggle = async () => {
    if (recorder.current) { recorder.current.stop(); return; }
    let stream: MediaStream;
    try { stream = await navigator.mediaDevices.getUserMedia({ audio: true }); } catch { status('No microphone access'); return; }
    const chunks: Blob[] = []; const rec = new MediaRecorder(stream); recorder.current = rec;
    rec.ondataavailable = e => { if (e.data.size) chunks.push(e.data); };
    rec.onstop = async () => {
      stream.getTracks().forEach(t => t.stop()); recorder.current = null; setListening(false); status('Transcribing…');
      try {
        const blob = new Blob(chunks, { type: rec.mimeType || 'audio/webm' });
        const r = await fetch('/api/dictate', { method: 'POST', headers: { 'content-type': blob.type }, body: blob });
        const out = await r.json() as { text?: string; error?: string };
        if (!r.ok || out.text === undefined) throw Error(out.error || 'Dictation failed');
        said(out.text); status('Dictated');
      } catch (e) { status((e as Error).message); }
    };
    rec.start(); setListening(true); status('Listening… press again to stop');
  };
  return { listening, toggle };
}
