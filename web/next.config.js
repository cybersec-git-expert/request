/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  output: 'standalone',
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'api.alphabet.lk' },
      { protocol: 'https', hostname: 'api.request.lk' },
      { protocol: 'https', hostname: 'www.request.lk' },
  { protocol: 'https', hostname: 'request.lk' },
  { protocol: 'http', hostname: 'localhost' },
  { protocol: 'http', hostname: '127.0.0.1' }
    ]
  },
  env: {
    PUBLIC_API_BASE: process.env.PUBLIC_API_BASE || 'https://api.alphabet.lk'
  }
};

module.exports = nextConfig;
