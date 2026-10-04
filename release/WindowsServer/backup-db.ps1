# Backs up the Neon database to a local file (needs the PostgreSQL client tools, i.e. pg_dump, on this PC:
#   winget install PostgreSQL.PostgreSQL.16   - you only need the "Command Line Tools" component).
# Keeps the newest $Keep files. Schedule it daily (PowerShell as Administrator, once):
#   schtasks /Create /TN "ClauseTracker Backup" /SC DAILY /ST 02:00 /RU SYSTEM /TR "powershell -ExecutionPolicy Bypass -File \"<full path>\backup-db.ps1\" -DatabaseUrl \"<neon url>\""
param(
    [Parameter(Mandatory = $true)][string]$DatabaseUrl,
    [string]$PgBin = 'C:\Program Files\PostgreSQL\16\bin',
    [string]$BackupDir = 'C:\ClauseTrackerBackups',
    [int]$Keep = 30
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $BackupDir | Out-Null
$file = Join-Path $BackupDir ("clausetracker-{0:yyyy-MM-dd_HHmm}.dump" -f (Get-Date))
& "$PgBin\pg_dump.exe" --dbname="$DatabaseUrl" -Fc -f $file
if ($LASTEXITCODE -ne 0) { throw "pg_dump failed" }
Get-ChildItem $BackupDir -Filter 'clausetracker-*.dump' | Sort-Object LastWriteTime -Descending | Select-Object -Skip $Keep | Remove-Item -Force
Write-Host "Backup written: $file"
# Restore: pg_restore --dbname="<url>" --clean --if-exists <file>
