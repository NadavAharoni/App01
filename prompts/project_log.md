# Project Log

---

## Current Status
*Last updated: 2026-05-27 19:19 — update this section at the start/end of every session.*

### What's Working
- ✅ Google OAuth 2.0 login — tested with two separate Google accounts
- ✅ Local register / login / logout (email + password)
- ✅ JWT session via HTTP-only cookie (`access_token`, 24h TTL)
- ✅ Protected `/auth/me` endpoint and `get_current_user` dependency
- ✅ Single-page frontend (Tailwind CSS) with auth card + dashboard
- ✅ Neon Postgres connected; `users` table auto-created on startup
- ✅ App runs locally on Python 3.14 via `python -m uvicorn main:app --reload --port 8080`

### What's Not Done Yet
- ⬜ Local credentials login (form exists in UI, untested end-to-end)
- ⬜ Deployed to Google Cloud Run
- ⬜ Cloudflare CDN / R2 integration (future phase)
- ⬜ AI API integration (future phase)

### Known Quirks
- `uvicorn` in PATH is Python 3.13 — always use `python -m uvicorn`, never bare `uvicorn`
- Neon connection string contains libpq params (`sslmode`, `channel_binding`) that asyncpg rejects — `database.py` strips them automatically; don't add them manually to `connect_args`
- `load_dotenv()` is called in `main.py` — `.env` is picked up automatically, no need to set env vars manually when running locally

### Environment
- Local: Windows, Python 3.14.3, WSL2 available as fallback
- DB: Neon Postgres 17 (credentials in `.env`)
- Docker image: `python:3.11-slim` (production target)

### Next Steps
- Test local credentials register/login end-to-end
- Deploy to Google Cloud Run and smoke test

---

## 2026-05-27 18:40–19:19 — Session 2

### Dependency Cleanup & Local Dev Fixes

All issues resolved; Google OAuth confirmed working end-to-end with two separate Google accounts.

#### Dependency Changes (`requirements.txt`)

| Change | Reason |
|---|---|
| Removed `alembic` | Was never used — `Base.metadata.create_all` in the lifespan already handles table creation |
| `passlib[bcrypt]` → `bcrypt==4.1.3` | passlib unmaintained since 2020; `bcrypt` is the library passlib called anyway |
| `python-jose[cryptography]` → `PyJWT==2.8.0` (later bumped to `2.13.0`) | python-jose pulls the heavy `cryptography` binary; HS256 only needs stdlib — `PyJWT` with no extras suffices |
| All packages bumped to current stable | Original pins pre-dated Python 3.14 — `asyncpg 0.29.0` and `pydantic-core 2.18.2` failed to compile on the local Python 3.14 install |

#### Bug Fixes

| File | Fix |
|---|---|
| `database.py` | Strip all libpq-style query params (`sslmode`, `channel_binding`, etc.) from the Neon URL — asyncpg doesn't accept them; pass `ssl="require"` via `connect_args` instead |
| `database.py` | `init_db()` now catches connection failures and logs a warning instead of crashing the app on startup |
| `main.py` | Added `load_dotenv()` so a local `.env` file is picked up automatically; no-op in Cloud Run where vars are injected |

#### Local Dev Notes

- `uvicorn` in PATH resolves to a Python 3.13 install; always run via `python -m uvicorn main:app --reload --port 8080` to use the active Python (3.14)
- WSL2 available as fallback if Python version conflicts arise

#### Git Commits

| Hash | Message |
|---|---|
| `fad3628` | Dependency improvements: remove Alembic, swap passlib->bcrypt, swap python-jose->PyJWT |
| `86441a4` | Bump all deps to current stable; fixes build on Python 3.14 |
| `aab1c4d` | Graceful DB startup: warn instead of crash if DB unreachable |
| `42082f1` | Fix asyncpg SSL: strip all libpq query params, load .env on startup |

#### Milestone

✅ Google OAuth login confirmed working with two separate Google accounts against live Neon Postgres database.

---

## 2026-05-27 17:50–18:08 — Session 1

### Initial Application Build

Implemented the full baseline FastAPI authentication application as specified in `version_01.md`.

#### Files Created

| File | Description |
|---|---|
| `main.py` | FastAPI app entry point; registers routers, mounts static files, runs `init_db()` on startup via lifespan context |
| `database.py` | Async SQLAlchemy engine using `asyncpg`; auto-translates `postgres://` → `postgresql+asyncpg://` for Neon compatibility; `init_db()` creates tables on first run |
| `models.py` | `User` ORM model supporting both local and Google auth: `id` (UUID), `email`, `username`, `hashed_password` (nullable), `auth_provider`, `full_name`, `avatar_url`, `is_active`, `created_at`, `updated_at` |
| `auth.py` | bcrypt password hashing via `bcrypt`; JWT creation and decoding via `PyJWT`; `get_current_user` FastAPI dependency (reads `access_token` HTTP-only cookie) |
| `routers/auth.py` | All authentication endpoints (see API surface below) |
| `routers/__init__.py` | Package marker |
| `requirements.txt` | Pinned dependencies: FastAPI, Uvicorn, SQLAlchemy, asyncpg, bcrypt, PyJWT, httpx, python-multipart, python-dotenv, pydantic[email] |
| `static/index.html` | Single-page frontend (Tailwind CSS via CDN) |
| `.env.example` | Documents all required environment variables |
| `.gitignore` | Excludes `.env`, `__pycache__`, virtual environments |

#### Dockerfile Update

Updated `CMD` to use `${PORT:-8080}` so Google Cloud Run's injected `PORT` environment variable is respected at runtime.

#### API Surface

| Method | Route | Description |
|---|---|---|
| `POST` | `/auth/register` | Register a local account; returns user JSON + sets `access_token` cookie |
| `POST` | `/auth/login` | Authenticate with email + password; sets cookie |
| `POST` | `/auth/logout` | Clears the `access_token` cookie |
| `GET` | `/auth/google` | Redirects to Google OAuth 2.0 consent screen |
| `GET` | `/auth/google/callback` | Exchanges auth code for tokens; upserts user; redirects to `/` |
| `GET` | `/auth/me` | Returns current user profile (protected — requires valid cookie) |
| `GET` | `/` | Serves the SPA (`static/index.html`) |

#### Frontend Features

- "Sign in with Google" button (redirects to `/auth/google`)
- Login / Register tab switcher with inline error display
- Protected Dashboard view: avatar, full name, email, username, user ID, auth provider badge
- Auto-detects existing session on page load via `/auth/me`

#### Environment Variables Required

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | Neon Postgres connection string |
| `GOOGLE_CLIENT_ID` | Google OAuth app client ID |
| `GOOGLE_CLIENT_SECRET` | Google OAuth app client secret |
| `JWT_SECRET` | Secret key for signing JWTs |
| `GOOGLE_REDIRECT_URI` | OAuth callback URL registered in Google Console |
| `PORT` | Injected automatically by Cloud Run (defaults to `8080`) |

#### Git Commit

`08d4a30` — *Implement FastAPI auth app (Google OAuth + local credentials)*
