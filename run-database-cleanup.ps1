# PowerShell script to run database cleanup
# Usage: .\run-database-cleanup.ps1

param(
    [switch]$DryRun = $false
)

Write-Host "🗄️  Database Cleanup Script" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

# Check if psql is available
try {
    psql --version | Out-Null
} catch {
    Write-Host "❌ psql command not found!" -ForegroundColor Red
    Write-Host "Please install PostgreSQL client tools or use a database admin tool instead." -ForegroundColor Yellow
    Write-Host "You can run the SQL file manually: backend\database\migrations\999_cleanup_ride_tables.sql" -ForegroundColor Yellow
    exit 1
}

# Load environment variables
if (-not (Test-Path ".\production.password.env")) {
    Write-Host "❌ production.password.env not found!" -ForegroundColor Red
    exit 1
}

$envVars = @{}
Get-Content ".\production.password.env" | ForEach-Object {
    if ($_ -match '^([^#][^=]+)=(.*)$') {
        $envVars[$matches[1]] = $matches[2]
    }
}

$dbHost = $envVars['DB_HOST']
$dbPort = $envVars['DB_PORT']
$dbName = $envVars['DB_NAME']
$dbUser = $envVars['DB_USERNAME']

if (-not $dbHost -or -not $dbName -or -not $dbUser) {
    Write-Host "❌ Missing database configuration in environment file!" -ForegroundColor Red
    exit 1
}

Write-Host "🔗 Database: ${dbHost}:${dbPort}/${dbName}" -ForegroundColor Blue
Write-Host "👤 User: $dbUser" -ForegroundColor Blue

if ($DryRun) {
    Write-Host "🧪 DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host "Would execute: backend\database\migrations\999_cleanup_ride_tables.sql" -ForegroundColor Yellow
    exit 0
}

# Confirm before proceeding
Write-Host ""
Write-Host "⚠️  WARNING: This will permanently delete ride/driver related tables and data!" -ForegroundColor Red
Write-Host "Make sure you have a backup of your database before proceeding." -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Do you want to continue? (type 'YES' to confirm)"

if ($confirm -ne "YES") {
    Write-Host "❌ Operation cancelled." -ForegroundColor Yellow
    exit 0
}

# Set password environment variable
$env:PGPASSWORD = $envVars['DB_PASSWORD']

# Run the cleanup script
Write-Host "🚀 Running database cleanup..." -ForegroundColor Green
try {
    $result = psql -h $dbHost -p $dbPort -U $dbUser -d $dbName -f "backend\database\migrations\999_cleanup_ride_tables.sql" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Database cleanup completed successfully!" -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Host "❌ Database cleanup failed!" -ForegroundColor Red
        Write-Host $result
        exit 1
    }
} catch {
    Write-Host "❌ Error running database cleanup: $_" -ForegroundColor Red
    exit 1
} finally {
    # Clear password from environment
    $env:PGPASSWORD = $null
}

Write-Host ""
Write-Host "🎉 Database cleanup completed!" -ForegroundColor Green
Write-Host "Your database is now cleaned of all ride/driver functionality." -ForegroundColor Cyan
