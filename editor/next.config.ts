import type { NextConfig } from 'next';
// Standalone output: V installs .next/standalone and runs its server.js with Node. The Agent SDK launches its
// platform's Claude binary, which tracing does not follow, so N check's route includes it.
const config: NextConfig = {
  output: 'standalone', reactStrictMode: true, devIndicators: false,
  serverExternalPackages: ['@anthropic-ai/claude-agent-sdk'],
  outputFileTracingIncludes: { '/api/check': ['./node_modules/@anthropic-ai/claude-agent-sdk-darwin-arm64/**/*'] },
};
export default config;
