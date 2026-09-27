// A page's id is its path: the names of the pages above it and its own, joined by /. Shared by the server
// and the pages in the browser.
export const nameOf = (id: string) => id.split('/').pop() ?? id;
export const parentOf = (id: string) => id.split('/').slice(0, -1).join('/');
export const segments = (id: string) => id.split('/').map(encodeURIComponent).join('/');
export const href = (id: string) => `/d/${segments(id)}`;
// Each page above this one, top first, as [id, name].
export const ancestors = (id: string) => id.split('/').slice(0, -1).map((name, i, all) => [all.slice(0, i + 1).join('/'), name] as const);
