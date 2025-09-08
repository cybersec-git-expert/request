# Deploy updated backend/routes/driver-verifications.js to a remote server (Windows PowerShell)
# Prereqs: OpenSSH client (ssh/scp), PM2 running the Node app on the server

param(
  [string]$Server = "user@your-ec2-host",
  [string]$AppDir = "/var/www/request/backend",
  [string]$Pm2Process = "all",   # set to your pm2 process name, or leave 'all'
  [switch]$SkipReload,
  [switch]$SkipHealth,
  [string]$LocalFile = "",         # optional override path to local driver-verifications.js
  [string]$KeyFile = "",           # optional path to SSH private key (e.g., C:\keys\request-backend-key.pem)
  [switch]$NoStrictHostKeyChecking  # set to skip host key prompt on first connect
)

function Write-Step($msg){ Write-Host "==> $msg" -ForegroundColor Cyan }
function Fail($msg){ Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# Validate server placeholder to avoid DNS error
if ($Server -match "your-ec2-host") {
  Fail "Please pass -Server with your real host (e.g., ubuntu@11.22.33.44 or ubuntu@api.alphabet.lk)"
}

# Resolve local file path (either provided or relative to this script)
try {
  if ([string]::IsNullOrWhiteSpace($LocalFile)) {
    $relative = Join-Path -Path $PSScriptRoot -ChildPath "..\backend\routes\driver-verifications.js"
    $LocalFile = (Resolve-Path -Path $relative -ErrorAction Stop).Path
  } else {
    $LocalFile = (Resolve-Path -Path $LocalFile -ErrorAction Stop).Path
  }
} catch {
  Fail "Local file not found or cannot resolve path. Provide -LocalFile or run from repo. Details: $($_.Exception.Message)"
}
if (-not (Test-Path -Path $LocalFile)) { Fail "Local file not found: $LocalFile" }

Write-Step "Server: $Server"
Write-Step "AppDir: $AppDir"
Write-Step "Local file: $LocalFile"
if (-not [string]::IsNullOrWhiteSpace($KeyFile)) { Write-Step "Key file: $KeyFile" }

# Validate tools and key
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) { Fail "ssh not found in PATH. Install OpenSSH client or run from Git Bash." }
if (-not (Get-Command scp -ErrorAction SilentlyContinue)) { Fail "scp not found in PATH. Install OpenSSH client or run from Git Bash." }
if (-not [string]::IsNullOrWhiteSpace($KeyFile) -and -not (Test-Path -Path $KeyFile)) { Fail "Key file not found: $KeyFile" }

# Build common ssh/scp options
$sshOpts = @()
if (-not [string]::IsNullOrWhiteSpace($KeyFile)) { $sshOpts += @('-i', $KeyFile) }
if ($NoStrictHostKeyChecking) { $sshOpts += @('-o', 'StrictHostKeyChecking=no') }

function Invoke-SSH {
  param([string]$SshHost, [string]$SshCommand)
  $sshArgs = @()
  $sshArgs += $sshOpts
  $sshArgs += $SshHost
  $sshArgs += $SshCommand
  & ssh @sshArgs
}

function Invoke-SCP {
  param([string]$LocalPath, [string]$RemotePath)
  $scpArgs = @()
  $scpArgs += $sshOpts
  $scpArgs += $LocalPath
  $scpArgs += $RemotePath
  & scp @scpArgs
}

# Backup remote file
$Timestamp = (Get-Date -Format "yyyy-MM-dd_HHmmss")
# Single-line remote command to avoid CRLF issues on bash
$BackupCmd = "set -e; cd '$AppDir'; if [ -f routes/driver-verifications.js ]; then cp routes/driver-verifications.js routes/driver-verifications.js.bak_$Timestamp; fi"

Write-Step "Backing up remote file..."
Invoke-SSH -SshHost $Server -SshCommand $BackupCmd
if ($LASTEXITCODE -ne 0) { Fail "Remote backup failed." }

# Copy new file
Write-Step "Uploading driver-verifications.js..."
Invoke-SCP -LocalPath $LocalFile -RemotePath "${Server}:${AppDir}/routes/driver-verifications.js"
if ($LASTEXITCODE -ne 0) { Fail "File upload failed." }

if (-not $SkipReload) {
  # Reload PM2
  $ReloadCmd = if ($Pm2Process -eq "all") { "pm2 reload all" } else { "pm2 reload `"$Pm2Process`"" }
  Write-Step "Reloading PM2: $ReloadCmd"
  Invoke-SSH -SshHost $Server -SshCommand $ReloadCmd
  if ($LASTEXITCODE -ne 0) { Fail "PM2 reload failed." }
}

if (-not $SkipHealth) {
  Write-Step "Checking health endpoint..."
  try {
    # Adjust API host as needed
    $health = Invoke-WebRequest -UseBasicParsing -Uri "https://api.alphabet.lk/health" -TimeoutSec 10
    Write-Host $health.Content
  } catch {
    Write-Host "Health check failed: $($_.Exception.Message)" -ForegroundColor Yellow
  }

  Write-Step "Checking public drivers endpoint (sample)..."
  try {
    $test = Invoke-WebRequest -UseBasicParsing -Uri "https://api.alphabet.lk/api/driver-verifications/public?country=LK&limit=1" -TimeoutSec 10
    Write-Host $test.Content
  } catch {
    Write-Host "Public endpoint check failed: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

Write-Host "Done." -ForegroundColor Green
