// N's icons: one stroke, drawn at 20 by 20.
type P = { className?: string };
const svg = (d: React.ReactNode) => function Icon({ className = 'size-5' }: P) {
  return <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round" aria-hidden className={className}>{d}</svg>;
};
export const PageIcon = svg(<><path d="M5.5 2.75h6l3 3v11.5h-9z" /><path d="M11.5 2.75v3h3" /><path d="M7.75 10h4.5M7.75 13h4.5" /></>);
export const MicIcon = svg(<><rect x="7.25" y="2.75" width="5.5" height="9" rx="2.75" /><path d="M4.75 9.5a5.25 5.25 0 0 0 10.5 0M10 14.75v2.5" /></>);
export const CopyIcon = svg(<><rect x="6.75" y="6.75" width="10" height="10" rx="2" /><path d="M13.25 6.75v-2a2 2 0 0 0-2-2h-6.5a2 2 0 0 0-2 2v6.5a2 2 0 0 0 2 2h2" /></>);
export const PlusIcon = svg(<path d="M10 4.5v11M4.5 10h11" />);
export const CloseIcon = svg(<path d="M5.5 5.5l9 9M14.5 5.5l-9 9" />);
export const TickIcon = svg(<path d="M4.5 10.5l3.5 3.5 7.5-8" />);
export const UpIcon = svg(<path d="M5.5 12l4.5-4.5 4.5 4.5" />);
export const DownIcon = svg(<path d="M5.5 8l4.5 4.5L14.5 8" />);
export const ChevronIcon = svg(<path d="M8 5.5l4.5 4.5L8 14.5" />);
export function Spinner({ className = 'size-4' }: P) {
  return <span aria-hidden className={`${className} inline-block animate-spin rounded-full border-2 border-current border-t-transparent`} />;
}
