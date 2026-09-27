import './globals.css';
import type { Metadata, Viewport } from 'next';
export const metadata: Metadata = { title: 'N' };
export const viewport: Viewport = { width: 'device-width', initialScale: 1 };
export default function Layout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body className="min-h-screen bg-stone-50 text-stone-900 dark:bg-zinc-950 dark:text-zinc-100 antialiased">{children}</body></html>;
}
