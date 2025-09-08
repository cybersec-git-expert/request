# Domain Setup Guide for Request Marketplace

## Current Setup (api.alphabet.lk)

### DNS Configuration
- **Domain**: api.alphabet.lk
- **Type**: A Record
- **Value**: 54.144.9.22 (Your EC2 IP)
- **TTL**: Usually 300-3600 seconds

### EC2 to Domain Connection Flow
```
User Request → api.alphabet.lk → DNS Lookup → 54.144.9.22 → EC2 Instance → Nginx → Node.js App
```

## How to Switch to request.lk in Future

### Step 1: Domain Purchase & DNS Setup
1. **Purchase request.lk domain** from a registrar
2. **Set up DNS A Record**:
   - Name: `api` (for api.request.lk)
   - Type: A
   - Value: `54.144.9.22` (your current EC2 IP)
   - TTL: 300

### Step 2: Update Flutter App
Update the API client configuration:

```dart
// In lib/src/services/api_client.dart
static String get _baseUrl {
  if (kIsWeb) {
    return 'https://api.request.lk'; // New domain
  } else if (Platform.isAndroid) {
    return 'https://api.request.lk'; // New domain
  } else if (Platform.isIOS) {
    return 'https://api.request.lk'; // New domain
  } else {
    return 'https://api.request.lk'; // New domain
  }
}
```

### Step 3: Update Nginx Configuration on EC2
SSH into your EC2 and update Nginx:

```bash
sudo nano /etc/nginx/sites-available/default
```

Update server_name:
```nginx
server {
    listen 80;
    server_name api.request.lk;  # Change from api.alphabet.lk
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Restart Nginx:
```bash
sudo systemctl restart nginx
```

### Step 4: SSL Certificate Setup
Set up SSL for the new domain:

```bash
# Install certbot if not already installed
sudo apt update
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate for new domain
sudo certbot --nginx -d api.request.lk

# Auto-renewal (if not already set up)
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Step 5: Update App Version & Deploy
1. **Update pubspec.yaml version** (e.g., 1.0.3+4)
2. **Build new app bundle**:
   ```bash
   flutter clean
   flutter pub get
   flutter build appbundle --release
   ```
3. **Upload to Google Play Console**

## Domain Configuration Options

### Option 1: Subdomain (Recommended)
- **API**: `api.request.lk`
- **Admin**: `admin.request.lk`
- **Main Site**: `request.lk` or `www.request.lk`

### Option 2: Path-based
- **API**: `request.lk/api`
- **Admin**: `request.lk/admin`
- **Main Site**: `request.lk`

## DNS Records You'll Need

```
Type    Name    Value           TTL
A       api     54.144.9.22     300
A       admin   54.144.9.22     300
A       @       54.144.9.22     300  (for main domain)
CNAME   www     request.lk      300
```

## Testing Domain Changes

### Before Going Live
1. **Test locally** by editing your hosts file:
   ```
   # Windows: C:\Windows\System32\drivers\etc\hosts
   # Add: 54.144.9.22 api.request.lk
   ```

2. **Test API endpoints**:
   ```bash
   curl http://api.request.lk/health
   curl http://api.request.lk/api/countries
   ```

### After DNS Propagation
- DNS changes can take 24-48 hours to fully propagate
- Use online tools to check DNS propagation: whatsmydns.net

## Important Notes

1. **Keep EC2 IP Static**: Consider using Elastic IP to prevent IP changes
2. **Backup Current Setup**: Document current configuration before changes
3. **Gradual Migration**: You can run both domains temporarily during transition
4. **SSL Certificate**: Remember to get new SSL cert for new domain
5. **App Store Updates**: Plan app updates around domain changes

## Cost Considerations

- **Domain Registration**: ~$10-15/year for .lk domains
- **Elastic IP**: $0.005/hour when not attached to running instance
- **SSL Certificate**: Free with Let's Encrypt
- **No additional EC2 costs**: Same server handles both domains

## Rollback Plan

If issues arise with new domain:
1. **Revert DNS** to old domain
2. **Deploy app** with old API URLs
3. **Update Nginx** back to old server_name
4. **Restore SSL** certificate for old domain

This allows you to switch back quickly if needed.
