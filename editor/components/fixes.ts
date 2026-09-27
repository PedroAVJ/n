// What a check fixes on its own: each finding with exactly one rewrite that keeps the meaning. Findings
// with more than one reading stay, for the writer to choose or write their own.
import type { Found } from './use-n';
export const fixable = (fs: Found[]) => fs.filter(f => f.fixable && !(f.options?.length)).sort((a, b) => b.start - a.start);
