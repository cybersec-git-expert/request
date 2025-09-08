# Deploying the Request Web (Next.js)

This site runs on Next.js and consumes the existing API. You can deploy on the same EC2 with Nginx or on another host.

## Build

```
npm install
npm run build
```

## Start with PM2 (recommended)

```
# from the web/ folder
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

- App listens on port 3010.
- Set `PUBLIC_API_BASE=https://api.request.lk` once that DNS is live.

## Nginx (sample)

```
server {
  listen 80;
  server_name request.lk www.request.lk;
  return 301 https://$host$request_uri;
}

server {
  listen 443 ssl http2;
  server_name request.lk www.request.lk;

  # ssl_certificate /etc/letsencrypt/live/request.lk/fullchain.pem;
  # ssl_certificate_key /etc/letsencrypt/live/request.lk/privkey.pem;
  # include /etc/letsencrypt/options-ssl-nginx.conf;
  # ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

  location / {
    proxy_pass http://127.0.0.1:3010;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

Issue certs with certbot, similar to your API domain process.

## DNS

- When you purchase the domain:
  - A/AAAA for request.lk and www.request.lk to your EC2 IP.
- Later, create admin.request.lk pointed to the admin app.
- Optionally create api.request.lk CNAME to api.alphabet.lk and add it as an alias to Nginx.

## Environment

- Default `PUBLIC_API_BASE` is https://api.alphabet.lk and works now.
- Switch to https://api.request.lk when you add that alias.

## Notes

- We render banners with `<img>` to accommodate legacy localhost image URLs during dev. In production the backend now returns absolute https URLs, so you can swap to `next/image` for optimization if desired.
