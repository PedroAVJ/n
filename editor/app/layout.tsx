import './globals.css';
import type { Metadata, Viewport } from 'next';
import { Inter, Newsreader } from 'next/font/google';

const inter = Inter({ subsets: ['latin'], variable: '--font-inter', display: 'swap' });
const newsreader = Newsreader({ subsets: ['latin'], variable: '--font-newsreader', display: 'swap', style: ['normal', 'italic'] });

export const metadata: Metadata = { title: 'N', appleWebApp: { capable: true, title: 'N', statusBarStyle: 'default' } };
export const viewport: Viewport = { width: 'device-width', initialScale: 1, viewportFit: 'cover', themeColor: [{ media: '(prefers-color-scheme: light)', color: '#fbfaf8' }, { media: '(prefers-color-scheme: dark)', color: '#151514' }] };
export default function Layout({ children }: { children: React.ReactNode }) {
  return <html lang="en" className={`${inter.variable} ${newsreader.variable}`}><body className="min-h-dvh bg-paper font-sans text-ink antialiased">{children}</body></html>;
}
