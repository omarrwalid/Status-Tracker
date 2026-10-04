# Run once on the SERVER PC, in PowerShell "as Administrator".
# Installs ClauseTracker.Server as a Windows service (starts at boot, restarts on failure).
#
#   .\install-service.ps1 -SetupKey "<long secret you invent>"          # normal: reached through the Cloudflare Tunnel
#   .\install-service.ps1 -SetupKey "<secret>" -AllowLan                # also reachable directly on the office network
#
# The database is your Neon database: put its connection string in appsettings.json first.
param(
    [Parameter(Mandatory = $true)][string]$SetupKey,
    [int]$Port = 5080,
    [switch]$AllowLan
)

$ErrorActionPreference = 'Stop'
$exe = Join-Path $PSScriptRoot 'ClauseTracker.Server.exe'
$cfgPath = Join-Path $PSScriptRoot 'appsettings.json'
if (-not (Test-Path $exe)) { throw "ClauseTracker.Server.exe not found next to this script." }
if ((Get-Content $cfgPath -Raw) -match 'CHANGE_ME') { throw "Edit appsettings.json first: paste your Neon connection string as ConnectionStrings:Default." }
if ($SetupKey.Length -lt 12) { throw "-SetupKey must be at least 12 characters." }

# Listening address: localhost only (safest, the tunnel connects locally) unless -AllowLan.
$bind = if ($AllowLan) { '0.0.0.0' } else { '127.0.0.1' }
$cfg = Get-Content $cfgPath -Raw
$cfg = [regex]::Replace($cfg, '"Url":\s*"http://[^"]*"', "`"Url`": `"http://${bind}:$Port`"")
Set-Content $cfgPath $cfg -Encoding UTF8

# The setup key protects first-time creation of the Leader account while the server is reachable from the internet.
[Environment]::SetEnvironmentVariable('SETUP_KEY', $SetupKey, 'Machine')

if (Get-Service ClauseTrackerServer -ErrorAction SilentlyContinue) {
    Stop-Service ClauseTrackerServer -Force; sc.exe delete ClauseTrackerServer | Out-Null; Start-Sleep 2
}
New-Service -Name ClauseTrackerServer -BinaryPathName "`"$exe`"" -DisplayName 'Clause Tracker Server' -StartupType Automatic | Out-Null
sc.exe failure ClauseTrackerServer reset= 86400 actions= restart/5000/restart/5000/restart/5000 | Out-Null

Remove-NetFirewallRule -DisplayName 'ClauseTracker Server' -ErrorAction SilentlyContinue
if ($AllowLan) {
    New-NetFirewallRule -DisplayName 'ClauseTracker Server' -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Profile Domain,Private | Out-Null
}

Start-Service ClauseTrackerServer
Start-Sleep 5
try { Invoke-RestMethod "http://127.0.0.1:$Port/api/health" | Out-Null; Write-Host "OK - server is running on port $Port (listening on $bind)." -ForegroundColor Green }
catch { Write-Host "Service started but the health check failed. Check the Neon connection string; see Event Viewer > Application." -ForegroundColor Yellow }
Write-Host "Next: run install-tunnel.ps1 to make it reachable from the other PCs."
