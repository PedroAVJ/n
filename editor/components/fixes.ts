// What Check fixes on its own: each finding with exactly one rewrite that keeps the meaning (N's fixable
// findings). Findings with more than one reading stay as suggestions, for the writer to choose.
import type { Found } from './use-n';
export const fixable = (fs: Found[]) => fs.filter(f => f.fixable && f.new !== undefined).sort((a, b) => b.start - a.start);
