# Keeps a Cloudflare "quick tunnel" running and writes its current public address to tunnel-url.txt.
# (Started automatically at boot by install-tunnel.ps1; you normally never run this by hand.)
# The address changes every time the tunnel restarts (PC reboot, network drop) - read tunnel-url.txt for the new one.
param([string]$Cloudflared = 'cloudflared', [int]$Port = 5080)

$dir = $PSScriptRoot
$log = Join-Path $dir 'tunnel.log'
$urlFile = Join-Path $dir 'tunnel-url.txt'

while ($true) {
    Remove-Item $log, $urlFile -ErrorAction SilentlyContinue
    $p = Start-Process $Cloudflared -ArgumentList "tunnel --url http://127.0.0.1:$Port --no-autoupdate" `
        -RedirectStandardError $log -RedirectStandardOutput (Join-Path $dir 'tunnel.out') -WindowStyle Hidden -PassThru
    for ($i = 0; $i -lt 90 -and -not $p.HasExited; $i++) {
        Start-Sleep 1
        $m = if (Test-Path $log) { Select-String -Path $log -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' -ErrorAction SilentlyContinue | Select-Object -First 1 }
        if ($m) { Set-Content $urlFile $m.Matches[0].Value -Encoding ascii; break }
    }
    $p.WaitForExit()
    Start-Sleep 5     # tunnel died (network drop?) - start a new one
}
