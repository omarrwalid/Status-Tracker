# Hosting Clause Tracker free, without a card (Hugging Face Spaces + Neon)

```
Every PC: Client\ClauseTracker.exe ──HTTPS──► Hugging Face Space (server, from CloudDeploy\) ──► Neon (PostgreSQL)
```
Free-tier rules change; if a screen below differs from what you see, follow the site's wording.

## 1. Database – Neon (https://neon.tech)
1. Open your Neon project → **Connect** → copy the connection string:  
   `postgresql://user:password@ep-xxxx.region.aws.neon.tech/neondb?sslmode=require`
2. Keep it private – it contains the database password.

## 2. Server – Hugging Face Space (https://huggingface.co)
1. Sign up / log in → **New Space** (huggingface.co/new-space).
   - **Space name:** e.g. `clausetracker`
   - **SDK:** **Docker** → template **Blank**
   - **Hardware:** CPU basic (free)
   - **Visibility:** see the note at the end.
2. **Add the files:** in the new Space open **Files → Add file → Upload files** and upload everything inside the `CloudDeploy` folder  
   (`Dockerfile`, `README.md`, `Program.cs`, `Api.cs`, `Db.cs`, `Workflow.cs`, `ClauseTracker.Server.csproj`, `appsettings.json`, `.dockerignore`).  
   `Dockerfile` and `README.md` must be at the top level of the Space. Click **Commit**.
3. **Secrets:** Space → **Settings → Variables and secrets → New secret**, add two:
   | Name | Value |
   |---|---|
   | `DATABASE_URL` | the Neon connection string |
   | `SETUP_KEY` | a long secret you invent, e.g. `K9v-3fQ-77xA-lemon-42` |
4. The Space builds automatically (first build takes a few minutes; watch the **Logs**). When it says **Running**, check:  
   `https://<your-username>-<space-name>.hf.space/api/health` → should show `{"ok":true,…}`.  
   If you added the secrets after the first build, use **Settings → Factory rebuild** (or Restart) so they take effect.

## 3. Every PC
1. Copy `Client\ClauseTracker.exe` and run it.
2. Login screen → «إعدادات الاتصال بالخادم» → paste `https://<your-username>-<space-name>.hf.space` → حفظ واتصال.
3. First time only: the setup screen asks for the **setup key** (`SETUP_KEY`) and creates the **Leader** account. The Leader then adds department accounts under «المستخدمون».

## Good to know
- **Sleeping:** free Spaces go to sleep after a while without traffic; the first request afterwards can take up to a minute (the app waits 60 s). Data is not lost – it is in Neon. If the delay bothers you, upgrade the Space hardware or move to a paid host.
- **Visibility:** a *public* Space shows your code (not your secrets) to anyone. Nothing sensitive is in the code, and the app itself needs a login, but if you prefer privacy, check Hugging Face's current docs on private Spaces before using one – I have not verified that the desktop app can connect to a private Space.
- **Backups:** Neon's free plan keeps only a short history. Before relying on this for real work, use a paid Neon plan or schedule your own `pg_dump` of the Neon database.
- **Updating:** upload the new files to the Space (or `git push`); it rebuilds automatically. Tables are updated on start.
- Run only **one** instance (login lockout counters are in memory).
