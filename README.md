# Clause Review Status Tracker

Windows desktop app (Arabic, RTL) that tracks each receipt code through the fixed C1–C5 review processes.

| Path | What |
|---|---|
| `Program.cs`, `ui/index.html`, `ClauseTracker.csproj` | Desktop client (WinForms + WebView2) |
| `Server/` | ASP.NET Core 8 API server + PostgreSQL (`Api.cs` = all business rules and role enforcement, `Workflow.cs` = processes C1–C5) |
| `release/` | Deployment guides and scripts (`DEPLOY-TUNNEL.md` is the one in use) |

## Build
```powershell
# client
dotnet publish ClauseTracker.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -o release\Client
# server
dotnet publish Server\ClauseTracker.Server.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -o release\WindowsServer
```
After publishing the server, copy `release\WindowsServer\appsettings.example.json` to `appsettings.json` and put your real Neon connection string in it (that file is git-ignored).

## Secrets
Never commit connection strings or the setup key. `appsettings.json` with real values, `.env` files and all `.exe` files are in `.gitignore`.
