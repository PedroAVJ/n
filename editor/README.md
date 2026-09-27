# N editor

Where `.n` documents are written until each says exactly one thing. A document's title is its first
`#` heading; its Markdown renders beside it. Jev screens it when typing pauses, and N check has
Claude Opus read the whole document for type errors and lint, giving each finding its fix or its
readings.

Next.js, React and Tailwind. Documents are files in `~/Library/Application Support/N/documents`.
N's checks run through N's binary (`N_BIN`, built from `n/n.bend` in this repository),
with Jev's OpenRouter key from the Keychain item `N_KEYCHAIN`, and Claude on the owner's Claude
subscription through the Agent SDK.

It is deployed by V from this repository's architecture: V builds it (`next build`, standalone), installs
it, and runs it as the launch agent `com.pedro.n-editor` on 127.0.0.1:4610, served on the tailnet at :9447.
