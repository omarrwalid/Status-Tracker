# Run once on the SERVER PC, in PowerShell "as Administrator", AFTER install-service.ps1.
# Makes the server reachable from the other PCs over HTTPS using Cloudflare Tunnel (free).
#
#   .\install-tunnel.ps1                       # QUICK tunnel: no account, no domain. Address changes on every tunnel restart.
#   .\install-tunnel.ps1 -Token "<token>"      # NAMED tunnel: permanent address (needs a free Cloudflare account + a domain you own on Cloudflare)
param([string]$Token = '', [int]$Port = 5080)

$ErrorActionPreference = 'Stop'

# Find cloudflared (install it with: winget install Cloudflare.cloudflared)
$cf = (Get-Command cloudflared -ErrorAction SilentlyContinue).Source
if (-not $cf) { $cf = Join-Path $PSScriptRoot 'cloudflared.exe' }
if (-not (Test-Path $cf)) { throw "cloudflared not found. Run:  winget install Cloudflare.cloudflared   (then open a NEW PowerShell as Administrator) - or put cloudflared.exe in this folder." }

if ($Token) {
    # Permanent address: cloudflared runs as its own Windows service. In the Cloudflare dashboard, give the tunnel a
    # public hostname (e.g. tracker.yourcompany.com) pointing to  http://localhost:$Port
    & $cf service install $Token
    Write-Host "Named tunnel installed. Your address is the public hostname you set in the Cloudflare dashboard (https://...)." -ForegroundColor Green
    return
}

$script = Join-Path $PSScriptRoot 'run-quick-tunnel.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Cloudflared `"$cf`" -Port $Port"
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -RestartCount 99 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable
Unregister-ScheduledTask -TaskName 'ClauseTracker Tunnel' -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName 'ClauseTracker Tunnel' -Action $action -Trigger $trigger -Settings $settings -User 'SYSTEM' -RunLevel Highest | Out-Null
Start-ScheduledTask -TaskName 'ClauseTracker Tunnel'

$urlFile = Join-Path $PSScriptRoot 'tunnel-url.txt'
Write-Host "Starting tunnel..."
for ($i = 0; $i -lt 60 -and -not (Test-Path $urlFile); $i++) { Start-Sleep 1 }
if (Test-Path $urlFile) {
    $url = (Get-Content $urlFile -Raw).Trim()
    Write-Host "`nType this address in every client PC:  $url" -ForegroundColor Green
    Write-Host "It changes if the tunnel restarts (reboot / network drop). The current address is always in: $urlFile"
} else { Write-Host "Tunnel did not report an address yet. Check $(Join-Path $PSScriptRoot 'tunnel.log')." -ForegroundColor Yellow }
