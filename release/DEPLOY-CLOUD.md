# Hosting Clause Tracker online (Render + Neon)

```
Every PC: Client\ClauseTracker.exe ──HTTPS──► Render (the server, from CloudDeploy\) ──► Neon (PostgreSQL)
```
Nobody has to keep a PC running. You only do this setup once (~20 minutes).

## 1. Database – Neon (https://neon.tech)
1. Sign up → **Create project**. Pick the region closest to your users.
2. On the project page click **Connect** and copy the **connection string**. It looks like  
   `postgresql://user:password@ep-xxxx.region.aws.neon.tech/neondb?sslmode=require`
3. Neon keeps automatic backups / point-in-time restore (history window depends on your plan – on the free plan it is short, so use a paid plan for real use).

## 2. Server – Render (https://render.com)
1. Put the contents of the `CloudDeploy` folder in a new **private GitHub repository** (upload the files so `Dockerfile` is at the repo root).
2. Render → **New → Web Service** → connect that repository.
   - **Language / Runtime:** Docker (it detects the Dockerfile)
   - **Instance type:** Starter or higher for real use. The free tier works for a trial but *sleeps after inactivity* and the first request after a sleep takes up to a minute.
   - **Health Check Path:** `/api/health`
3. **Environment variables** (Render → Environment):
   | Name | Value |
   |---|---|
   | `DATABASE_URL` | the Neon connection string from step 1 |
   | `SETUP_KEY` | any long secret you invent, e.g. `K9v-3fQ-77xA-lemon-42` (needed once to create the Leader account) |
   Render sets `PORT` itself. Do **not** put the database password in the repository.
4. Deploy. When it finishes you get an address like `https://clausetracker-abcd.onrender.com`.  
   Check it: open `https://…onrender.com/api/health` → you should see `{"ok":true,…}`.
   (Optional: Render → Settings → Custom Domains to use `https://tracker.yourcompany.com`.)

> Railway, Fly.io, Azure App Service and any VPS work the same way: they just need to run the Docker image with the two environment variables `DATABASE_URL` and `SETUP_KEY`.

## 3. Every PC
1. Copy `Client\ClauseTracker.exe` and run it.
2. Login screen → «إعدادات الاتصال بالخادم» → paste the `https://…` address → حفظ واتصال.
3. First time only: the setup screen asks for the **setup key** (the `SETUP_KEY` value) and creates the **Leader** account. After that the Leader adds the department accounts under «المستخدمون». You can then delete `SETUP_KEY` from Render if you like (it is only checked while no account exists).

## Good to know
- The app refuses plain `http://` for internet addresses – only `https://` is accepted (plain http is allowed only for `localhost` and private office addresses).
- Logins are stored in the database, so redeploying/restarting the server does not log anybody out.
- Login protection: 5 wrong passwords lock that username (from that address) for a minute; each address is limited to 240 requests/minute.
- Run **one** server instance (don't scale to several) – the login lockout counters are kept in memory.
- Updating the server later: push the new code to GitHub → Render redeploys automatically. Tables are created/updated on start.
- Your receipt data is stored with Neon and Render. Confirm that your company allows third-party hosting.
