import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  base: '/admin/',
  plugins: [react()],
  server: {
    port: 5173,
    host: true,
    proxy: {
      // Proxy API calls to the AWS EC2 production server
      '/api': {
        target: 'http://3.92.216.149:3001', // AWS EC2 production server
        changeOrigin: true,
        secure: false, // Disable SSL verification for HTTP
        // Avoid Vite rewriting or serving index.html for API routes
        configure: (proxy) => {
          proxy.on('proxyReq', (proxyReq) => {
            // Ensure we always pass JSON accept header
            proxyReq.setHeader('Accept', 'application/json');
          });
        },
      },
    },
  },
})
