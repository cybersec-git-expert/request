# Backend Deployment via SCP (Simple and Manual)

This guide shows how to deploy the `backend/` to your running EC2 instance using SCP and PM2. No Docker or CI/CD is required.

## Prerequisites
- EC2 instance (Ubuntu 22.04) is running and reachable (public DNS/IP allowed in security group on port 22).
- SSH key pair (PEM) for the instance available on your machine.
- Node.js and npm on the instance (script can install via apt).
- A PM2 process is optional (script uses `pm2` or `npx pm2`).
- App environment file on the instance: `/opt/request-backend/production.env` (create once).

Example `production.env` (adjust values):
```
NODE_ENV=production
PORT=3001
DATABASE_URL=postgres://USER:PASS@HOST:5432/DB
JWT_SECRET=change_me
# add any other required vars your app uses
```

## One-time EC2 prep (run on the server)
```bash
# Log in to the instance first (from your PC)
# ssh -i /path/to/key.pem ubuntu@<EC2_PUBLIC_DNS>

# Ensure base path exists
sudo mkdir -p /opt/request-backend

# Install Node if missing
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

# Create/edit env file
sudo tee /opt/request-backend/production.env >/dev/null <<'EOF'
NODE_ENV=production
PORT=3001
DATABASE_URL=postgres://USER:PASS@HOST:5432/DB
JWT_SECRET=change_me
EOF
```

## Full deploy from your PC (Windows PowerShell)
From the repository root:
```powershell
$env:DEPLOY_HOST = "ec2-54-144-9-226.compute-1.amazonaws.com"   # your EC2 public DNS/IP
$env:DEPLOY_USER = "ubuntu"                                      # SSH user
$env:DEPLOY_KEY_PATH = "E:\MyDrive\Documents\Request\Cloud Services\AWS E3\request-backend-key.pem.pem"

npm run deploy:scp:ps --prefix ./backend
```
What it does:
- Creates a tarball of `backend/` (excludes node_modules, .env*, uploads, .git, *.md).
- Copies it to `/tmp/request-backend.tgz` on the server.
- Extracts to `/opt/request-backend` (override with `DEPLOY_PATH`).
- Installs production deps, restarts/starts with PM2 (override name with `PM2_NAME`).

## Full deploy (macOS/Linux Bash)
```bash
export DEPLOY_HOST=ec2-54-144-9-226.compute-1.amazonaws.com
export DEPLOY_USER=ubuntu
export DEPLOY_KEY_PATH="$HOME/.ssh/request_deploy"
(cd backend && npm run deploy:scp:sh)
```

## Quick single-file patch
```powershell
# Replace with the file you edited locally
$env:DEPLOY_HOST = "ec2-54-144-9-226.compute-1.amazonaws.com"
$env:DEPLOY_USER = "ubuntu"
$env:DEPLOY_KEY_PATH = "E:\MyDrive\Documents\Request\Cloud Services\AWS E3\request-backend-key.pem.pem"

scp -i "$env:DEPLOY_KEY_PATH" .\backend\server.js $env:DEPLOY_USER@$env:DEPLOY_HOST:/opt/request-backend/server.js
ssh -i "$env:DEPLOY_KEY_PATH" $env:DEPLOY_USER@$env:DEPLOY_HOST "pm2 reload request-backend || npx pm2 reload request-backend"
```

## Verify
On server:
```bash
curl -fsS http://127.0.0.1:3001/health
```
If you use Nginx, ensure it proxies `/api` to `http://127.0.0.1:3001` and test your domain `/api/health`.

## Troubleshooting
- Permission denied (publickey): ensure you used the right key and user (Ubuntu AMI user is `ubuntu`).
- PM2 not found: script falls back to `npx pm2`; or install globally `npm i -g pm2`.
- Health check fails: check `pm2 logs request-backend` and confirm DB/env values.
- Don’t overwrite `/opt/request-backend/production.env` when deploying.

### Windows: fix PEM permissions (OpenSSH "UNPROTECTED PRIVATE KEY FILE!")
If SSH fails with a message like "UNPROTECTED PRIVATE KEY FILE!" or mentions `NT AUTHORITY\\Authenticated Users`, tighten the ACLs on the `.pem` file:

PowerShell (replace with your path):
```powershell
$KEY = "E:\MyDrive\Documents\Request\Cloud Services\AWS E3\request-backend-key.pem.pem"
$ME  = "$env:USERDOMAIN\\$env:USERNAME"
${perm} = "$ME:(R)"  # avoid PowerShell parsing issues with colon

icacls "$KEY" /inheritance:r | Out-Null
icacls "$KEY" /grant:r ${perm} | Out-Null
icacls "$KEY" /remove "NT AUTHORITY\\Authenticated Users" "Authenticated Users" "BUILTIN\\Users" "Users" "Everyone" | Out-Null

# Verify
icacls "$KEY"
```
Then retry:
```powershell
ssh -i "$KEY" ubuntu@<EC2_PUBLIC_DNS> "echo SSH_OK"
```

## Security tips
- Never commit PEM or env files to git.
- Restrict SSH security group to your IP.
- Rotate keys if a PEM was shared or exposed.
