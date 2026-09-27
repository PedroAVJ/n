import type { NextConfig } from 'next';
// Standalone output: V installs .next/standalone and runs its server.js with Node.
const config: NextConfig = { output: 'standalone', reactStrictMode: true, devIndicators: false, serverExternalPackages: ['@anthropic-ai/claude-agent-sdk'] };
export default config;
