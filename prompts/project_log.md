# Project Log

---

## Current Status
*Last updated: 2026-08-19 — update this section at the start/end of every session.*

### What's Working
- ✅ Google OAuth 2.0 login — tested locally and on Cloud Run with two separate Google accounts.
  Re-verified end to end in production 2026-08-19 against the restyled frontend: sign-in creates
  the Neon `users` row, the dashboard renders the profile, and Google's generated letter-avatar
  loads via `avatar_url`. `username` is correctly `—` for Google accounts.
- ✅ Local register / login / logout (email + password)
- ✅ JWT session via HTTP-only cookie (`access_token`, 24h TTL)
- ✅ Protected `/auth/me` endpoint and `get_current_user` dependency
- ✅ Public marketing home page (hero, features, stack, CTA) reachable without logging in
- ✅ Sticky menu bar with Sign in / Sign up buttons and a hamburger menu on narrow screens
- ✅ Dashboard as a second view behind auth; signing out returns to the public home page
- ✅ Neon Postgres connected; `users` table auto-created on startup
- ✅ App runs locally on Python 3.14 via `python -m uvicorn main:app --reload --port 8080`
- ✅ Deployed to Google Cloud Run

### What's Not Done Yet
- ⬜ Local credentials login (form exists in UI, untested end-to-end)
- ⬜ Cloudflare CDN / R2 integration (future phase)
- ⬜ AI API integration (future phase)

### Known Quirks
- `uvicorn` in PATH is Python 3.13 — always use `python -m uvicorn`, never bare `uvicorn`
- Neon connection string contains libpq params (`sslmode`, `channel_binding`) that asyncpg rejects — `database.py` strips them automatically; don't add them manually to `connect_args`
- `load_dotenv()` is called in `main.py` — `.env` is picked up automatically, no need to set env vars manually when running locally
- Cloud Run terminates HTTPS at the ingress — `ProxyHeadersMiddleware` in `main.py` ensures `request.base_url` reflects the correct `https://` scheme
- **Tailwind CDN has two traps, both hit in `static/index.html`:** (1) `@apply` in a `<style>` block does nothing — it is a build-time directive, so write plain CSS; (2) the CDN only compiles class names it can find in the document, so a class that exists *only* inside a JS string (e.g. `lg:inline` in an `innerHTML` template) is never generated. Keep both auth states in the static HTML and toggle them instead of injecting markup.
- No `.env` exists on this machine — `DATABASE_URL` and `JWT_SECRET` must be supplied before the app will import (`database.py` and `auth.py` read them at module level)

### Environment
- Local: Windows, Python 3.14.3, WSL2 available as fallback
- DB: Neon Postgres 17 (credentials in `.env`)
- Docker image: `python:3.11-slim` (production target)
- Cloud Run: service `app01`, region **us-east1** (free-tier eligible), scaling Min 0 / Max 1,
  URL `https://app01-295433370725.us-east1.run.app`
- **Deploys happen by pushing to the GitHub repo**, not by `gcloud run deploy --source`. A Cloud
  Build trigger created through the Cloud Run console watches the repo and builds from the
  `Dockerfile`.

### Next Steps
- ~~GCP free trial expiry~~ — **resolved 2026-08-19** by the account owner, so the service is no
  longer on a clock. The underlying issue still applies to *students*, not to this project: every
  one of them hits the same cliff 90 days after signing up, so the wizard needs a page for it.
  Tracked in `prompts/wizard_concept.md` under "Constraints the template must respect".
- **Docs-only commits trigger a full rebuild and a new Cloud Run revision.** The build trigger has
  no ignored-files filter, so editing `project_log.md` ships a revision identical to the running
  one and burns build quota. Fix once the gcloud CLI is installed on this machine — set the
  equivalent of RiddleSite's `TriggerIgnoredFiles = "**/*.md,*.ps1"`. Note RiddleSite's warning:
  a trigger created by the Cloud Run console wizard is Cloud Run-managed and holds fields that
  `gcloud builds triggers create/update github` cannot express — those subcommands reject it with
  `INVALID_ARGUMENT`. Use `gcloud beta builds triggers export`, edit the YAML, then `import`,
  which round-trips the whole resource.
- **No deploy config in the repo.** There is no `cloudbuild.yaml` and no `.github/workflows`, so
  the build/deploy pipeline exists only as a console-created Cloud Build trigger. Nothing in the
  repo records how this app ships, and a fresh clone cannot reproduce it. Compare RiddleSite,
  which keeps its runtime flags in `cloudbuild.yaml`. Worth fixing before this becomes a template.
- `sql/users_table.sql` is **syntax-checked but never executed** — there is no reachable database
  from this machine. Run it once in the Neon SQL editor to confirm; both verification queries
  should report `OK` on every row.
- Replace the placeholder landing-page copy once a demo feature (e.g. per-user notes) exists —
  the hero should show off that feature rather than describe the template
- Test local credentials register/login end-to-end
- Smoke test Cloud Run with local credentials
- **pytest suite** — unit tests (JWT, password hashing) + integration tests via `httpx.AsyncClient` against the FastAPI routes; run in CI on every push
- **Browser smoke tests** — automated end-to-end verification against Cloud Run after deploy (local credentials test account; Google OAuth verified manually)

---

## 2026-08-19 — Session 4

### Frontend restyle: public home page + menu bar

App01 previously opened straight onto a login card, so there was nothing to see without an
account. Rebuilt `static/index.html` as a public marketing page with the app behind it, in
preparation for using this repo as the template for the setup-wizard project.

#### Changes

| File | Change |
|---|---|
| `static/index.html` | Rewritten. Sticky translucent menu bar (brand, nav links, Sign in / Sign up, hamburger under `md`); public hero with gradient headline and a drawn product mock; features, stack and CTA sections; footer. Login/register moved into a single modal dialog shared by the header buttons and both CTAs. Dashboard is now a second view (`#view-dashboard`) rather than a replacement for the page. |

Backend untouched — no changes to `main.py`, `routers/auth.py`, `models.py`, `database.py`
or `auth.py`. The frontend still talks to the same four endpoints.

#### Landing-page copy: describe the app, don't advertise the template

First draft of the hero sold the *idea* of the template ("Your app, on the cloud, for almost
nothing"). Wrong on two counts: this page is also what a student's own users will eventually see,
so until it is rewritten their app advertises someone else's product; and the pitch belongs on the
wizard site, not in the thing the wizard installs. Recast as an example app describing itself
("An example app, running in the cloud for almost nothing"), with a `Replace this copy` comment
marking the section as the first thing to rewrite. When a demo feature lands, the hero should
show that feature instead.

The stack panel also claimed `gcloud run deploy --source .`, which is not how this repo ships.
Corrected to `git push origin main`.

#### Follow-up after the first deploy: the home page ignored the auth state

Signing in with Google landed on the public home page still showing "Create an account", "Sign up"
and "Try the sign-in flow" — to a user who had just signed in. Two separate faults:

1. **The public page never adapted to being signed in.** It is reachable while authenticated (via
   the logo, the Home link, or the post-login redirect), so its calls to action have to follow the
   auth state like the header already did. The hero CTA now swaps to "Open your dashboard", the
   closing invitation section is removed entirely, and the hero's final sentence swaps. All are
   static markup toggled by class in `renderAuth()` — the same pattern used for the header, and
   for the same Tailwind CDN reason.
2. **The two auth paths ended in different places.** `routers/auth.py` redirected the Google
   callback to `/`, while the email/password path calls `showView("dashboard")`. The callback now
   redirects to `/#/dashboard`, which the frontend already reads on load.

Verified locally in both states: signed in, the home page contains no "Create an account" or
"Sign up" text anywhere; signed out, everything is restored.

Confirmed on the live service after deploy: Google sign-in now lands on the dashboard, and a
second sign-in reuses the existing `users` row (same UUID) rather than inserting a duplicate,
so the callback's update branch works as well as its insert branch.

#### Bugs found and fixed along the way

- `.tab-btn.active` was styled with `@apply` inside a plain `<style>` block, which the Tailwind
  CDN does not process. The active-tab underline had never rendered. Now plain CSS.
- The signed-in username span was injected via `innerHTML` carrying `lg:inline`, a class present
  nowhere else in the document, so the CDN never generated it and the name was invisible at every
  width. Both auth states are now static markup toggled by class, and the display name is set with
  `textContent` — which also removes the `innerHTML` injection path entirely.

#### Verified locally

Server run on port 8080 with a deliberately unreachable `DATABASE_URL` (`init_db` degrades
without raising, by design). Driven through the browser: logged-out header, modal open/close via
button, backdrop and Escape, tab switching, hamburger toggle with correct `aria-expanded`, menu
auto-close on navigation, dashboard render for both avatar and initials fallback, Google vs local
provider badges, sign-out returning to the public page, HTML-escaping of a hostile display name,
and no horizontal overflow at 375 / 768 / 1280 px.

**Not verified:** real register / login / Google OAuth against Neon — this machine has no `.env`,
so no database credentials. The forms are wired to the same endpoints as before and the request
shapes are unchanged, but the round trip is still untested end to end.

---

## 2026-05-28 12:00–12:06 — Session 3

### Cloud Run OAuth Fix

Google OAuth redirect URI was hardcoded to `localhost`, causing login to fail on Cloud Run.

#### Changes

| File | Change |
|---|---|
| `routers/auth.py` | `GOOGLE_REDIRECT_URI` env var removed; redirect URI now built dynamically via `_callback_uri(request)` using `str(request.base_url) + "auth/google/callback"` |
| `main.py` | Added `ProxyHeadersMiddleware` so `request.base_url` returns `https://` on Cloud Run (which terminates TLS at the ingress before uvicorn) |

#### Git Commit

`407cd38` — *Fix Google OAuth redirect URI to be dynamic; add ProxyHeadersMiddleware for Cloud Run HTTPS*

#### Milestone

✅ Google OAuth confirmed working on Cloud Run.

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
