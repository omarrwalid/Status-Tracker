---
title: Clause Tracker Server
emoji: 📋
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
pinned: false
---

Clause Review Status Tracker – API server (ASP.NET Core 8 + PostgreSQL).

Configuration is read from environment variables (set them as Space **secrets**, never in files):

- `DATABASE_URL` – PostgreSQL connection string (e.g. from Neon)
- `SETUP_KEY` – secret needed once to create the first (Leader) account

Health check: `/api/health`
