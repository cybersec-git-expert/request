module.exports = {
  apps: [
    {
      name: 'request-web',
      cwd: __dirname,
      script: 'node_modules/next/dist/bin/next',
      args: 'start -p 3010',
      env: {
        NODE_ENV: 'production',
        PUBLIC_API_BASE: process.env.PUBLIC_API_BASE || 'https://api.alphabet.lk'
      }
    }
  ]
};
