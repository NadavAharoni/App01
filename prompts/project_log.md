# Project Log

---

## 2026-05-27

### Initial Application Build

Implemented the full baseline FastAPI authentication application as specified in `version_01.md`.

#### Files Created

| File | Description |
|---|---|
| `main.py` | FastAPI app entry point; registers routers, mounts static files, runs `init_db()` on startup via lifespan context |
| `database.py` | Async SQLAlchemy engine using `asyncpg`; auto-translates `postgres://` → `postgresql+asyncpg://` for Neon compatibility; `init_db()` creates tables on first run |
| `models.py` | `User` ORM model supporting both local and Google auth: `id` (UUID), `email`, `username`, `hashed_password` (nullable), `auth_provider`, `full_name`, `avatar_url`, `is_active`, `created_at`, `updated_at` |
| `auth.py` | bcrypt password hashing via `passlib`; JWT creation and decoding via `python-jose`; `get_current_user` FastAPI dependency (reads `access_token` HTTP-only cookie) |
| `routers/auth.py` | All authentication endpoints (see API surface below) |
| `routers/__init__.py` | Package marker |
| `requirements.txt` | Pinned dependencies: FastAPI, Uvicorn, SQLAlchemy, asyncpg, Alembic, passlib[bcrypt], python-jose, httpx, python-multipart, python-dotenv, pydantic[email] |
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
