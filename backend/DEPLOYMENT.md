Backend Deployment (No SCP)

Overview
- Build and publish Docker images automatically on push to main.
- Server redeploys strictly via a single script (/opt/request-backend/redeploy.sh). No other workflow should start containers directly.

Environments
- Production: branch main → image tag ghcr.io/<owner>/request-backend:<git-sha>. Redeploy is manual-only via Backend Redeploy workflow.
- Staging: branch develop → image tag ghcr.io/<owner>/request-backend:<git-sha>-stg. Redeploy is manual-only via Backend Redeploy workflow.

CI/CD
- GitHub Actions workflow at `.github/workflows/backend-deploy.yml` builds Docker image from `backend/` and pushes to GHCR. Deploy steps in this file are disabled; use `backend-redeploy.yml` to execute server redeploys.
- Image tags:
  - `ghcr.io/<owner-lower>/request-backend:latest`
  - `ghcr.io/<owner-lower>/request-backend:<git-sha>` (deploys use the immutable sha tag)
- Required repo secrets:
  - `GHCR_USER` (lowercase GitHub username or org) and `GHCR_TOKEN` (PAT with `read:packages`, `write:packages`) — used for image push; if not set, workflow falls back to `GITHUB_TOKEN` for GHCR push.
  - `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY` — used by SSH deploy.
- GHCR visibility: if your GHCR package is private, the server must also authenticate (workflow will docker login with `GHCR_USER/TOKEN` on the server if provided). If public, server can pull anonymously.
  - Node 20, `npm ci`
  - `npm run lint` (if present)
  - `npm test` (if present)
Staging deployment
- Workflow: `.github/workflows/backend-deploy-staging.yml` (push to `develop` or manual dispatch)
- Tags pushed: `staging` and `<git-sha>-stg`
- Required repo secrets:
  - `STAGING_DEPLOY_HOST`, `STAGING_DEPLOY_USER`, `STAGING_DEPLOY_SSH_KEY`
  - Optional `GHCR_USER`, `GHCR_TOKEN` if GHCR is private
- Server binds container to `127.0.0.1:3101` (keep behind Nginx if exposing)
- Expects env file at `/opt/request-backend/production.env` (you can switch to a dedicated staging env path later)

Server setup (one-time)
1) Install Docker
   - Ubuntu: sudo apt-get update && sudo apt-get install -y docker.io
   - Ensure your user is in docker group: sudo usermod -aG docker $USER
2) Create app dir and env file
   - sudo mkdir -p /opt/request-backend && sudo chown $USER:$USER /opt/request-backend
   - Create /opt/request-backend/production.env with required environment variables (copy from backend/.env.example)
3) Keep container bound to localhost and proxy via Nginx
   - Container is started with: `-p 127.0.0.1:3001:3001` (not exposed publicly)
   - Configure Nginx to proxy your domain (e.g., `/api`) to `http://127.0.0.1:3001`

How deployments work
- On push to main: workflow builds image and pushes `latest` and `<git-sha>` to GHCR (owner normalized to lowercase).
- Server-side container start is done exclusively by `/opt/request-backend/redeploy.sh` which:
  - Removes any existing containers by canonical name, legacy name, label, and by image repo match.
  - Starts exactly one container named `request-backend-container` on port 3001 (127.0.0.1 bind by default).
  - Health-checks `/health` before completing.
  - Writes the last successful sha to `/opt/request-backend/last_successful.sha`.

How staging deployments work
- On push to develop: workflow builds and pushes `staging` and `<git-sha>-stg` to GHCR.
- Deploy pulls `<git-sha>-stg`, starts `request-backend-stg` container bound to `127.0.0.1:3101`, then health checks `/health` on port 3101.

Local development
- docker compose -f backend/docker-compose.yml up --build

Rollbacks
- SSH to server and run:
  docker pull ghcr.io/<owner>/request-backend:<old-sha>

Staging rollback (similar)
- SSH to staging server and run:
  docker pull ghcr.io/<owner>/request-backend:<old-sha>-stg
  docker rm -f request-backend-stg
  docker run -d --name request-backend-stg --restart unless-stopped --env-file /opt/request-backend/production.env -p 127.0.0.1:3101:3001 ghcr.io/<owner>/request-backend:<old-sha>-stg

Notes
- Ensure production.env matches the variables consumed by backend/server.js.
- For Nginx TLS, keep Nginx on host and proxy to http://localhost:3001.
 - If `/health` depends on DB and the database is unreachable, deployment will fail and rollback. Verify DB access and credentials in `production.env` before retrying.
 - If GHCR pulls fail on server, either set `GHCR_USER/GHCR_TOKEN` repo secrets (server docker login is attempted) or make the GHCR package public.

Standardize container name (avoid duplicates)
- Always use a single canonical name: `request-backend-container`.
- Never start containers directly from CI or ad-hoc scripts. Always call the helper script below.

Helper script (server)
```bash
bash /opt/request-backend/redeploy.sh <tag-or-sha> [--public]
# Example:
bash /opt/request-backend/redeploy.sh fa3e6cb7d845608f8db12ef246201759eef6f243
```

Installing the helper once
```bash
sudo mkdir -p /opt/request-backend
sudo cp backend/deploy/redeploy.sh /opt/request-backend/
sudo chmod +x /opt/request-backend/redeploy.sh
```

Alternative install (no repo on server)
```bash
sudo mkdir -p /opt/request-backend
sudo tee /opt/request-backend/redeploy.sh > /dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

NAME="request-backend-container"
PORT="3001"
HOST_BIND="127.0.0.1"
ENV_FILE="/opt/request-backend/production.env"
REPO="ghcr.io/gitgurusl/request-backend"

usage() {
  echo "Usage: $(basename "$0") <tag-or-full-image> [--public]"
  echo "  <tag-or-full-image>  Either an image tag/sha (e.g., latest or <sha>) or a full image ref"
  echo "  --public              Bind to 0.0.0.0 instead of 127.0.0.1"
}

if [[ ${1:-} == "" ]]; then
  usage
  exit 1
fi

IMAGE_ARG="$1"; shift || true
if [[ ${1:-} == "--public" ]]; then
  HOST_BIND="0.0.0.0"
fi

if [[ "$IMAGE_ARG" == *":"* && "$IMAGE_ARG" == ghcr.io/* ]]; then
  IMAGE="$IMAGE_ARG"
else
  IMAGE="$REPO:$IMAGE_ARG"
fi

echo "Deploying image: $IMAGE"
echo "Container name: $NAME"
echo "Host bind:      $HOST_BIND:$PORT -> 3001"
echo "Env file:       $ENV_FILE"

docker pull "$IMAGE"
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" \
  --restart unless-stopped \
  --env-file "$ENV_FILE" \
  -p "$HOST_BIND:$PORT:3001" \
  "$IMAGE"

ATTEMPTS=30
for i in $(seq 1 $ATTEMPTS); do
  if curl -fsS "http://localhost:$PORT/health" >/dev/null 2>&1; then
    echo "Healthy at http://localhost:$PORT/health"
    exit 0
  fi
  sleep 2
done

echo "Health check failed. Showing logs:"
docker logs --tail=200 "$NAME" || true
exit 1
EOF
sudo chmod +x /opt/request-backend/redeploy.sh

Policy to prevent duplicate containers
- CI workflows that previously ran `docker run` have been disabled from doing so.
- Only the server’s `/opt/request-backend/redeploy.sh` may start/replace the backend container.
- The script removes any containers matching the app’s label or image repository before starting the new one.
```

Troubleshooting: no space left on device (Docker pull/extract)
```bash
# Inspect usage
df -h
docker system df

# Free Docker space (removes unused containers/images/build cache)
sudo docker system prune -af
sudo docker builder prune -af
# Optional: prune unused volumes (skip if you rely on named volumes)
# sudo docker volume prune -f

# Trim large Docker container logs
sudo find /var/lib/docker/containers -name '*-json.log' -type f -exec sudo truncate -s 0 {} +

# Clean OS caches and logs
sudo apt-get clean
sudo journalctl --vacuum-time=2d

# Retry deploy
sudo /opt/request-backend/redeploy.sh <tag-or-sha>
curl -sS http://localhost:3001/health
```

Tip: If you want pretty JSON in health output, install jq: `sudo apt-get install -y jq`, then use `curl -sS http://localhost:3001/health | jq .`.

<!-- ci: trigger backend build - 2025-08-27T10:30Z -->
 - GHCR repository owner must be lowercase; the workflow normalizes owner for tags, but set GHCR_USER secret in lowercase to avoid auth issues.

.dockerignore
- Added to reduce Docker build context size (excludes node_modules, uploads, .env*, .git, markdown, etc.).

Simple SCP deployment (no CI)

Windows PowerShell
```powershell
$env:DEPLOY_HOST = "your.server.ip"     # e.g., 203.0.113.10
$env:DEPLOY_USER = "ubuntu"             # your SSH user
$env:DEPLOY_KEY_PATH = "$env:USERPROFILE\.ssh\request_deploy"  # optional key path
cd $PSScriptRoot
npm run deploy:scp:ps --prefix ./backend
```

Bash (macOS/Linux)
```bash
export DEPLOY_HOST=your.server.ip   # e.g., 203.0.113.10
export DEPLOY_USER=ubuntu           # your SSH user
export DEPLOY_KEY_PATH=$HOME/.ssh/request_deploy  # optional
(cd backend && npm run deploy:scp:sh)
```

What it does
- Creates a tarball of `backend/` (excluding node_modules, .env*, uploads, .git).
- Copies it to the server at `/tmp/request-backend.tgz`.
- Extracts to `/opt/request-backend` (override with DEPLOY_PATH).
- Installs production deps and restarts/starts via PM2 (`PM2_NAME` env to change name).

<!-- ci: trigger backend deploy - 2025-08-27T00:00Z -->
