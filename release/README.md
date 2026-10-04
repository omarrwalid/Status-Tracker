# Clause Tracker – what is in this folder

| Folder / file | What it is |
|---|---|
| `Client\ClauseTracker.exe` | The desktop app. Copy it to every user PC (no install). |
| `WindowsServer\` | The server, run as a Windows service on one office PC. **Chosen setup:** with Neon + a free Cloudflare Tunnel → guide `DEPLOY-TUNNEL.md` |
| `CloudDeploy\` | Server source + Dockerfile for hosts that run Docker (Render needs a card; Hugging Face Docker may be paid) → `DEPLOY-CLOUD.md`, `DEPLOY-HUGGINGFACE.md` |

Start with **`DEPLOY-TUNNEL.md`**.

In the client: login screen → «إعدادات الاتصال بالخادم» → server address (`https://…`).