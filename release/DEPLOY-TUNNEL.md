# Free setup: one office PC + Cloudflare Tunnel + Neon (no card, no domain needed)

```
Every PC: Client\ClauseTracker.exe ──HTTPS──► Cloudflare Tunnel ──► Server PC (WindowsServer\, a Windows service) ──► Neon (PostgreSQL)
```
- **Neon** keeps all the data online. If the server PC is off, nothing is lost – the app is just unreachable until it's back.
- **The server PC** must be on (and online) whenever people work. A normal office PC is fine. Give it "never sleep" in Power Options.
- **Cloudflare Tunnel** gives the server a public `https://` address without opening any router port.

## 1. Neon (database) – 2 minutes
Neon project → **Connect** → copy the connection string  
`postgresql://user:password@ep-xxxx.region.aws.neon.tech/neondb?sslmode=require`

## 2. Server PC (once) – PowerShell **as Administrator**
1. Copy the `WindowsServer` folder to e.g. `C:\ClauseTracker\Server`.
2. Open `appsettings.json` and replace the whole `ConnectionStrings:Default` value with your Neon string.
3. Install the server (invent a long secret for `-SetupKey` – it's needed once to create the Leader account):
   ```powershell
   cd C:\ClauseTracker\Server
   powershell -ExecutionPolicy Bypass -File .\install-service.ps1 -SetupKey "PUT-A-LONG-SECRET-HERE"
   ```
   It installs the service (starts at boot, restarts on failure) listening on this PC only. You should see `OK - server is running`.
4. Install the tunnel client, then **open a new** Administrator PowerShell:
   ```powershell
   winget install Cloudflare.cloudflared
   ```
5. Start the tunnel:
   ```powershell
   cd C:\ClauseTracker\Server
   powershell -ExecutionPolicy Bypass -File .\install-tunnel.ps1
   ```
   It prints the public address, e.g. `https://automatic-maps-bibliography-abu.trycloudflare.com`. It also starts automatically at every boot.

## 3. Every PC
1. Copy `Client\ClauseTracker.exe` and run it.
2. Login screen → «إعدادات الاتصال بالخادم» → paste the `https://…trycloudflare.com` address → حفظ واتصال.
3. First time only: the setup screen asks for the **setup key** (the `-SetupKey` you chose) and creates the **Leader** account. The Leader then adds department accounts under «المستخدمون».

## The one catch: the free address changes
A free *quick tunnel* gets a **new random address every time the tunnel restarts** (server PC reboot, internet drop). Then:
- the current address is always in `tunnel-url.txt` next to the scripts on the server PC;
- every client has to paste the new address once (login screen → connection settings).

**To get a permanent address** you need a domain on Cloudflare (a domain costs roughly $10/year; Cloudflare itself is free):
1. Add your domain to a free Cloudflare account.
2. Cloudflare dashboard → **Zero Trust → Networks → Tunnels → Create a tunnel** (type *Cloudflared*), copy the **token**.
3. In that tunnel add a **Public hostname**, e.g. `tracker.yourcompany.com` → service `http://localhost:5080`.
4. On the server PC: `.\install-tunnel.ps1 -Token "<token>"` (this replaces the quick tunnel; the address never changes).

## Good to know
- **Security:** the server is reachable from the internet through the tunnel, so use strong passwords. The app allows 5 wrong passwords per minute per user/address, and the first-account setup needs your setup key. Traffic is HTTPS.
- **Backups:** Neon's free plan keeps a short history. `backup-db.ps1` saves a daily copy of the database to the server PC (needs `pg_dump`; command at the top of the file). Keep copies on another disk.
- **Check it works:** open `<address>/api/health` in a browser → `{"ok":true,…}`.
- **Updating the server:** stop the service (`Stop-Service ClauseTrackerServer`), replace `ClauseTracker.Server.exe`, start it again.
- **Reliability:** quick tunnels are meant for testing/light use and have no uptime guarantee. For a business-critical setup, use the named tunnel with a domain, or a paid host.
